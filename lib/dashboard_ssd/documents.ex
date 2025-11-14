defmodule DashboardSSD.Documents do
  @moduledoc """
  Documents context entry points (shared documents listings, cache helpers, etc.).
  """
  import Ecto.Query

  alias DashboardSSD.Accounts.User
  alias DashboardSSD.Cache.SharedDocumentsCache
  alias DashboardSSD.Documents.SharedDocument
  alias DashboardSSD.Repo

  @doc """
  Lists client-visible shared documents for the user's client scope.
  """
  @spec list_client_documents(User.t(), keyword()) ::
          {:ok, [SharedDocument.t()]} | {:error, term()}
  def list_client_documents(%User{id: user_id, client_id: client_id}, opts)
      when is_integer(user_id) and is_integer(client_id) do
    project_id = Keyword.get(opts, :project_id)
    scope = {user_id, project_id}

    SharedDocumentsCache.fetch_listing(scope, fn ->
      {:ok, Repo.all(client_documents_query(client_id, project_id))}
    end)
  end

  def list_client_documents(_user, _opts), do: {:error, :client_scope_missing}

  defp client_documents_query(client_id, project_id) do
    base =
      from sd in SharedDocument,
        where: sd.client_id == ^client_id and sd.visibility == :client,
        order_by: [desc: sd.updated_at]

    maybe_filter_project(base, project_id)
  end

  defp maybe_filter_project(query, nil), do: query

  defp maybe_filter_project(query, project_id) do
    from sd in query,
      where: sd.project_id == ^project_id or is_nil(sd.project_id)
  end
end
