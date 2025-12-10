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
