defmodule DashboardSSD.Projects.SyncFromLinearTest do
  use DashboardSSD.DataCase, async: false

  alias DashboardSSD.{Clients, Projects}
  alias DashboardSSD.Projects.{CacheStore, WorkflowStateCache}

  setup do
    # Configure Linear token for Integrations
    prev = Application.get_env(:dashboard_ssd, :integrations)
    Application.put_env(:dashboard_ssd, :integrations, linear_token: "tok")

    CacheStore.delete()
    WorkflowStateCache.flush()

    on_exit(fn ->
      if prev,
        do: Application.put_env(:dashboard_ssd, :integrations, prev),
        else: Application.delete_env(:dashboard_ssd, :integrations)
    end)

    :ok
  end

  test "imports projects and infers client by name substring" do
    {:ok, c} = Clients.create_client(%{name: "Acme"})

    mock_linear(
      [%{id: "team-1", name: "Acme Team"}],
      %{"team-1" => [%{id: "proj-1", name: "Acme Website"}]},
      %{"team-1" => [%{id: "state-1", name: "Todo", type: "backlog"}]},
      %{"team-1" => [%{id: "user-1", name: "Alice", display_name: "Alice A."}]}
    )

    assert {:ok, %{inserted: 1, updated: 0}} = Projects.sync_from_linear()

    projects = Projects.list_projects_by_client(c.id)
    project = Enum.find(projects, &(&1.name == "Acme Website"))
    assert project.linear_project_id == "proj-1"
    assert project.linear_team_id == "team-1"
    assert project.linear_team_name == "Acme Team"

    state_map = Projects.workflow_state_metadata("team-1")
    assert Map.get(state_map, "state-1") == %{name: "Todo", type: "backlog", color: nil}

    members = Projects.team_members_by_team_ids(["team-1"])
    assert Map.has_key?(members, "team-1")

    assert Enum.any?(
             members["team-1"],
             &(&1.linear_user_id == "user-1" and &1.display_name == "Alice A.")
           )
  end

  test "imports project unassigned when no client match" do
    mock_linear(
      [%{id: "team-1", name: "Random Team"}],
      %{"team-1" => [%{id: "proj-2", name: "Foobar"}]}
    )

    assert {:ok, %{inserted: 1, updated: 0}} = Projects.sync_from_linear()
    # Should exist with nil client_id
    assert Enum.any?(Projects.list_projects(), &(&1.name == "Foobar" and is_nil(&1.client_id)))
  end

  test "sync falls back when members field is unavailable" do
    {:ok, _} = Projects.create_project(%{name: "Fallback Test"})

    Tesla.Mock.mock(fn %{method: :post, url: "https://api.linear.app/graphql"} = env ->
      payload = decode_graphql(env)
      query = payload["query"]
      vars = Map.get(payload, "variables", %{})

      cond do
        String.contains?(query, "TeamsPage") ->
          build_team_page_response([%{id: "team-fallback", name: "Fallback"}])

        String.contains?(query, "teamMemberships") ->
          %Tesla.Env{
            status: 400,
            body: %{
              "errors" => [
                %{"message" => "Cannot query field \"teamMemberships\" on type \"Team\"."}
              ]
            }
          }

        String.contains?(query, "members(first: 100)") ->
          build_team_projects_response(
            vars["teamId"],
            %{"team-fallback" => [%{id: "proj-fallback", name: "Fallback"}]},
            %{"team-fallback" => [%{id: "state-x", name: "Todo"}]},
            %{"team-fallback" => [%{id: "user-fallback", name: "Fallback User"}]}
          )

        String.contains?(query, "TeamProjects") ->
          build_team_projects_response(
            vars["teamId"],
            %{"team-fallback" => [%{id: "proj-fallback", name: "Fallback"}]},
            %{"team-fallback" => [%{id: "state-x", name: "Todo"}]},
            %{}
          )

        true ->
          flunk("Unexpected GraphQL query: #{query}")
      end
    end)

    assert {:ok, %{inserted: inserted, updated: updated}} = Projects.sync_from_linear()
    assert inserted + updated >= 1

    members = Projects.team_members_by_team_ids(["team-fallback"])
    assert Map.has_key?(members, "team-fallback")
  end

  test "sync gracefully ignores teams without ids" do
    mock_linear(
      [%{id: nil, name: "Unknown"}],
      %{nil => [%{id: "proj-orphan", name: "Orphaned"}]},
      %{},
      %{nil => [%{id: "user-ghost", name: "Ghost"}]}
    )

    assert {:ok, %{inserted: inserted, updated: updated}} = Projects.sync_from_linear()
    assert inserted + updated >= 1

    assert Projects.team_members_by_team_ids([nil]) == %{}
  end

  test "sync surfaces unexpected payload errors" do
    Tesla.Mock.mock(fn %{method: :post, url: "https://api.linear.app/graphql"} = env ->
      payload = decode_graphql(env)
      query = payload["query"]

      cond do
        String.contains?(query, "TeamsPage") ->
          %Tesla.Env{
            status: 200,
            body: %{
              "data" => %{
                "teams" => %{
                  "nodes" => [%{"id" => "team-unexpected", "name" => "Unexpected"}],
                  "pageInfo" => %{"hasNextPage" => false}
                }
              }
            }
          }

        String.contains?(query, "TeamProjects") ->
          %Tesla.Env{status: 200, body: %{"unexpected" => "structure"}}
      end
    end)

    assert_raise CaseClauseError, fn -> Projects.sync_from_linear() end
  end

  test "sync normalizes team members with mixed data shapes" do
    Tesla.Mock.mock(fn %{method: :post, url: "https://api.linear.app/graphql"} = env ->
      payload = decode_graphql(env)
      query = payload["query"]

      cond do
        String.contains?(query, "TeamsPage") ->
          %Tesla.Env{
            status: 200,
            body: %{
              "data" => %{
                "teams" => %{
                  "nodes" => [%{"id" => "team-mixed", "name" => "Mixed"}],
                  "pageInfo" => %{"hasNextPage" => false}
                }
              }
            }
          }

        String.contains?(query, "teamMemberships") ->
          %Tesla.Env{
            status: 400,
            body: %{
              "errors" => [
                %{"message" => "Cannot query field \"teamMemberships\" on type \"Team\"."}
              ]
            }
          }

        String.contains?(query, "members(first: 100)") ->
          %Tesla.Env{
            status: 200,
            body: %{
              "data" => %{
                "team" => %{
                  "projects" => %{
                    "nodes" => [],
                    "pageInfo" => %{"hasNextPage" => false}
                  },
                  "states" => %{"nodes" => []},
                  "members" => %{
                    "nodes" => [
                      %{
                        "id" => 123,
                        "name" => "Alice",
                        "displayName" => "Alice A.",
                        "email" => "alice@example.com",
                        "avatarUrl" => "https://cdn.example.com/a.png"
                      },
                      %{
                        id: 456,
                        name: "Bob",
                        display_name: "Bobby",
                        email: "bob@example.com",
                        avatar_url: "https://cdn.example.com/b.png"
                      }
                    ]
                  }
                }
              }
            }
          }
      end
    end)

    assert {:ok, _} = Projects.sync_from_linear()

    members = Projects.team_members_by_team_ids(["team-mixed"])["team-mixed"]
    linear_ids = Enum.map(members, & &1.linear_user_id)

    assert Enum.sort(linear_ids) == ["123", "456"]

    assert Enum.any?(members, &(&1.display_name == "Alice A."))
    assert Enum.any?(members, &(&1.display_name == "Bobby"))
  end

  test "sync handles teams without accessible member fields" do
    Tesla.Mock.mock(fn %{method: :post, url: "https://api.linear.app/graphql"} = env ->
      payload = decode_graphql(env)
      query = payload["query"]

      cond do
        String.contains?(query, "TeamsPage") ->
          %Tesla.Env{
            status: 200,
            body: %{
              "data" => %{
                "teams" => %{
                  "nodes" => [%{"id" => "team-nomembers", "name" => "No Members"}],
                  "pageInfo" => %{"hasNextPage" => false}
                }
              }
            }
          }

        String.contains?(query, "teamMemberships") ->
          %Tesla.Env{
            status: 400,
            body: %{
              "errors" => [
                %{"message" => "Cannot query field \"teamMemberships\" on type \"Team\"."}
              ]
            }
          }

        String.contains?(query, "members(first: 100)") ->
          %Tesla.Env{
            status: 400,
            body: %{
              "errors" => [
                %{"message" => "Cannot query field \"members\" on type \"Team\"."}
              ]
            }
          }

        String.contains?(query, "TeamProjectsNoMembers") ->
          %Tesla.Env{
            status: 200,
            body: %{
              "data" => %{
                "team" => %{
                  "projects" => %{
                    "nodes" => [%{"id" => "proj-none", "name" => "No Members"}],
                    "pageInfo" => %{"hasNextPage" => false}
                  },
                  "states" => %{"nodes" => []}
                }
              }
            }
          }

        true ->
          flunk("Unexpected query #{query}")
      end
    end)

    assert {:ok, _} = Projects.sync_from_linear()
    assert Projects.team_members_by_team_ids(["team-nomembers"]) == %{}
  end

  test "sync returns error when team payload unexpected" do
    Tesla.Mock.mock(fn %{method: :post, url: "https://api.linear.app/graphql"} = env ->
      payload = decode_graphql(env)
      query = payload["query"]

      if String.contains?(query, "TeamsPage") do
        %Tesla.Env{status: 200, body: %{"unexpected" => "structure"}}
      else
        flunk("Unexpected query #{query}")
      end
    end)

    assert {:error, {:unexpected, %{"unexpected" => "structure"}}} = Projects.sync_from_linear()
  end

  test "sync updates team members removing stale entries" do
    mock_linear(
      [%{id: "team-update", name: "Update"}],
      %{"team-update" => [%{id: "proj-update", name: "Update"}]},
      %{},
      %{"team-update" => [%{id: "user-a", name: "Alice"}, %{id: "user-b", name: "Bob"}]}
    )

    assert {:ok, _} = Projects.sync_from_linear()
    assert Map.has_key?(Projects.team_members_by_team_ids(["team-update"]), "team-update")

    mock_linear(
      [%{id: "team-update", name: "Update"}],
      %{"team-update" => [%{id: "proj-update", name: "Update"}]},
      %{},
      %{"team-update" => [%{id: "user-a", name: "Alice"}]}
    )

    assert {:ok, _} = Projects.sync_from_linear()

    members = Projects.team_members_by_team_ids(["team-update"])
    assert Enum.map(members["team-update"], & &1.linear_user_id) == ["user-a"]
  end

  test "sync stores members across multiple teams even with shared users" do
    mock_linear(
      [%{id: "team-a", name: "Team A"}, %{id: "team-b", name: "Team B"}],
      %{
        "team-a" => [%{id: "proj-a", name: "Proj A"}],
        "team-b" => [%{id: "proj-b", name: "Proj B"}]
      },
      %{},
      %{
        "team-a" => [%{id: "user-1", name: "Shared User"}],
        "team-b" => [
          %{id: "user-1", name: "Shared User"},
          %{id: "user-2", name: "Other User"}
        ]
      }
    )

    assert {:ok, %{inserted: inserted, updated: updated}} = Projects.sync_from_linear()
    assert inserted + updated >= 2

    members_map = Projects.team_members_by_team_ids(["team-a", "team-b"])

    assert Map.has_key?(members_map, "team-a")
    assert Map.has_key?(members_map, "team-b")

    assert Enum.map(members_map["team-a"], & &1.linear_user_id) == ["user-1"]

    assert Enum.map(members_map["team-b"], & &1.linear_user_id) |> Enum.sort() ==
             ["user-1", "user-2"]
  end

  test "updates existing project to assign inferred client" do
    {:ok, c} = Clients.create_client(%{name: "Globex"})
    # existing project with nil client
    {:ok, _p} = Projects.create_project(%{name: "Globex CRM"})

    mock_linear(
      [%{id: "team-1", name: "Globex Team"}],
      %{"team-1" => [%{id: "proj-3", name: "Globex CRM"}]}
    )

    assert {:ok, %{inserted: 0, updated: _}} = Projects.sync_from_linear()
    # project should now be assigned to Globex
    assert Enum.any?(Projects.list_projects_by_client(c.id), &(&1.name == "Globex CRM"))
  end

  test "no-op when project already assigned to inferred client" do
    {:ok, c} = Clients.create_client(%{name: "Acme"})
    {:ok, _} = Projects.create_project(%{name: "Acme Website", client_id: c.id})

    mock_linear(
      [%{id: "team-1", name: "Acme"}],
      %{"team-1" => [%{id: "proj-4", name: "Acme Website"}]}
    )

    assert {:ok, %{inserted: 0, updated: u}} = Projects.sync_from_linear()
    # updated may be 0 (no change) or 1 (touched same client)
    assert u in [0, 1]
  end

  test "updates existing project with linear metadata without altering client" do
    {:ok, c} = Clients.create_client(%{name: "Acme"})
    {:ok, project} = Projects.create_project(%{name: "Acme Website", client_id: c.id})

    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.linear.app/graphql"} = env ->
        %{"query" => query} = decode_graphql(env)

        cond do
          String.contains?(query, "TeamsPage") ->
            %Tesla.Env{
              status: 200,
              body: %{
                "data" => %{
                  "teams" => %{
                    "nodes" => [%{"id" => "team-1", "name" => "Acme"}],
                    "pageInfo" => %{"hasNextPage" => false}
                  }
                }
              }
            }

          String.contains?(query, "TeamProjects") ->
            %Tesla.Env{
              status: 200,
              body: %{
                "data" => %{
                  "team" => %{
                    "projects" => %{
                      "nodes" => [%{"id" => "proj-linear", "name" => "Acme Website"}],
                      "pageInfo" => %{"hasNextPage" => false}
                    },
                    "states" => %{"nodes" => []}
                  }
                }
              }
            }

          true ->
            flunk("Unexpected query: #{query}")
        end
    end)

    assert {:ok, %{inserted: 0, updated: 1}} = Projects.sync_from_linear()

    updated = Projects.list_projects() |> Enum.find(&(&1.id == project.id))
    assert updated.linear_project_id == "proj-linear"
    assert updated.linear_team_id == "team-1"
    assert updated.linear_team_name == "Acme"
    assert updated.client_id == c.id
  end

  test "imports paginated teams and project pages" do
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.linear.app/graphql", body: body} ->
        %{"query" => query, "variables" => vars} = decode_graphql(%Tesla.Env{body: body})

        cond do
          String.contains?(query, "TeamsPage") ->
            respond_to_team_page(vars)

          String.contains?(query, "TeamProjects") ->
            respond_to_team_projects(vars)

          true ->
            flunk("Unexpected query: #{query}")
        end
    end)

    assert {:ok, %{inserted: 3, updated: 0}} = Projects.sync_from_linear()

    projects = Projects.list_projects()
    assert Enum.sort(Enum.map(projects, & &1.linear_project_id)) == ["proj-a", "proj-b", "proj-c"]
    assert Enum.any?(projects, &(&1.linear_team_name == "Team One"))
    assert Enum.any?(projects, &(&1.linear_team_name == "Team Two"))

    team_1_states = Projects.workflow_state_metadata("team-1")
    assert Map.has_key?(team_1_states, "state-1")

    team_2_states = Projects.workflow_state_metadata("team-2")
    assert Map.get(team_2_states, "state-2").name == "QA"
  end

  defp respond_to_team_page(vars) do
    case Map.get(vars, "after") do
      nil ->
        %Tesla.Env{
          status: 200,
          body: %{
            "data" => %{
              "teams" => %{
                "nodes" => [%{"id" => "team-1", "name" => "Team One"}],
                "pageInfo" => %{"hasNextPage" => true, "endCursor" => "teams-cursor"}
              }
            }
          }
        }

      "teams-cursor" ->
        %Tesla.Env{
          status: 200,
          body: %{
            "data" => %{
              "teams" => %{
                "nodes" => [%{"id" => "team-2", "name" => "Team Two"}],
                "pageInfo" => %{"hasNextPage" => false}
              }
            }
          }
        }
    end
  end

  defp respond_to_team_projects(%{"teamId" => "team-1"} = vars) do
    case Map.get(vars, "after") do
      nil ->
        %Tesla.Env{
          status: 200,
          body: %{
            "data" => %{
              "team" => %{
                "projects" => %{
                  "nodes" => [%{"id" => "proj-a", "name" => "Proj A"}],
                  "pageInfo" => %{"hasNextPage" => true, "endCursor" => "proj-cursor"}
                },
                "states" => %{
                  "nodes" => [%{"id" => "state-1", "name" => "Todo", "type" => "backlog"}]
                }
              }
            }
          }
        }

      "proj-cursor" ->
        %Tesla.Env{
          status: 200,
          body: %{
            "data" => %{
              "team" => %{
                "projects" => %{
                  "nodes" => [%{"id" => "proj-b", "name" => "Proj B"}],
                  "pageInfo" => %{"hasNextPage" => false}
                },
                "states" => %{
                  "nodes" => [%{"id" => "state-1", "name" => "Todo", "type" => "backlog"}]
                }
              }
            }
          }
        }
    end
  end

  defp respond_to_team_projects(%{"teamId" => "team-2"}) do
    %Tesla.Env{
      status: 200,
      body: %{
        "data" => %{
          "team" => %{
            "projects" => %{
              "nodes" => [%{"id" => "proj-c", "name" => "Proj C"}],
              "pageInfo" => %{"hasNextPage" => false}
            },
            "states" => %{
              "nodes" => [
                %{"id" => "state-2", "name" => "QA", "type" => "started", "color" => "#FF00FF"}
              ]
            }
          }
        }
      }
    }
  end

  defp mock_linear(
         teams,
         projects_by_team,
         states_by_team \\ %{},
         members_by_team \\ %{},
         issues_by_project \\ %{}
       ) do
    Tesla.Mock.mock(fn %{method: :post, url: "https://api.linear.app/graphql"} = env ->
      payload = decode_graphql(env)
      query = payload["query"]
      variables = Map.get(payload, "variables", %{})

      respond_to_linear_query(
        query,
        variables,
        teams,
        projects_by_team,
        states_by_team,
        members_by_team,
        issues_by_project
      )
    end)
  end

  defp respond_to_linear_query(
         query,
         variables,
         teams,
         projects_by_team,
         states_by_team,
         members_by_team,
         issues_by_project
       ) do
    cond do
      String.contains?(query, "TeamsPage") ->
        build_team_page_response(teams)

      String.contains?(query, "TeamProjects") ->
        team_id = variables["teamId"]
        build_team_projects_response(team_id, projects_by_team, states_by_team, members_by_team)

      String.contains?(query, "IssuesByProjectId") ->
        project_id = variables["projectId"]
        build_issue_nodes_response(project_id, issues_by_project)

      true ->
        flunk("Unexpected GraphQL query: #{query}")
    end
  end

  defp build_team_page_response(teams) do
    team_nodes = Enum.map(teams, &%{"id" => &1.id, "name" => &1.name})

    %Tesla.Env{
      status: 200,
      body: %{
        "data" => %{
          "teams" => %{
            "nodes" => team_nodes,
            "pageInfo" => %{"hasNextPage" => false}
          }
        }
      }
    }
  end

  defp build_issue_nodes_response(project_id, issues_by_project) do
    nodes = Map.get(issues_by_project, project_id, [])

    %Tesla.Env{
      status: 200,
      body: %{
        "data" => %{
          "issues" => %{
            "nodes" => nodes,
            "pageInfo" => %{"hasNextPage" => false}
          }
        }
      }
    }
  end

  defp build_team_projects_response(team_id, projects_by_team, states_by_team, members_by_team) do
    members = team_members_for(team_id, members_by_team)

    %Tesla.Env{
      status: 200,
      body: %{
        "data" => %{
          "team" => %{
            "projects" => %{
              "nodes" => project_nodes_for(team_id, projects_by_team),
              "pageInfo" => %{"hasNextPage" => false}
            },
            "states" => %{"nodes" => workflow_states_for(team_id, states_by_team)},
            "members" => %{"nodes" => members},
            "teamMemberships" => %{
              "nodes" => Enum.map(members, fn member -> %{"user" => member} end)
            }
          }
        }
      }
    }
  end

  defp project_nodes_for(team_id, projects_by_team) do
    projects_by_team
    |> Map.get(team_id, [])
    |> Enum.map(&normalize_project_node(team_id, &1))
  end

  defp normalize_project_node(_team_id, %{"id" => id, "name" => name}),
    do: %{"id" => id, "name" => name}

  defp normalize_project_node(_team_id, %{id: id, name: name}),
    do: %{"id" => id, "name" => name}

  defp normalize_project_node(team_id, name) when is_binary(name),
    do: %{"id" => "proj-#{:erlang.phash2({team_id, name})}", "name" => name}

  defp workflow_states_for(team_id, states_by_team) do
    states_by_team
    |> Map.get(team_id, [])
    |> Enum.map(&normalize_state/1)
  end

  defp team_members_for(team_id, members_by_team) do
    members_by_team
    |> Map.get(team_id, [])
    |> Enum.map(&normalize_member/1)
  end

  defp normalize_member(%{id: id} = member) do
    %{
      "id" => id,
      "name" => Map.get(member, :name) || Map.get(member, "name"),
      "displayName" =>
        Map.get(member, :display_name) || Map.get(member, "display_name") ||
          Map.get(member, "displayName"),
      "email" => Map.get(member, :email) || Map.get(member, "email"),
      "avatarUrl" =>
        Map.get(member, :avatar_url) || Map.get(member, "avatar_url") ||
          Map.get(member, "avatarUrl")
    }
  end

  defp normalize_member(%{"id" => id} = member) do
    %{
      "id" => id,
      "name" => Map.get(member, "name"),
      "displayName" => Map.get(member, "displayName"),
      "email" => Map.get(member, "email"),
      "avatarUrl" => Map.get(member, "avatarUrl")
    }
  end

  defp normalize_member(_), do: nil

  defp normalize_state(%{"id" => id, "name" => name, "type" => type, "color" => color}) do
    %{"id" => id, "name" => name, "type" => type, "color" => color}
  end

  defp normalize_state(%{id: id, name: name} = state) do
    %{
      "id" => id,
      "name" => name,
      "type" => Map.get(state, :type) || Map.get(state, "type"),
      "color" => Map.get(state, :color) || Map.get(state, "color")
    }
  end

  defp normalize_state(name) when is_binary(name) do
    %{"id" => "state-#{:erlang.phash2({:state, name})}", "name" => name}
  end

  test "workflow_state_metadata returns empty map for missing team" do
    assert Projects.workflow_state_metadata(nil) == %{}
    assert Projects.workflow_state_metadata("does-not-exist") == %{}
  end

  test "sync handles teams without workflow states" do
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.linear.app/graphql"} = env ->
        %{"query" => query} = decode_graphql(env)

        cond do
          String.contains?(query, "TeamsPage") ->
            %Tesla.Env{
              status: 200,
              body: %{
                "data" => %{
                  "teams" => %{
                    "nodes" => [%{"id" => "team-3", "name" => "Stateless"}],
                    "pageInfo" => %{"hasNextPage" => false}
                  }
                }
              }
            }

          String.contains?(query, "TeamProjects") ->
            %Tesla.Env{
              status: 200,
              body: %{
                "data" => %{
                  "team" => %{
                    "projects" => %{
                      "nodes" => [%{"id" => "proj-stateless", "name" => "Stateless Project"}],
                      "pageInfo" => %{"hasNextPage" => false}
                    },
                    "states" => nil
                  }
                }
              }
            }

          true ->
            flunk("Unexpected query: #{query}")
        end
    end)

    assert {:ok, %{inserted: 1, updated: 0}} = Projects.sync_from_linear()

    projects = Projects.list_projects()
    project = Enum.find(projects, &(&1.linear_team_id == "team-3"))
    assert project.linear_team_name == "Stateless"
    assert Projects.workflow_state_metadata("team-3") == %{}
  end

  test "returns error when Linear GraphQL fails" do
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.linear.app/graphql"} ->
        %Tesla.Env{status: 500, body: "error"}
    end)

    assert {:error, _} = Projects.sync_from_linear()
  end

  test "does not clear existing linear ids when absent from response" do
    {:ok, project} =
      Projects.create_project(%{
        name: "Legacy Project",
        linear_project_id: "existing-proj",
        linear_team_id: "existing-team"
      })

    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.linear.app/graphql"} = env ->
        %{"query" => query} = decode_graphql(env)

        cond do
          String.contains?(query, "TeamsPage") ->
            %Tesla.Env{
              status: 200,
              body: %{
                "data" => %{
                  "teams" => %{
                    "nodes" => [%{"id" => "existing-team", "name" => "Legacy"}],
                    "pageInfo" => %{"hasNextPage" => false}
                  }
                }
              }
            }

          String.contains?(query, "TeamProjects") ->
            %Tesla.Env{
              status: 200,
              body: %{
                "data" => %{
                  "team" => %{
                    "projects" => %{
                      "nodes" => [%{"id" => nil, "name" => "Legacy Project"}],
                      "pageInfo" => %{"hasNextPage" => false}
                    },
                    "states" => %{"nodes" => []}
                  }
                }
              }
            }

          true ->
            flunk("Unexpected query: #{query}")
        end
    end)

    assert {:ok, %{inserted: 0, updated: u}} = Projects.sync_from_linear()
    assert u in [0, 1]

    reloaded = Projects.list_projects() |> Enum.find(&(&1.id == project.id))
    assert reloaded.linear_project_id == "existing-proj"
    assert reloaded.linear_team_id == "existing-team"
    assert reloaded.linear_team_name == "Legacy"
  end

  test "handles missing team object in projects response" do
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.linear.app/graphql"} = env ->
        %{"query" => query} = decode_graphql(env)

        cond do
          String.contains?(query, "TeamsPage") ->
            %Tesla.Env{
              status: 200,
              body: %{
                "data" => %{
                  "teams" => %{
                    "nodes" => [%{"id" => "ghost-team", "name" => "Ghost"}],
                    "pageInfo" => %{"hasNextPage" => false}
                  }
                }
              }
            }

          String.contains?(query, "TeamProjects") ->
            %Tesla.Env{
              status: 200,
              body: %{"data" => %{"team" => nil}}
            }

          true ->
            flunk("Unexpected query: #{query}")
        end
    end)

    assert {:ok, %{inserted: 0, updated: u}} = Projects.sync_from_linear()
    assert u in [0, 1]
  end

  defp decode_graphql(%Tesla.Env{body: body}) when is_binary(body), do: Jason.decode!(body)
  defp decode_graphql(%Tesla.Env{body: body}) when is_map(body), do: body
end
