defmodule DashboardSSD.Documents do
  @moduledoc """
  Documents context entry points (shared documents listings, cache helpers, etc.).
  """
  import Ecto.Query

  alias DashboardSSD.Accounts.User
  alias DashboardSSD.Cache.SharedDocumentsCache
  alias DashboardSSD.Documents.DocumentAccessLog
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

  @doc """
  Fetches a client-visible shared document by ID for the given user scope.
  """
  @spec fetch_client_document(User.t(), Ecto.UUID.t()) ::
          {:ok, SharedDocument.t()} | {:error, term()}
  def fetch_client_document(%User{client_id: client_id} = _user, id)
      when is_integer(client_id) and is_binary(id) do
    query =
      from sd in SharedDocument,
        where: sd.id == ^id and sd.client_id == ^client_id and sd.visibility == :client

    case Repo.one(query) do
      %SharedDocument{} = doc -> {:ok, doc}
      nil -> {:error, :not_found}
    end
  end

  def fetch_client_document(_user, _id), do: {:error, :client_scope_missing}

  @doc """
  Returns basic metadata required to decide how to download the document.
  """
  @spec download_descriptor(SharedDocument.t()) :: map()
  def download_descriptor(%SharedDocument{} = document) do
    %{
      document_id: document.id,
      source: document.source,
      source_id: document.source_id,
      mime_type: document.mime_type,
      title: document.title
    }
  end

  @doc """
  Records an access log entry for the given document/user/action.
  """
  @spec log_access(SharedDocument.t(), User.t() | nil, atom(), map()) ::
          {:ok, DocumentAccessLog.t()} | {:error, Ecto.Changeset.t()}
  def log_access(%SharedDocument{} = document, user, action, context \\ %{}) do
    attrs = %{
      shared_document_id: document.id,
      actor_id: user && user.id,
      action: action,
      context: context
    }

    %DocumentAccessLog{}
    |> DocumentAccessLog.changeset(attrs)
    |> Repo.insert()
  end

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
