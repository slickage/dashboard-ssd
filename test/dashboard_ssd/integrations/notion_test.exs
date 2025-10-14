defmodule DashboardSSD.Integrations.NotionTest do
  use ExUnit.Case, async: true

  alias DashboardSSD.Integrations.Notion

  @token "tok"
  @namespace {:dashboard_ssd, :notion_circuit}

  setup do
    Notion.reset_circuits()

    on_exit(fn ->
      clear_circuit(:search)
      clear_circuit({:database_query, "db-id"})
      clear_circuit({:database_query, "db-fail"})
      clear_circuit({:block_children, "block-id"})
      Notion.reset_circuits()
    end)
  end

  describe "search/3" do
    test "posts with Notion-Version and auth header" do
      Tesla.Mock.mock(fn
        %{
          method: :post,
          url: "https://api.notion.com/v1/search",
          headers: headers,
          body: body
        } ->
          assert auth_header?(headers)
          assert version_header?(headers)
          body_map = decode_body(body)
          assert body_map["query"] == "dashboard"
          %Tesla.Env{status: 200, body: %{"results" => []}}
      end)

      assert {:ok, %{"results" => []}} = Notion.search(@token, "dashboard")
    end

    test "returns http_error on non-200" do
      Tesla.Mock.mock(fn _ -> %Tesla.Env{status: 429, body: %{"error" => "rate_limited"}} end)

      assert {:error, {:http_error, 429, %{"error" => "rate_limited"}}} =
               Notion.search(@token, "q")
    end

    test "propagates adapter error tuple" do
      Tesla.Mock.mock(fn _ -> {:error, :econnrefused} end)
      assert {:error, :econnrefused} = Notion.search(@token, "q")
    end
  end

  describe "query_database/3" do
    test "posts body with optional filters and sorts" do
      Tesla.Mock.mock(fn
        %{
          method: :post,
          url: "https://api.notion.com/v1/databases/db-id/query",
          body: body,
          headers: headers
        } ->
          assert auth_header?(headers)
          body_map = decode_body(body)
          assert %{"page_size" => 10, "filter" => %{"property" => "Status"}} = body_map
          %Tesla.Env{status: 200, body: %{"results" => []}}
      end)

      assert {:ok, %{"results" => []}} =
               Notion.query_database(@token, "db-id",
                 page_size: 10,
                 filter: %{property: "Status"}
               )
    end

    test "retries on rate limiting and eventually succeeds" do
      sleep = fn _ -> :ok end
      parent = self()

      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.notion.com/v1/databases/db-id/query"} ->
          attempt = Process.get(:attempts, 0)
          Process.put(:attempts, attempt + 1)

          case attempt do
            x when x < 2 ->
              %Tesla.Env{status: 429, body: %{"error" => "rate_limited"}}

            _ ->
              send(parent, :retried)
              %Tesla.Env{status: 200, body: %{"results" => []}}
          end
      end)

      assert {:ok, %{"results" => []}} =
               Notion.query_database(@token, "db-id",
                 sleep: sleep,
                 base_backoff_ms: 1,
                 max_backoff_ms: 2,
                 circuit_cooldown_ms: 20
               )

      assert_receive :retried
      assert Process.get(:attempts) == 3
    end

    test "opens circuit after exhausting retry attempts" do
      sleep = fn _ -> :ok end
      time = fn :millisecond -> 100 end

      Tesla.Mock.mock(fn _ -> %Tesla.Env{status: 429, body: %{"error" => "rate_limited"}} end)

      assert {:error, {:http_error, 429, _}} =
               Notion.query_database(@token, "db-fail",
                 sleep: sleep,
                 base_backoff_ms: 1,
                 max_backoff_ms: 1,
                 max_attempts: 2,
                 circuit_cooldown_ms: 50,
                 time_provider: time
               )

      assert {:error, {:circuit_open, resume_at}} =
               Notion.query_database(@token, "db-fail",
                 sleep: sleep,
                 time_provider: time,
                 circuit_cooldown_ms: 50
               )

      assert resume_at == 150
    end
  end

  describe "retrieve_block_children/3" do
    test "fetches block children with query params" do
      Tesla.Mock.mock(fn
        %{
          method: :get,
          url: "https://api.notion.com/v1/blocks/block-id/children",
          query: query,
          headers: headers
        } ->
          assert auth_header?(headers)
          assert Enum.into(query, %{}) == %{page_size: 100, start_cursor: "cursor"}
          %Tesla.Env{status: 200, body: %{"results" => []}}
      end)

      assert {:ok, %{"results" => []}} =
               Notion.retrieve_block_children(@token, "block-id",
                 page_size: 100,
                 start_cursor: "cursor"
               )
    end
  end

  defp auth_header?(headers),
    do:
      Enum.any?(headers, fn {k, v} ->
        k == "authorization" and String.starts_with?(v, "Bearer ")
      end)

  defp version_header?(headers),
    do: Enum.any?(headers, fn {k, v} -> k == "Notion-Version" and v == "2022-06-28" end)

  defp decode_body(body) when is_binary(body), do: Jason.decode!(body)
  defp decode_body(body), do: body

  defp clear_circuit(key) do
    :persistent_term.erase({@namespace, key})
  rescue
    ArgumentError -> :ok
  end
end
