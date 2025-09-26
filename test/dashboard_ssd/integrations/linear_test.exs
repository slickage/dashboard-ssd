defmodule DashboardSSD.Integrations.LinearTest do
  use ExUnit.Case, async: true

  alias DashboardSSD.Integrations.Linear

  setup do
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.linear.app/graphql", headers: headers, body: body} ->
        assert Enum.any?(headers, fn {k, v} -> k == "authorization" and v == "tok" end)

        body_map = if is_binary(body), do: Jason.decode!(body), else: body
        assert Map.has_key?(body_map, "query") or Map.has_key?(body_map, :query)
        %Tesla.Env{status: 200, body: %{"data" => %{"issues" => []}}}
    end)

    :ok
  end

  test "list_issues posts GraphQL with auth header" do
    assert {:ok, %{"data" => %{"issues" => []}}} =
             Linear.list_issues("tok", "{ issues { id } }", %{})
  end

  test "returns http_error on non-200" do
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.linear.app/graphql"} ->
        %Tesla.Env{status: 401, body: %{"message" => "unauthorized"}}
    end)

    assert {:error, {:http_error, 401, %{"message" => _}}} =
             Linear.list_issues("bad", "{ issues { id } }", %{})
  end

  test "propagates adapter error tuple" do
    Tesla.Mock.mock(fn _ -> {:error, :timeout} end)
    assert {:error, :timeout} = Linear.list_issues("tok", "{ q }", %{})
  end
end
