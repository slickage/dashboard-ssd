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

  test "list_transcripts builds variables (clamp, sanitize, configured user)" do
    # Provide a configured user id to prefer over mine when not explicitly set
    prev = Application.get_env(:dashboard_ssd, :integrations)

    Application.put_env(
      :dashboard_ssd,
      :integrations,
      Keyword.merge(prev || [], fireflies_user_id: "user-123")
    )

    on_exit(fn ->
      if prev,
        do: Application.put_env(:dashboard_ssd, :integrations, prev),
        else: Application.delete_env(:dashboard_ssd, :integrations)
    end)

    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
        payload = if is_binary(body), do: Jason.decode!(body), else: body
        vars = Map.get(payload, "variables") || %{}

        # limit should be clamped to 50 when >50 provided
        assert vars["limit"] == 50
        # participants should be sanitized (nil removed)
        assert vars["participants"] == ["a@example.com"]
        # userId should be injected from config and mine should be absent
        assert vars["userId"] == "user-123"
        refute Map.has_key?(vars, "mine")

        %Tesla.Env{status: 200, body: %{"data" => %{"transcripts" => []}}}
    end)

    assert {:ok, []} =
             FirefliesClient.list_transcripts(
               keyword: "weekly",
               participants: ["a@example.com", nil],
               limit: 100
             )
  end

  test "get_bite returns ok, not_found, and maps GraphQL errors" do
    # ok path
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql"} ->
        %Tesla.Env{
          status: 200,
          body: %{"data" => %{"bite" => %{"id" => "b1", "transcript_id" => "t1"}}}
        }
    end)

    assert {:ok, %{"id" => "b1", "transcript_id" => "t1"}} = FirefliesClient.get_bite("b1")

    # not_found path
    Tesla.Mock.mock(fn _ -> %Tesla.Env{status: 200, body: %{"data" => %{"bite" => nil}}} end)
    assert {:error, :not_found} = FirefliesClient.get_bite("missing")

    # GraphQL error mapping (rate limited)
    Tesla.Mock.mock(fn _ ->
      %Tesla.Env{
        status: 200,
        body: %{"errors" => [%{"code" => "too_many_requests", "message" => "Burst"}]}
      }
    end)

    assert {:error, {:rate_limited, "Burst"}} = FirefliesClient.get_bite("b2")
  end

  test "list_users returns ok and graphql errors" do
    Tesla.Mock.mock(fn _ ->
      %Tesla.Env{status: 200, body: %{"data" => %{"users" => [%{"user_id" => "u1"}]}}}
    end)

    assert {:ok, [%{"user_id" => "u1"}]} = FirefliesClient.list_users()

    Tesla.Mock.mock(fn _ ->
      %Tesla.Env{status: 200, body: %{"errors" => [%{"message" => "bad"}]}}
    end)

    assert {:error, {:graphql_error, _}} = FirefliesClient.list_users()
  end

  test "missing token returns error" do
    prev = Application.get_env(:dashboard_ssd, :integrations)

    Application.put_env(
      :dashboard_ssd,
      :integrations,
      Keyword.delete(prev || [], :fireflies_api_token)
    )

    prev_env = System.get_env("FIREFLIES_API_TOKEN")
    System.delete_env("FIREFLIES_API_TOKEN")

    on_exit(fn ->
      if prev,
        do: Application.put_env(:dashboard_ssd, :integrations, prev),
        else: Application.delete_env(:dashboard_ssd, :integrations)

      if prev_env, do: System.put_env("FIREFLIES_API_TOKEN", prev_env)
    end)

    assert {:error, {:missing_env, "FIREFLIES_API_TOKEN"}} = FirefliesClient.list_bites()
  end

  test "HTTP 429 maps to rate_limited via handle_http_error" do
    Tesla.Mock.mock(fn _ ->
      %Tesla.Env{status: 429, body: %{"errors" => [%{"message" => "Burst"}]}}
    end)

    assert {:error, {:rate_limited, "Burst"}} = FirefliesClient.list_transcripts()
  end

  test "get_transcript_summary returns defaults when missing data" do
    Tesla.Mock.mock(fn _ -> %Tesla.Env{status: 200, body: %{"data" => %{"foo" => "bar"}}} end)

    assert {:ok, %{notes: nil, action_items: [], bullet_gist: nil}} =
             FirefliesClient.get_transcript_summary("t-missing")
  end
end
