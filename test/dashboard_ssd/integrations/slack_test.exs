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

  test "returns http_error on non-200" do
    Tesla.Mock.mock(fn _ ->
      %Tesla.Env{status: 403, body: %{"ok" => false, "error" => "forbidden"}}
    end)

    assert {:error, {:http_error, 403, %{"ok" => false, "error" => _}}} =
             Slack.send_message("tok", "C123", "hi")
  end

  test "propagates adapter error tuple" do
    Tesla.Mock.mock(fn _ -> {:error, :nxdomain} end)
    assert {:error, :nxdomain} = Slack.send_message("tok", "C123", "hi")
  end
end
