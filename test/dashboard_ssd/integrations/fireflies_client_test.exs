defmodule DashboardSSD.Integrations.FirefliesClientTest do
  use DashboardSSD.DataCase, async: false

  import ExUnit.CaptureLog
  alias DashboardSSD.Integrations.FirefliesClient

  setup do
    prev = Application.get_env(:dashboard_ssd, :integrations)

    Application.put_env(
      :dashboard_ssd,
      :integrations,
      Keyword.merge(prev || [], fireflies_api_token: "secret-token")
    )

    on_exit(fn ->
      if prev,
        do: Application.put_env(:dashboard_ssd, :integrations, prev),
        else: Application.delete_env(:dashboard_ssd, :integrations)
    end)

    :ok
  end

  test "get_transcript_summary maps notes, action_items, bullet_gist" do
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql"} ->
        %Tesla.Env{
          status: 200,
          body: %{
            "data" => %{
              "transcript" => %{
                "summary" => %{
                  "overview" => "Notes here",
                  "short_summary" => "Short",
                  "action_items" => ["One", "Two"],
                  "bullet_gist" => "• One\n• Two"
                }
              }
            }
          }
        }
    end)

    assert {:ok,
            %{notes: "Notes here", action_items: ["One", "Two"], bullet_gist: "• One\n• Two"}} =
             FirefliesClient.get_transcript_summary("t1")
  end

  test "list_bites returns mapped list with created_from and transcript_id" do
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql"} ->
        %Tesla.Env{
          status: 200,
          body: %{
            "data" => %{
              "bites" => [
                %{"id" => "b1", "transcript_id" => "t1", "created_from" => %{"id" => "series-1"}},
                %{"id" => "b2", "transcript_id" => "t2", "created_from" => %{"id" => "series-2"}}
              ]
            }
          }
        }
    end)

    assert {:ok, bites} = FirefliesClient.list_bites(limit: 2)
    assert Enum.any?(bites, &(&1["id"] == "b1" and &1["transcript_id"] == "t1"))
    assert Enum.any?(bites, &(&1["created_from"]["id"] == "series-2"))
  end

  test "does not log Authorization token" do
    Tesla.Mock.mock(fn _ -> %Tesla.Env{status: 200, body: %{"data" => %{"bites" => []}}} end)

    log = capture_log(fn -> FirefliesClient.list_bites(limit: 1) end)
    refute String.contains?(log, "secret-token")
    refute String.contains?(log, "Authorization")
  end

  test "rate limit error is mapped from GraphQL errors for bites" do
    Tesla.Mock.mock(fn %{method: :post, url: "https://api.fireflies.ai/graphql"} ->
      %Tesla.Env{
        status: 200,
        body: %{
          "data" => nil,
          "errors" => [
            %{
              "code" => "too_many_requests",
              "message" => "Too many requests. Please retry after 12:35:57 AM (UTC)",
              "extensions" => %{"code" => "too_many_requests", "status" => 429}
            }
          ]
        }
      }
    end)

    assert {:error, {:rate_limited, msg}} = FirefliesClient.list_bites(limit: 1)
    assert String.contains?(msg, "Too many requests")
  end

  test "rate limit error is mapped from GraphQL errors for transcript summary" do
    Tesla.Mock.mock(fn %{method: :post, url: "https://api.fireflies.ai/graphql"} ->
      %Tesla.Env{
        status: 200,
        body: %{
          "data" => nil,
          "errors" => [
            %{
              "code" => "too_many_requests",
              "message" => "Too many requests. Please retry after 12:00:00 AM (UTC)",
              "extensions" => %{"code" => "too_many_requests", "status" => 429}
            }
          ]
        }
      }
    end)

    assert {:error, {:rate_limited, msg}} = FirefliesClient.get_transcript_summary("t1")
    assert String.contains?(msg, "Too many requests")
  end
end
