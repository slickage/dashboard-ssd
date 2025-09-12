defmodule DashboardSSD.Integrations.Drive do
  @moduledoc "Basic Google Drive API client (list files in folder)."
  use Tesla

  @base "https://www.googleapis.com/drive/v3"

  plug Tesla.Middleware.BaseUrl, @base
  plug Tesla.Middleware.Query
  plug Tesla.Middleware.Headers, [{"content-type", "application/json"}]
  plug Tesla.Middleware.JSON

  @doc "List files in a given folder id."
  @spec list_files_in_folder(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def list_files_in_folder(token, folder_id) do
    headers = [{"authorization", "Bearer #{token}"}]
    params = [q: "'#{folder_id}' in parents"]

    case get("/files", query: params, headers: headers) do
      {:ok, %Tesla.Env{status: 200, body: body}} -> {:ok, body}
      {:ok, %Tesla.Env{status: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end
end
