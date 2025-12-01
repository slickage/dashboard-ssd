defmodule DashboardSSD.Integrations.NotionTest do
  use ExUnit.Case, async: true

  import Tesla.Mock

  alias DashboardSSD.Integrations.Notion

  setup do
    :ok = mock(fn env -> handle_request(env) end)
    :ok
  end

  defp handle_request(%{method: :post, url: "https://api.notion.com/v1/search"} = env) do
    body = decode_body(env.body)

    {:ok, %Tesla.Env{status: 200, body: %{"results" => [%{"query" => body["query"]}]}}}
  end

  defp handle_request(
         %{method: :post, url: "https://api.notion.com/v1/databases/db-1/query"} = env
       ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: %{"results" => [%{"body" => decode_body(env.body)}]}
     }}
  end

  defp handle_request(%{method: :post, url: "https://api.notion.com/v1/databases"} = env) do
    {:ok, %Tesla.Env{status: 200, body: Map.put(decode_body(env.body), "id", "db-1")}}
  end

  defp handle_request(%{method: :post, url: "https://api.notion.com/v1/pages"} = env) do
    {:ok, %Tesla.Env{status: 200, body: Map.put(decode_body(env.body), "id", "page-1")}}
  end

  defp handle_request(
         %{method: :patch, url: "https://api.notion.com/v1/blocks/block-1/children"} = env
       ) do
    {:ok, %Tesla.Env{status: 200, body: decode_body(env.body)}}
  end

  defp handle_request(%{method: :delete, url: "https://api.notion.com/v1/blocks/block-1"}) do
    {:ok, %Tesla.Env{status: 200, body: %{"object" => "block"}}}
  end

  defp handle_request(%{method: :get, url: "https://api.notion.com/v1/databases/db-1"}) do
    {:ok, %Tesla.Env{status: 200, body: %{"id" => "db-1"}}}
  end

  defp handle_request(%{method: :get, url: "https://api.notion.com/v1/pages/page-1"}) do
    {:ok, %Tesla.Env{status: 200, body: %{"id" => "page-1"}}}
  end

  defp handle_request(%{
         method: :get,
         url: "https://api.notion.com/v1/blocks/block-1/children",
         query: query
       }) do
    body =
      if Enum.empty?(query) do
        %{
          "results" => [%{"id" => "block-1-child"}],
          "has_more" => true,
          "next_cursor" => "cursor"
        }
      else
        %{"results" => [%{"id" => "block-1-child-2"}], "has_more" => false}
      end

    {:ok, %Tesla.Env{status: 200, body: body}}
  end

  defp handle_request(%{method: :post, url: "https://oauth2.googleapis.com/token"}) do
    {:ok, %Tesla.Env{status: 500, body: %{"error" => "wrong module"}}}
  end

  defp decode_body(body) when is_binary(body), do: Jason.decode!(body)
  defp decode_body(body), do: body

  describe "basic requests" do
    test "search/3 sends query" do
      assert {:ok, %{"results" => [%{"query" => "projects"}]}} =
               Notion.search("tok", "projects", body: %{filter: %{}})
    end

    test "list_databases/2 applies default body" do
      assert {:ok, %{"results" => [%{"query" => "proj"}]}} =
               Notion.list_databases("tok", query: "proj", page_size: 5)
    end

    test "retrieve helpers return payloads" do
      assert {:ok, %{"id" => "db-1"}} = Notion.retrieve_database("tok", "db-1")
      assert {:ok, %{"id" => "page-1"}} = Notion.retrieve_page("tok", "page-1")
    end

    test "query_database posts filters" do
      assert {:ok, %{"results" => [%{"body" => body}]}} =
               Notion.query_database("tok", "db-1", filter: %{property: "Name"})

      assert body["filter"]["property"] == "Name"
    end

    test "retrieve_block_children fetches pagination" do
      assert {:ok, %{"results" => results, "has_more" => true}} =
               Notion.retrieve_block_children("tok", "block-1")

      assert length(results) == 1
    end

    test "create helpers return ids" do
      assert {:ok, %{"id" => "page-1"}} =
               Notion.create_page("tok", %{parent: %{database_id: "db-1"}})

      assert {:ok, %{"id" => "db-1"}} =
               Notion.create_database("tok", %{parent: %{page_id: "page-1"}})
    end

    test "append_block_children and delete_block succeed" do
      assert {:ok, %{"children" => [%{"type" => "paragraph"}]}} =
               Notion.append_block_children("tok", "block-1", [%{"type" => "paragraph"}])

      assert {:ok, %{"object" => "block"}} = Notion.delete_block("tok", "block-1")
    end

    test "search surfaces HTTP errors" do
      mock(fn %{method: :post, url: "https://api.notion.com/v1/search"} ->
        {:ok, %Tesla.Env{status: 500, body: %{"error" => "boom"}}}
      end)

      assert {:error, {:http_error, 500, %{"error" => "boom"}}} =
               Notion.search("tok", "broken")

      mock(&handle_request/1)
      Notion.reset_circuits()
    end

    test "retrieve_database returns error when request fails" do
      mock(fn %{method: :get, url: "https://api.notion.com/v1/databases/db-error"} ->
        {:ok, %Tesla.Env{status: 404, body: %{"error" => "not found"}}}
      end)

      assert {:error, {:http_error, 404, %{"error" => "not found"}}} =
               Notion.retrieve_database("tok", "db-error")

      mock(&handle_request/1)
      Notion.reset_circuits()
    end
  end
end
