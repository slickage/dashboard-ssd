defmodule DashboardSSD.Integrations.Linear do
  @moduledoc "Basic Linear API client (GraphQL)."
  use Tesla

  @base "https://api.linear.app"

  plug Tesla.Middleware.BaseUrl, @base
  plug Tesla.Middleware.Headers, [{"content-type", "application/json"}]
  plug Tesla.Middleware.JSON

  @doc """
  Execute a Linear GraphQL request (e.g., list/search issues).

  Accepts a GraphQL `query` string and optional `variables` map.
  Note: Linear expects `Authorization: <api-key>` (no "Bearer ").
  Returns {:ok, response_body} on 200 or {:error, term} otherwise.
  """
  @spec list_issues(String.t(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def list_issues(token, query, variables \\ %{}) do
    headers = [{"authorization", token}]
    body = %{query: query, variables: variables}

    case post("/graphql", body, headers: headers) do
      {:ok, %Tesla.Env{status: 200, body: body}} -> {:ok, body}
      {:ok, %Tesla.Env{status: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end
end
