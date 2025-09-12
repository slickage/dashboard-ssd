defmodule DashboardSSD.Integrations.SlackTest do
  use ExUnit.Case, async: true

  alias DashboardSSD.Integrations.Slack

  setup do
    Tesla.Mock.mock(fn
      %{
        method: :post,
        url: "https://slack.com/api/chat.postMessage",
        headers: headers,
        body: body
      } ->
        assert Enum.any?(headers, fn {k, v} ->
                 k == "authorization" and String.starts_with?(v, "Bearer ")
               end)

        _body_map = if is_binary(body), do: Jason.decode!(body), else: body
        %Tesla.Env{status: 200, body: %{"ok" => true}}
    end)

    :ok
  end

  test "send_message posts with auth header" do
    assert {:ok, %{"ok" => true}} = Slack.send_message("tok", "#general", "Hello")
  end
end
