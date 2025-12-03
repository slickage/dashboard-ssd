defmodule DashboardSSD.Analytics.WorkloadTest do
  use DashboardSSD.DataCase, async: false

  alias DashboardSSD.Analytics.Workload

  describe "summarize_all_projects/1" do
    setup do
      original_config = Application.get_env(:dashboard_ssd, :integrations)
      original_adapter = Application.get_env(:tesla, :adapter)

      on_exit(fn ->
        case original_config do
          nil -> Application.delete_env(:dashboard_ssd, :integrations)
          config -> Application.put_env(:dashboard_ssd, :integrations, config)
        end

        case original_adapter do
          nil -> Application.delete_env(:tesla, :adapter)
          adapter -> Application.put_env(:tesla, :adapter, adapter)
        end
      end)

      :ok
    end

    test "returns zeros when linear integration disabled" do
      Application.delete_env(:dashboard_ssd, :integrations)
      System.delete_env("LINEAR_TOKEN")
      System.delete_env("LINEAR_API_KEY")

      assert %{total: 0, in_progress: 0, finished: 0} ==
               Workload.summarize_all_projects([%{name: "Any"}])
    end

    test "aggregates project summaries when integration enabled" do
      Application.put_env(:dashboard_ssd, :integrations, linear_token: "token")
      Application.put_env(:tesla, :adapter, Tesla.Mock)

      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.linear.app/graphql", body: body} ->
          %{"query" => query, "variables" => vars} = Jason.decode!(body)

          if String.contains?(query, "IssuesByProjectId") do
            nodes =
              case vars["projectId"] do
                "proj-a" ->
                  [
                    %{"state" => %{"name" => "Done"}},
                    %{"state" => %{"name" => "In Progress"}}
                  ]

                "proj-b" ->
                  [
                    %{"state" => %{"name" => "Completed"}},
                    %{"state" => %{"name" => "Completed"}}
                  ]
              end

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
          else
            flunk("Unexpected Linear query: #{query}")
          end
      end)

      projects = [
        %{linear_project_id: "proj-a", linear_team_id: "team-1"},
        %{linear_project_id: "proj-b", linear_team_id: "team-1"}
      ]

      summary = Workload.summarize_all_projects(projects)

      assert summary.total == 4
      assert summary.in_progress == 1
      assert summary.finished == 3
    end
  end

  describe "percent/2" do
    test "returns zero when total is zero" do
      assert Workload.percent(5, 0) == 0
    end

    test "returns truncated percentage for positive totals" do
      assert Workload.percent(3, 4) == 75
      assert Workload.percent(1, 3) == 33
    end
  end
end
