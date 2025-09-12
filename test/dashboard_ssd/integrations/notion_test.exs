defmodule DashboardSSD.Integrations.NotionTest do
  use ExUnit.Case, async: true

  alias DashboardSSD.Integrations.Notion

  setup do
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.notion.com/v1/search", headers: headers, body: body} ->
        assert Enum.any?(headers, fn {k, v} ->
                 k == "authorization" and String.starts_with?(v, "Bearer ")
               end)

        assert Enum.any?(headers, fn {k, _v} -> k == "Notion-Version" end)
        _body_map = if is_binary(body), do: Jason.decode!(body), else: body
        %Tesla.Env{status: 200, body: %{"results" => []}}
    end)

    :ok
  end

  test "search posts with Notion-Version and auth header" do
    assert {:ok, %{"results" => []}} = Notion.search("tok", "dashboard")
  end
end
