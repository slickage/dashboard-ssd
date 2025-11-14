defmodule DashboardSSD.Documents do
  @moduledoc """
  Documents context entry points (shared documents listings, cache helpers, etc.).
  """
  import Ecto.Query

  alias DashboardSSD.Accounts.User
  alias DashboardSSD.Cache.SharedDocumentsCache
  alias DashboardSSD.Documents.DocumentAccessLog
  alias DashboardSSD.Documents.SharedDocument
  alias DashboardSSD.Documents.WorkspaceBootstrap
  alias DashboardSSD.Projects.DrivePermissionWorker
  alias DashboardSSD.Repo
  require Logger

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
  Lists all shared documents for staff-facing surfaces.
  """
  @spec list_staff_documents(keyword()) :: [SharedDocument.t()]
  def list_staff_documents(opts \\ []) do
    query =
      from sd in SharedDocument,
        preload: [:client, :project],
        order_by: [desc: sd.updated_at]

    query =
      case Keyword.get(opts, :client_id) do
        nil -> query
        client_id -> from sd in query, where: sd.client_id == ^client_id
      end

    Repo.all(query)
  end

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
  Updates document visibility/edit settings and logs the change.
  """
  @spec update_document_settings(SharedDocument.t() | Ecto.UUID.t(), map(), User.t() | nil) ::
          {:ok, SharedDocument.t()} | {:error, term()}
  def update_document_settings(document_or_id, attrs, actor \\ nil) do
    Repo.transaction(fn ->
      doc =
        case document_or_id do
          %SharedDocument{} = doc -> Repo.preload(doc, :project)
          id -> Repo.get!(SharedDocument, id) |> Repo.preload(:project)
        end

      case Repo.update(SharedDocument.changeset(doc, attrs)) do
        {:ok, updated} ->
          SharedDocumentsCache.invalidate_listing(:all)
          SharedDocumentsCache.invalidate_download(updated.id)

          _ =
            log_access(updated, actor, :visibility_changed, %{
              visibility: updated.visibility,
              client_edit_allowed: updated.client_edit_allowed
            })

          maybe_update_drive_acl(updated)
          updated

        {:error, reason} ->
          Repo.rollback(reason)
      end
    end)
  end

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
  def log_access(document, user, action, context \\ %{})

  def log_access(%SharedDocument{} = document, user, action, context) do
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

  def log_access(_, _, _, _), do: {:error, :invalid_document}

  @doc """
  Asynchronously bootstraps workspace sections for the given project.
  """
  @spec bootstrap_workspace(struct(), keyword()) :: :ok
  def bootstrap_workspace(project, opts \\ []) do
    module =
      Application.get_env(
        :dashboard_ssd,
        :workspace_bootstrap_module,
        WorkspaceBootstrap
      )

    Task.Supervisor.start_child(DashboardSSD.TaskSupervisor, fn ->
      case module.bootstrap(project, opts) do
        {:ok, _} ->
          :ok

        {:error, reason} ->
          Logger.warning("Workspace bootstrap failed",
            reason: inspect(reason),
            project_id: Map.get(project, :id)
          )
      end
    end)

    :ok
  end

  @doc """
  Returns enabled workspace sections from the configured blueprint.
  """
  @spec workspace_section_options() :: [map()]
  def workspace_section_options do
    case WorkspaceBootstrap.blueprint() do
      {:ok, %{sections: sections}} when is_list(sections) ->
        Enum.filter(sections, fn section -> Map.get(section, :enabled?, true) end)

      {:ok, blueprint} when is_map(blueprint) ->
        blueprint
        |> Map.get(:sections, [])
        |> Enum.filter(fn section -> Map.get(section, :enabled?, true) end)

      {:error, _reason} ->
        []
    end
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

  defp maybe_update_drive_acl(
         %SharedDocument{source: :drive, project: %{drive_folder_id: folder_id}} = document
       )
       when is_binary(folder_id) do
    params = %{role: "reader", type: "anyone", allow_file_discovery: false}

    case document.visibility do
      :client -> DrivePermissionWorker.share(folder_id, params)
      :internal -> :ok
    end
  end

  defp maybe_update_drive_acl(_), do: :ok
end
