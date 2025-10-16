defmodule DashboardSSD.Integrations.LinearUtilsTest do
  use ExUnit.Case, async: true

  alias DashboardSSD.Integrations.LinearUtils

  setup do
    # Set linear token for tests
    Application.put_env(:dashboard_ssd, :integrations, linear_token: "test_token")
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
        %{method: :post, url: "https://api.linear.app/graphql"} ->
          %Tesla.Env{status: 200, body: %{"data" => %{"issues" => %{"nodes" => nil}}}}
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

    test "returns :unavailable on error" do
      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.linear.app/graphql"} ->
          %Tesla.Env{status: 500, body: "error"}
      end)

      project = %{name: "test"}
      assert :unavailable = LinearUtils.fetch_linear_summary(project)
    end
  end
end
