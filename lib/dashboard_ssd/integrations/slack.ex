defmodule DashboardSSD.Integrations.Slack do
  @moduledoc """
  Basic Slack API client (chat.postMessage).

    - Configures a Tesla client pointed at the Slack Web API.
  - Sends channel messages using bot/user tokens provided at runtime.
  - Normalizes success/error tuples for higher-level notification workflows.
  """
  use Tesla

  @base "https://slack.com/api"

  plug Tesla.Middleware.BaseUrl, @base
  plug Tesla.Middleware.Headers, [{"content-type", "application/json"}]
  plug Tesla.Middleware.JSON

  @doc "Send a message to a Slack channel."
  @spec send_message(String.t(), String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def send_message(token, channel, text) do
    headers = [{"authorization", "Bearer #{token}"}]
    body = %{channel: channel, text: text}

    case post("/chat.postMessage", body, headers: headers) do
      {:ok, %Tesla.Env{status: 200, body: body}} -> {:ok, body}
      {:ok, %Tesla.Env{status: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end
end
