defmodule DashboardSSD.Projects.SyncFromLinearCacheTest do
  use DashboardSSD.DataCase, async: false

  alias DashboardSSD.Projects
  alias DashboardSSD.Projects.CacheStore

  setup do
    prev_env = Application.get_env(:dashboard_ssd, :env)
    prev_integrations = Application.get_env(:dashboard_ssd, :integrations)

    Application.put_env(:dashboard_ssd, :env, :dev)

    start_cache_if_needed()
    CacheStore.reset()
    CacheStore.delete()

    on_exit(fn ->
      CacheStore.reset()
      CacheStore.delete()

      if prev_env do
        Application.put_env(:dashboard_ssd, :env, prev_env)
      else
        Application.delete_env(:dashboard_ssd, :env)
      end

      if prev_integrations do
        Application.put_env(:dashboard_ssd, :integrations, prev_integrations)
      else
        Application.delete_env(:dashboard_ssd, :integrations)
      end
    end)

    :ok
  end

  test "returns cached payload when data is fresh" do
    entry = %{
      payload: %{inserted: 1, updated: 2},
      synced_at: DateTime.utc_now(),
      synced_at_mono: System.monotonic_time(:millisecond),
      next_allowed_sync_mono: nil,
      rate_limit_message: nil
    }

    :ok = CacheStore.put(entry, :timer.minutes(30))

    assert {:ok, payload} = Projects.sync_from_linear()
    assert payload.inserted == entry.payload.inserted
    assert payload.updated == entry.payload.updated
    assert payload[:cached?]
    assert payload[:cached_reason] == :fresh_cache
    assert payload[:summaries] == %{}
  end

  test "returns cached payload when within backoff window" do
    now_mono = System.monotonic_time(:millisecond)

    entry = %{
      payload: %{inserted: 4, updated: 0},
      synced_at: DateTime.utc_now(),
      synced_at_mono: now_mono,
      next_allowed_sync_mono: now_mono + 10_000,
      rate_limit_message: "Try again later"
    }

    :ok = CacheStore.put(entry, :timer.minutes(30))

    assert {:ok, payload} = Projects.sync_from_linear(force: true)
    assert payload.inserted == entry.payload.inserted
    assert payload.updated == entry.payload.updated
    assert payload[:cached?]
    assert payload[:cached_reason] == :rate_limited
    assert payload[:message] == "Try again later"
    assert payload[:summaries] == %{}
  end

  test "performs sync and caches result when data is stale" do
    Application.put_env(:dashboard_ssd, :integrations, linear_token: "tok")
    mock_linear_simple()

    CacheStore.delete()

    assert {:ok, payload} = Projects.sync_from_linear(force: true)
    assert payload.inserted >= 1
    refute payload[:cached?]
    assert payload[:cached_reason] == :fresh
    assert is_map(payload[:summaries])
    assert map_size(payload[:summaries]) > 0

    assert {:ok, cached_payload} = Projects.sync_from_linear()
    assert cached_payload[:cached?]
    assert cached_payload[:cached_reason] in [:fresh_cache, :fresh]
    assert cached_payload[:summaries] == payload[:summaries]
  end

  test "returns error when rate limited without cached data" do
    Application.put_env(:dashboard_ssd, :integrations, linear_token: "tok")

    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.linear.app/graphql"} ->
        %Tesla.Env{
          status: 429,
          body: %{
            "errors" => [
              %{
                "message" => "ratelimit exceeded",
                "extensions" => %{
                  "code" => "RATELIMITED",
                  "userPresentableMessage" => "Rate limit hit"
                }
              }
            ]
          }
        }
    end)

    CacheStore.delete()

    assert {:error, {:rate_limited, "Rate limit hit"}} = Projects.sync_from_linear(force: true)
  end

  test "returns cached summaries when rate limited after successful sync" do
    Application.put_env(:dashboard_ssd, :integrations, linear_token: "tok")
    mock_linear_simple()

    CacheStore.delete()

    assert {:ok, payload} = Projects.sync_from_linear(force: true)
    assert map_size(payload[:summaries]) > 0

    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.linear.app/graphql"} ->
        %Tesla.Env{
          status: 429,
          body: %{
            "errors" => [
              %{
                "message" => "ratelimit exceeded",
                "extensions" => %{
                  "code" => "RATELIMITED",
                  "userPresentableMessage" => "Rate limit hit"
                }
              }
            ]
          }
        }
    end)

    assert {:ok, cached} = Projects.sync_from_linear(force: true)
    assert cached[:cached?]
    assert cached[:cached_reason] == :rate_limited
    assert cached[:summaries] == payload[:summaries]
    assert cached[:message] == "Rate limit hit"
  end

  test "cached payload without counts defaults to zeros" do
    entry = %{
      payload: %{other: :data},
      synced_at: DateTime.utc_now(),
      synced_at_mono: System.monotonic_time(:millisecond),
      next_allowed_sync_mono: nil,
      rate_limit_message: nil
    }

    :ok = CacheStore.put(entry, :timer.minutes(30))

    assert {:ok, payload} = Projects.sync_from_linear()
    assert payload.inserted == 0
    assert payload.updated == 0
    assert payload[:cached?]
  end

  test "cached summaries backfill assigned list when absent" do
    entry = %{
      payload: %{
        "summaries" => %{"42" => %{"total" => 5, "in_progress" => 2, "finished" => 1}}
      },
      synced_at: DateTime.utc_now(),
      synced_at_mono: System.monotonic_time(:millisecond),
      next_allowed_sync_mono: nil,
      rate_limit_message: nil
    }

    :ok = CacheStore.put(entry, :timer.minutes(30))

    assert {:ok, payload} = Projects.sync_from_linear()
    assert payload[:cached?]

    summary = payload[:summaries]["42"]
    assert summary[:assigned] == []
    assert summary["assigned"] == []
    assert payload["summaries"]["42"]["assigned"] == []
  end

  test "sync payload includes assigned members" do
    Application.put_env(:dashboard_ssd, :integrations, linear_token: "tok")
    mock_linear_with_assignees()

    CacheStore.delete()

    assert {:ok, payload} = Projects.sync_from_linear(force: true)
    assert payload[:cached_reason] == :fresh

    project_ids =
      Projects.list_projects()
      |> Enum.map(&to_string(&1.id))

    assert [project_id] = project_ids

    summary = payload[:summaries][project_id]

    assert [
             %{id: "user-1", name: "Alice Demo", count: 2},
             %{id: "user-2", name: "Bob Builder", count: 1}
           ] = summary[:assigned]

    assert summary["assigned"] == summary[:assigned]
  end

  test "cached summaries preserve unavailable sentinel" do
    entry = %{
      payload: %{"summaries" => %{"99" => :unavailable}},
      synced_at: DateTime.utc_now(),
      synced_at_mono: System.monotonic_time(:millisecond),
      next_allowed_sync_mono: nil,
      rate_limit_message: nil
    }

    :ok = CacheStore.put(entry, :timer.minutes(30))

    assert {:ok, payload} = Projects.sync_from_linear()
    assert payload[:cached?]
    assert payload[:summaries]["99"] == :unavailable
  end

  test "cached entry summaries fallback to cache entry map" do
    now = DateTime.utc_now()
    now_mono = System.monotonic_time(:millisecond)

    entry = %{
      payload: %{inserted: 3, updated: 1},
      synced_at: now,
      synced_at_mono: now_mono,
      next_allowed_sync_mono: now_mono,
      rate_limit_message: nil,
      summaries: %{
        "123" => %{
          total: 3,
          in_progress: 1,
          finished: 2,
          assigned: [%{id: "user-1", name: "Cache User", count: 3}]
        }
      }
    }

    :ok = CacheStore.put(entry, :timer.minutes(30))

    assert {:ok, payload} = Projects.sync_from_linear()
    assert payload[:cached?]
    assert payload[:cached_reason] == :fresh_cache

    summary = payload[:summaries]["123"]
    assert summary[:assigned] == [%{id: "user-1", name: "Cache User", count: 3}]
    assert summary["assigned"] == [%{id: "user-1", name: "Cache User", count: 3}]
  end

  defp start_cache_if_needed do
    unless Process.whereis(DashboardSSD.Cache) do
      start_supervised!(DashboardSSD.Cache)
    end
  end

  defp mock_linear_simple do
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.linear.app/graphql", body: body} ->
        payload = Jason.decode!(body)
        query = payload["query"] || ""
        vars = payload["variables"] || %{}

        cond do
          String.contains?(query, "TeamsPage") ->
            %Tesla.Env{
              status: 200,
              body: %{
                "data" => %{
                  "teams" => %{
                    "nodes" => [%{"id" => "team-1", "name" => "Demo Team"}],
                    "pageInfo" => %{"hasNextPage" => false}
                  }
                }
              }
            }

          String.contains?(query, "IssuesByProjectId") ->
            %Tesla.Env{
              status: 200,
              body: %{
                "data" => %{
                  "issues" => %{
                    "nodes" => [
                      %{"state" => %{"id" => "state-1", "name" => "Done", "type" => "completed"}},
                      %{
                        "state" => %{
                          "id" => "state-2",
                          "name" => "In Progress",
                          "type" => "started"
                        }
                      }
                    ],
                    "pageInfo" => %{"hasNextPage" => false}
                  }
                }
              }
            }

          String.contains?(query, "TeamProjects(") or
            String.contains?(query, "TeamProjectsWithMembers") or
              String.contains?(query, "TeamProjectsNoMembers") ->
            %Tesla.Env{
              status: 200,
              body: %{
                "data" => %{
                  "team" => %{
                    "projects" => %{
                      "nodes" => [%{"id" => "proj-1", "name" => "Demo Project"}],
                      "pageInfo" => %{"hasNextPage" => false}
                    },
                    "states" => %{
                      "nodes" => [%{"id" => "state-1", "name" => "Done", "type" => "completed"}]
                    },
                    "teamMemberships" => %{
                      "nodes" => [
                        %{
                          "user" => %{
                            "id" => "user-1",
                            "name" => "Tester",
                            "displayName" => "Tester",
                            "email" => "tester@example.com",
                            "avatarUrl" => nil
                          }
                        }
                      ]
                    },
                    "members" => %{
                      "nodes" => [
                        %{
                          "id" => "user-1",
                          "name" => "Tester",
                          "displayName" => "Tester",
                          "email" => "tester@example.com",
                          "avatarUrl" => nil
                        }
                      ]
                    }
                  }
                }
              }
            }

          true ->
            flunk("Unexpected Linear query: #{inspect({query, vars})}")
        end
    end)
  end

  defp mock_linear_with_assignees do
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.linear.app/graphql", body: body} ->
        payload = Jason.decode!(body)
        query = payload["query"] || ""
        vars = payload["variables"] || %{}

        cond do
          String.contains?(query, "TeamsPage") ->
            %Tesla.Env{
              status: 200,
              body: %{
                "data" => %{
                  "teams" => %{
                    "nodes" => [%{"id" => "team-assign", "name" => "Assign Team"}],
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
                    "id" => "team-assign",
                    "name" => "Assign Team",
                    "projects" => %{
                      "nodes" => [%{"id" => "proj-assign", "name" => "Assigned Project"}],
                      "pageInfo" => %{"hasNextPage" => false}
                    },
                    "states" => %{
                      "nodes" => [
                        %{"id" => "state-done", "name" => "Done", "type" => "completed"},
                        %{"id" => "state-progress", "name" => "In Progress", "type" => "started"}
                      ]
                    },
                    "teamMemberships" => %{"nodes" => []},
                    "members" => %{"nodes" => []}
                  }
                }
              }
            }

          String.contains?(query, "IssuesByProjectId") ->
            %Tesla.Env{
              status: 200,
              body: %{
                "data" => %{
                  "issues" => %{
                    "nodes" => [
                      %{
                        "state" => %{
                          "id" => "state-progress",
                          "name" => "In Progress",
                          "type" => "started"
                        },
                        "assignee" => %{"id" => "user-1", "displayName" => "Alice Demo"}
                      },
                      %{
                        "state" => %{
                          "id" => "state-done",
                          "name" => "Done",
                          "type" => "completed"
                        },
                        "assignee" => %{"id" => "user-1", "displayName" => "Alice Demo"}
                      },
                      %{
                        "state" => %{
                          "id" => "state-done",
                          "name" => "Done",
                          "type" => "completed"
                        },
                        "assignee" => %{"id" => "user-2", "displayName" => "Bob Builder"}
                      }
                    ],
                    "pageInfo" => %{"hasNextPage" => false}
                  }
                }
              }
            }

          String.contains?(query, "IssueSearch") ->
            %Tesla.Env{
              status: 200,
              body: %{
                "data" => %{
                  "issueSearch" => %{
                    "nodes" => []
                  }
                }
              }
            }

          true ->
            flunk("Unexpected Linear query: #{inspect({query, vars})}")
        end
    end)
  end
end
