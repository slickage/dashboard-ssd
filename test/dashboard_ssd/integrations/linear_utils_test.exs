defmodule DashboardSSD.Integrations.LinearUtilsTest do
  use DashboardSSD.DataCase, async: false

  alias DashboardSSD.Integrations.LinearUtils
  alias DashboardSSD.Projects.LinearWorkflowState
  alias DashboardSSD.Repo

  setup do
    # Set linear token for tests
    Application.put_env(:dashboard_ssd, :integrations, linear_token: "test_token")
    previous_adapter = Application.get_env(:tesla, :adapter)
    Application.put_env(:tesla, :adapter, Tesla.Mock)

    on_exit(fn ->
      case previous_adapter do
        nil -> Application.delete_env(:tesla, :adapter)
        adapter -> Application.put_env(:tesla, :adapter, adapter)
      end
    end)

    :ok
  end

  describe "issue_nodes_for_project/1" do
    test "returns nodes from first successful query" do
      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.linear.app/graphql"} ->
          %Tesla.Env{
            status: 200,
            body: %{"data" => %{"issues" => %{"nodes" => [%{"id" => "1"}]}}}
          }
      end)

      assert {:ok, [%{"id" => "1"}]} = LinearUtils.issue_nodes_for_project("test")
    end

    test "tries next query on invalid responses" do
      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.linear.app/graphql", body: body} ->
          body_map = Jason.decode!(body)
          query = body_map["query"]

          if String.contains?(query, "issueSearch") do
            %Tesla.Env{
              status: 200,
              body: %{"data" => %{"issueSearch" => %{"nodes" => [%{"id" => "2"}]}}}
            }
          else
            %Tesla.Env{status: 200, body: %{"data" => %{"issues" => %{"nodes" => nil}}}}
          end
      end)

      assert {:ok, [%{"id" => "2"}]} = LinearUtils.issue_nodes_for_project("test")
    end

    test "returns :empty when all queries return invalid" do
      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.linear.app/graphql", body: body} ->
          body_map = Jason.decode!(body)
          query = body_map["query"]

          cond do
            String.contains?(query, "IssuesByProject($name: String!, $first: Int!)") ->
              %Tesla.Env{status: 200, body: %{"data" => %{"issues" => %{"nodes" => nil}}}}

            String.contains?(query, "IssuesByProjectContains($name: String!, $first: Int!)") ->
              %Tesla.Env{status: 200, body: %{"data" => %{"issues" => %{"nodes" => nil}}}}

            String.contains?(query, "IssueSearch($q: String!)") ->
              %Tesla.Env{status: 200, body: %{"data" => %{"issueSearch" => %{"nodes" => nil}}}}

            true ->
              raise "Unexpected query in mock: #{query}"
          end
      end)

      assert :empty = LinearUtils.issue_nodes_for_project("test")
    end

    test "returns :error on API errors" do
      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.linear.app/graphql"} ->
          %Tesla.Env{status: 500, body: "error"}
      end)

      assert :error = LinearUtils.issue_nodes_for_project("test")
    end
  end

  describe "issue_nodes_for_project_id/1" do
    test "returns paginated nodes" do
      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.linear.app/graphql", body: body} ->
          %{"query" => query, "variables" => vars} = Jason.decode!(body)

          if String.contains?(query, "IssuesByProjectId") do
            case Map.get(vars, "after") do
              nil ->
                %Tesla.Env{
                  status: 200,
                  body: %{
                    "data" => %{
                      "issues" => %{
                        "nodes" => [%{"id" => "1"}],
                        "pageInfo" => %{"hasNextPage" => true, "endCursor" => "c1"}
                      }
                    }
                  }
                }

              "c1" ->
                %Tesla.Env{
                  status: 200,
                  body: %{
                    "data" => %{
                      "issues" => %{
                        "nodes" => [%{"id" => "2"}, %{"id" => "3"}],
                        "pageInfo" => %{"hasNextPage" => false}
                      }
                    }
                  }
                }

              other ->
                flunk("Unexpected pagination cursor: #{inspect(other)}")
            end
          else
            flunk("Unexpected query: #{query}")
          end
      end)

      assert {:ok, nodes} = LinearUtils.issue_nodes_for_project_id("proj-123")
      assert Enum.map(nodes, & &1["id"]) == ["1", "2", "3"]
    end

    test "returns :error when Linear responds with error" do
      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.linear.app/graphql"} ->
          %Tesla.Env{status: 500, body: "oops"}
      end)

      assert {:error, _} = LinearUtils.issue_nodes_for_project_id("proj-error")
    end

    test "returns :empty when no issues found" do
      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.linear.app/graphql"} ->
          %Tesla.Env{
            status: 200,
            body: %{
              "data" => %{
                "issues" => %{"nodes" => nil, "pageInfo" => %{"hasNextPage" => false}}
              }
            }
          }
      end)

      assert {:ok, []} = LinearUtils.issue_nodes_for_project_id("proj-empty")
    end

    test "returns {:error, {:unexpected, _}} on malformed response" do
      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.linear.app/graphql"} ->
          %Tesla.Env{
            status: 200,
            body: %{"unexpected" => "structure"}
          }
      end)

      assert {:error, {:unexpected, %{"unexpected" => "structure"}}} =
               LinearUtils.issue_nodes_for_project_id("proj-bad")
    end

    test "returns :empty when API omits nodes entirely" do
      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.linear.app/graphql"} ->
          %Tesla.Env{
            status: 200,
            body: %{"data" => %{"issues" => %{"nodes" => nil}}}
          }
      end)

      assert :empty = LinearUtils.issue_nodes_for_project_id("proj-none")
    end

    test "preserves accumulated results when later page is empty" do
      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.linear.app/graphql", body: body} ->
          call = Process.get(:linear_issues_call, 0)
          Process.put(:linear_issues_call, call + 1)

          %{"variables" => vars} = Jason.decode!(body)

          case call do
            0 ->
              %Tesla.Env{
                status: 200,
                body: %{
                  "data" => %{
                    "issues" => %{
                      "nodes" => [%{"id" => "keep"}],
                      "pageInfo" => %{"hasNextPage" => true, "endCursor" => "cursor-1"}
                    }
                  }
                }
              }

            _ ->
              assert vars["after"] == "cursor-1"

              %Tesla.Env{
                status: 200,
                body: %{"data" => %{"issues" => %{"nodes" => nil}}}
              }
          end
      end)

      assert {:ok, [%{"id" => "keep"}]} = LinearUtils.issue_nodes_for_project_id("proj-partial")
    end
  end

  describe "summarize_issue_nodes/1" do
    test "counts issues by state" do
      nodes = [
        %{"state" => %{"name" => "Done"}},
        %{"state" => %{"name" => "In Progress"}},
        %{"state" => %{"name" => "Todo"}}
      ]

      assert %{total: 3, in_progress: 1, finished: 1} = LinearUtils.summarize_issue_nodes(nodes)
    end

    test "handles missing state" do
      nodes = [%{"state" => nil}, %{"state" => %{"name" => nil}}]

      assert %{total: 2, in_progress: 0, finished: 0} = LinearUtils.summarize_issue_nodes(nodes)
    end

    test "recognizes various done states" do
      nodes = [
        %{"state" => %{"name" => "Completed"}},
        %{"state" => %{"name" => "Closed"}},
        %{"state" => %{"name" => "Merged"}},
        %{"state" => %{"name" => "Released"}},
        %{"state" => %{"name" => "Shipped"}},
        %{"state" => %{"name" => "Resolved"}}
      ]

      assert %{total: 6, in_progress: 0, finished: 6} = LinearUtils.summarize_issue_nodes(nodes)
    end

    test "recognizes various in progress states" do
      nodes = [
        %{"state" => %{"name" => "In Progress"}},
        %{"state" => %{"name" => "Doing"}},
        %{"state" => %{"name" => "Started"}},
        %{"state" => %{"name" => "Active"}},
        %{"state" => %{"name" => "In Review"}},
        %{"state" => %{"name" => "In QA"}},
        %{"state" => %{"name" => "Testing"}},
        %{"state" => %{"name" => "Blocked"}},
        %{"state" => %{"name" => "Verify"}}
      ]

      assert %{total: 9, in_progress: 9, finished: 0} = LinearUtils.summarize_issue_nodes(nodes)
    end

    test "treats canceled workflow type as finished" do
      nodes = [
        %{"state" => %{"id" => "state-1", "type" => "canceled"}}
      ]

      assert %{total: 1, in_progress: 0, finished: 1} =
               LinearUtils.summarize_issue_nodes(nodes, %{"state-1" => %{type: "canceled"}})
    end
  end

  describe "fetch_linear_summary/1" do
    test "returns summary when successful" do
      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.linear.app/graphql"} ->
          %Tesla.Env{
            status: 200,
            body: %{"data" => %{"issues" => %{"nodes" => [%{"state" => %{"name" => "Done"}}]}}}
          }
      end)

      project = %{name: "test"}
      assert %{total: 1, in_progress: 0, finished: 1} = LinearUtils.fetch_linear_summary(project)
    end

    test "returns zero counts on empty" do
      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.linear.app/graphql"} ->
          %Tesla.Env{status: 200, body: %{"data" => %{"issues" => %{"nodes" => []}}}}
      end)

      project = %{name: "test"}
      assert %{total: 0, in_progress: 0, finished: 0} = LinearUtils.fetch_linear_summary(project)
    end

    test "uses workflow metadata when available" do
      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.linear.app/graphql", body: body} ->
          %{"query" => query} = Jason.decode!(body)

          if String.contains?(query, "IssuesByProjectId") do
            %Tesla.Env{
              status: 200,
              body: %{
                "data" => %{
                  "issues" => %{
                    "nodes" => [
                      %{"state" => %{"id" => "state-done"}},
                      %{"state" => %{"id" => "state-started"}}
                    ],
                    "pageInfo" => %{"hasNextPage" => false}
                  }
                }
              }
            }
          else
            flunk("Unexpected query: #{query}")
          end
      end)

      Repo.insert!(%LinearWorkflowState{
        linear_team_id: "team-1",
        linear_state_id: "state-done",
        name: "Done",
        type: "completed"
      })

      Repo.insert!(%LinearWorkflowState{
        linear_team_id: "team-1",
        linear_state_id: "state-started",
        name: "Doing",
        type: "started"
      })

      project = %{linear_project_id: "proj-1", linear_team_id: "team-1"}
      assert %{total: 2, in_progress: 1, finished: 1} = LinearUtils.fetch_linear_summary(project)
    end

    test "returns :unavailable on error" do
      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.linear.app/graphql"} ->
          %Tesla.Env{status: 500, body: "error"}
      end)

      project = %{name: "test"}
      assert :unavailable = LinearUtils.fetch_linear_summary(project)
    end

    test "returns zero results when project lacks identifiers" do
      project = %{}
      assert %{total: 0, in_progress: 0, finished: 0} = LinearUtils.fetch_linear_summary(project)
    end

    test "falls back to project name when project id query errors" do
      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.linear.app/graphql", body: body} ->
          %{"query" => query, "variables" => vars} = Jason.decode!(body)

          cond do
            String.contains?(query, "IssuesByProjectId") ->
              assert vars["projectId"] == "proj-error"
              %Tesla.Env{status: 500, body: %{"errors" => ["boom"]}}

            String.contains?(query, "IssuesByProject($name: String!, $first: Int!)") ->
              assert vars["name"] == "Fallback Project"

              %Tesla.Env{
                status: 200,
                body: %{
                  "data" => %{
                    "issues" => %{
                      "nodes" => [
                        %{"state" => %{"name" => "Done"}},
                        %{"state" => %{"name" => "In Progress"}}
                      ],
                      "pageInfo" => %{"hasNextPage" => false}
                    }
                  }
                }
              }

            true ->
              flunk("Unexpected Linear query: #{query}")
          end
      end)

      project = %{linear_project_id: "proj-error", name: "Fallback Project"}
      assert %{total: 2, in_progress: 1, finished: 1} = LinearUtils.fetch_linear_summary(project)
    end
  end

  describe "linear_enabled?/0" do
    setup do
      original_config = Application.get_env(:dashboard_ssd, :integrations)
      original_token = System.get_env("LINEAR_TOKEN")
      original_api_key = System.get_env("LINEAR_API_KEY")

      on_exit(fn ->
        case original_config do
          nil -> Application.delete_env(:dashboard_ssd, :integrations)
          config -> Application.put_env(:dashboard_ssd, :integrations, config)
        end

        reset_env("LINEAR_TOKEN", original_token)
        reset_env("LINEAR_API_KEY", original_api_key)
      end)

      :ok
    end

    test "returns true when token present in config" do
      Application.put_env(:dashboard_ssd, :integrations, linear_token: " config_token ")
      assert LinearUtils.linear_enabled?()
    end

    test "falls back to LINEAR_TOKEN env" do
      Application.put_env(:dashboard_ssd, :integrations, linear_token: nil)
      System.put_env("LINEAR_TOKEN", " env_token ")
      assert LinearUtils.linear_enabled?()
    end

    test "falls back to LINEAR_API_KEY env" do
      Application.put_env(:dashboard_ssd, :integrations, linear_token: nil)
      System.delete_env("LINEAR_TOKEN")
      System.put_env("LINEAR_API_KEY", " api_key ")
      assert LinearUtils.linear_enabled?()
    end

    test "returns false when no tokens configured" do
      Application.put_env(:dashboard_ssd, :integrations, linear_token: nil)
      System.delete_env("LINEAR_TOKEN")
      System.delete_env("LINEAR_API_KEY")
      refute LinearUtils.linear_enabled?()
    end
  end

  defp reset_env(var, nil), do: System.delete_env(var)
  defp reset_env(var, value), do: System.put_env(var, value)
end
