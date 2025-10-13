defmodule DashboardSSD.Integrations.Notion do
  @moduledoc "Basic Notion API client (search)."
  @behaviour DashboardSSD.Integrations.Notion.Behaviour
  use Tesla

  @base "https://api.notion.com"
  @version "2022-06-28"

  plug Tesla.Middleware.BaseUrl, @base

  plug Tesla.Middleware.Headers, [
    {"content-type", "application/json"},
    {"Notion-Version", @version}
  ]

  plug Tesla.Middleware.JSON

  @doc "Search pages or databases with a query string."
  @spec search(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def search(token, query) do
    headers = [{"authorization", "Bearer #{token}"}]
    body = %{query: query}

    case post("/v1/search", body, headers: headers) do
      {:ok, %Tesla.Env{status: 200, body: body}} -> {:ok, body}
      {:ok, %Tesla.Env{status: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end
end
