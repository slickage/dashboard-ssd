defmodule DashboardSSD.Integrations.FirefliesClientTest do
  use ExUnit.Case, async: true

  alias DashboardSSD.Integrations.FirefliesClient

  setup do
    # Provide token via app env
    prev_integrations = Application.get_env(:dashboard_ssd, :integrations)
    prev_tesla = Application.get_env(:tesla, :adapter)

    Application.put_env(
      :dashboard_ssd,
      :integrations,
      Keyword.merge(prev_integrations || [], fireflies_api_token: "test-token")
    )

    Application.put_env(:tesla, :adapter, Tesla.Mock)

    on_exit(fn ->
      case prev_integrations do
        nil -> Application.delete_env(:dashboard_ssd, :integrations)
        v -> Application.put_env(:dashboard_ssd, :integrations, v)
      end

      case prev_tesla do
        nil -> Application.delete_env(:tesla, :adapter)
        v -> Application.put_env(:tesla, :adapter, v)
      end
    end)

    :ok
  end

  test "list_bites returns [] on unexpected ok shape" do
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql"} ->
        %Tesla.Env{status: 200, body: %{"data" => %{"foo" => "bar"}}}
    end)

    assert {:ok, []} = FirefliesClient.list_bites(limit: 1)
  end

  test "list_bites returns http_error on non-200" do
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql"} ->
        %Tesla.Env{status: 500, body: %{"error" => "boom"}}
    end)

    assert {:error, {:http_error, 500, %{"error" => "boom"}}} =
             FirefliesClient.list_bites(limit: 1)
  end

  test "list_bites returns rate_limited when GraphQL errors include too_many_requests" do
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql"} ->
        %Tesla.Env{
          status: 200,
          body: %{"errors" => [%{"code" => "too_many_requests", "message" => "retry later"}]}
        }
    end)

    assert {:error, {:rate_limited, "retry later"}} = FirefliesClient.list_bites()
  end

  test "list_bites returns rate_limited via http 429 using message from errors" do
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql"} ->
        %Tesla.Env{status: 429, body: %{"errors" => [%{"message" => "slow down"}]}}
    end)

    assert {:error, {:rate_limited, "slow down"}} = FirefliesClient.list_bites()
  end

  test "list_transcripts bubbles Tesla error reason" do
    Tesla.Mock.mock(fn _ -> {:error, :econnrefused} end)
    assert {:error, :econnrefused} = FirefliesClient.list_transcripts()
  end

  test "list_transcripts builds variables from configured_user_id and sanitizes lists" do
    # configure fireflies_user_id and sanitize organizers/participants
    Application.put_env(:dashboard_ssd, :integrations,
      fireflies_api_token: "t",
      fireflies_user_id: " uid "
    )

    Tesla.Mock.mock(fn %{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
      payload = if is_binary(body), do: Jason.decode!(body), else: body
      vars = Map.get(payload, "variables") || %{}

      if vars["userId"] == "uid" and vars["mine"] == nil and vars["organizers"] == ["a", "b"] and
           vars["participants"] == [] do
        %Tesla.Env{status: 200, body: %{"data" => %{"transcripts" => []}}}
      else
        flunk("unexpected variables: #{inspect(vars)}")
      end
    end)

    assert {:ok, []} =
             FirefliesClient.list_transcripts(organizers: ["a", nil, "b"], participants: [nil])
  end

  test "get_transcript_summary returns graphql_error when errors and not rate-limited" do
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql"} ->
        %Tesla.Env{status: 200, body: %{"errors" => [%{"message" => "boom"}]}}
    end)

    assert {:error, {:graphql_error, _}} = FirefliesClient.get_transcript_summary("t1")
  end

  test "get_bite returns :not_found on ok without bite" do
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql"} ->
        %Tesla.Env{status: 200, body: %{"data" => %{}}}
    end)

    assert {:error, :not_found} = FirefliesClient.get_bite("b1")
  end

  test "get_summary_for_transcript returns defaults on ok without bites" do
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql"} ->
        %Tesla.Env{status: 200, body: %{"data" => %{"bites" => []}}}
    end)

    assert {:ok, %{notes: nil, action_items: [], bullet_gist: nil}} =
             FirefliesClient.get_summary_for_transcript("t1")
  end

  test "list_users returns [] on ok without users" do
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql"} ->
        %Tesla.Env{status: 200, body: %{"data" => %{}}}
    end)

    assert {:ok, []} = FirefliesClient.list_users()
  end
end
