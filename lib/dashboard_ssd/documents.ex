defmodule DashboardSSD.Documents do
  @moduledoc """
  Documents context entry points (shared documents listings, cache helpers, etc.).
  """
  import Ecto.Query

  alias DashboardSSD.Accounts.User
  alias DashboardSSD.Cache.SharedDocumentsCache
  alias DashboardSSD.Documents.DocumentAccessLog
  alias DashboardSSD.Documents.DriveSync
  alias DashboardSSD.Documents.SharedDocument
  alias DashboardSSD.Documents.WorkspaceBootstrap
  alias DashboardSSD.Integrations
  alias DashboardSSD.Integrations.Drive
  alias DashboardSSD.Projects
  alias DashboardSSD.Projects.DrivePermissionWorker
  alias DashboardSSD.Repo
  require Logger
  @dialyzer {:nowarn_function, log_access: 4}

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
  Lists shared documents for staff-facing surfaces. Returns all docs when the
  caller can manage projects/contracts; otherwise, applies an optional client
  filter for read-only viewers. Supports optional `:project_id` filtering.
  """
  @spec list_staff_documents(keyword()) :: [SharedDocument.t()]
  def list_staff_documents(opts \\ []) do
    can_manage? = Keyword.get(opts, :can_manage?, false)
    project_id = Keyword.get(opts, :project_id)

    query =
      from sd in SharedDocument,
        preload: [:client, :project],
        order_by: [
          asc: sd.client_id,
          asc: sd.project_id,
          asc: fragment("lower(?)", sd.title),
          asc: sd.inserted_at
        ]

    query =
      case {can_manage?, Keyword.get(opts, :client_id)} do
        {true, _} -> query
        {false, nil} -> query
        {false, client_id} -> from sd in query, where: sd.client_id == ^client_id
      end
      |> maybe_filter_project(project_id)

    Repo.all(query)
  end

  defp maybe_filter_project(query, nil), do: query

  defp maybe_filter_project(query, project_id) when is_integer(project_id),
    do: from(sd in query, where: sd.project_id == ^project_id)

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
    start_time = System.monotonic_time()

    result =
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
            maybe_refresh_drive_permissions(updated)
            updated

          {:error, reason} ->
            Repo.rollback(reason)
        end
      end)

    emit_visibility_toggle_telemetry(start_time, actor, result)
    result
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
          {:ok, DocumentAccessLog.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :invalid_document}
  def log_access(document, user, action, context \\ %{})

  def log_access(%SharedDocument{} = document, user, action, context) when is_map(context) do
    attrs =
      %{
        shared_document_id: document.id,
        actor_id: user && user.id,
        action: action,
        context: context
      }
      |> Map.new()

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
        {:ok, result} ->
          _ = persist_drive_results(project, result)
          :ok

        {:error, reason} ->
          Logger.warning(
            "Workspace bootstrap failed for project #{Map.get(project, :id)}: #{inspect(reason)}"
          )
      end
    end)

    :ok
  end

  @doc """
  Synchronously bootstraps workspace sections for the given project, returning
  the result from the configured WorkspaceBootstrap module.
  """
  @spec bootstrap_workspace_sync(struct(), keyword()) :: {:ok, map()} | {:error, term()}
  def bootstrap_workspace_sync(project, opts \\ []) do
    module =
      Application.get_env(
        :dashboard_ssd,
        :workspace_bootstrap_module,
        WorkspaceBootstrap
      )

    case module.bootstrap(project, opts) do
      {:ok, result} = ok ->
        _ = persist_drive_results(project, result)
        ok

      other ->
        other
    end
  end

  @doc """
  Manually syncs Drive documents from existing project folders into `shared_documents`.

  Options:
    * `:project_ids` - limit sync to the given project IDs.
  """
  @spec sync_drive_documents(keyword()) :: :ok | {:error, term()}
  def sync_drive_documents(opts \\ []) do
    with {:ok, token} <- Integrations.drive_service_token(),
         {:ok, blueprint} <- WorkspaceBootstrap.blueprint() do
      sections = drive_sections(blueprint)
      projects = drive_projects(opts)
      project_ids = Enum.map(projects, & &1.id)

      docs =
        projects
        |> Enum.filter(&Projects.drive_folder_configured?/1)
        |> Enum.flat_map(&collect_drive_docs(token, &1, sections))
        |> Enum.reject(&is_nil/1)

      case DriveSync.sync(docs,
             prune_missing?: Keyword.get(opts, :prune_missing?, false),
             project_ids: project_ids
           ) do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
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

    maybe_filter_client_project(base, project_id)
  end

  defp maybe_filter_client_project(query, nil), do: query

  defp maybe_filter_client_project(query, project_id) do
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

  defp maybe_refresh_drive_permissions(%SharedDocument{
         source: :drive,
         project: %{client_id: client_id}
       })
       when is_integer(client_id) do
    Projects.sync_drive_permissions_for_client(client_id)
  end

  defp maybe_refresh_drive_permissions(_), do: :ok

  defp emit_visibility_toggle_telemetry(start_time, actor, {:ok, %SharedDocument{} = doc}) do
    duration = System.monotonic_time() - start_time

    metadata = %{
      status: :ok,
      document_id: doc.id,
      client_id: doc.client_id,
      project_id: doc.project_id,
      visibility: doc.visibility,
      actor_id: actor && actor.id
    }

    :telemetry.execute(
      [:dashboard_ssd, :documents, :visibility_toggle],
      %{duration: duration},
      metadata
    )
  end

  defp emit_visibility_toggle_telemetry(start_time, actor, {:error, reason}) do
    duration = System.monotonic_time() - start_time

    metadata = %{
      status: :error,
      actor_id: actor && actor.id,
      error: inspect(reason)
    }

    :telemetry.execute(
      [:dashboard_ssd, :documents, :visibility_toggle],
      %{duration: duration},
      metadata
    )
  end

  defp persist_drive_results(%{client_id: client_id, id: project_id}, %{sections: sections})
       when is_integer(client_id) and is_integer(project_id) and is_list(sections) do
    drive_docs =
      sections
      |> Enum.filter(&match?(%{type: :drive}, &1))
      |> Enum.map(&build_drive_attrs(&1, client_id, project_id))
      |> Enum.reject(&is_nil/1)

    case drive_docs do
      [] ->
        :ok

      docs ->
        case DriveSync.sync(docs) do
          {:ok, _} ->
            :ok

          {:error, reason} ->
            Logger.warning(
              "Drive sync after bootstrap failed for project #{project_id}: #{inspect(reason)}"
            )

            :ok
        end
    end
  end

  defp persist_drive_results(_, _), do: :ok

  defp build_drive_attrs(
         %{section: section_id, document: doc, folder: folder},
         client_id,
         project_id
       ) do
    source_id = fetch(doc, ["id", :id])

    if is_binary(source_id) and source_id != "" do
      %{
        client_id: client_id,
        project_id: project_id,
        source_id: source_id,
        doc_type: doc_type_for_section(section_id),
        title: doc_title(section_id, doc),
        mime_type: fetch(doc, ["mimeType", :mimeType]) || "application/vnd.google-apps.document",
        metadata:
          %{
            folder_id: fetch(folder, ["id", :id]),
            drive_id: fetch(folder, ["driveId", :driveId])
          }
          |> Enum.reject(fn {_k, v} -> is_nil(v) end)
          |> Map.new(),
        visibility: :client
      }
    else
      nil
    end
  end

  defp build_drive_attrs(_, _client_id, _project_id), do: nil

  defp doc_type_for_section(:drive_contracts), do: "contract"
  defp doc_type_for_section(:drive_sow), do: "sow"
  defp doc_type_for_section(:drive_change_orders), do: "change_order"
  defp doc_type_for_section(other) when is_atom(other), do: Atom.to_string(other)
  defp doc_type_for_section(other), do: to_string(other || "")

  defp doc_title(_section_id, doc) do
    fetch(doc, ["name", :name]) || "Drive Document"
  end

  defp fetch(map, keys) when is_map(map) and is_list(keys) do
    Enum.find_value(keys, fn
      key when is_binary(key) -> map[key]
      key when is_atom(key) -> Map.get(map, key)
      _ -> nil
    end)
  end

  defp fetch(_, _), do: nil

  defp drive_sections(%{sections: sections}) when is_list(sections) do
    sections
    |> Enum.filter(fn section ->
      match?(%{type: :drive}, section) and Map.get(section, :enabled?, true) !== false
    end)
  end

  defp drive_sections(_), do: []

  defp drive_projects(opts) do
    project_ids = Keyword.get(opts, :project_ids)

    base =
      Projects.list_projects()
      |> Repo.preload(:client)

    case project_ids do
      nil -> base
      ids when is_list(ids) -> Enum.filter(base, &(&1.id in ids))
      _ -> base
    end
  end

  defp collect_drive_docs(_token, %{client_id: nil}, _sections), do: []

  defp collect_drive_docs(token, project, sections) do
    Enum.flat_map(sections, fn section ->
      with {:ok, folder_name} <- drive_section_folder_name(section),
           {:ok, folder} <-
             Drive.ensure_project_folder(token, %{
               parent_id: project.drive_folder_id,
               name: folder_name
             }),
           {:ok, folder_meta} <- Drive.get_file(token, folder["id"]),
           {:ok, %{"files" => files}} <-
             Drive.list_documents(%{token: token, folder_id: folder["id"]}) do
        Enum.map(files, fn file ->
          web_view = fetch(file, ["webViewLink", :webViewLink])

          %{
            client_id: project.client_id,
            project_id: project.id,
            source_id: fetch(file, ["id", :id]),
            doc_type: doc_type_for_section(section.id),
            title: fetch(file, ["name", :name]) || "Drive Document",
            mime_type:
              fetch(file, ["mimeType", :mimeType]) ||
                "application/vnd.google-apps.document",
            metadata:
              %{
                folder_id: fetch(folder, ["id", :id]),
                drive_id: fetch(folder_meta, ["driveId", :driveId]),
                webViewLink: web_view
              }
              |> Enum.reject(fn {_k, v} -> is_nil(v) end)
              |> Map.new(),
            visibility: :client
          }
        end)
      else
        {:error, reason} ->
          Logger.debug(
            "Drive resync skipped for project #{project.id}, section #{section.id}: #{inspect(reason)}"
          )

          []

        _ ->
          []
      end
    end)
  end

  defp drive_section_folder_name(%{folder_path: path}) when is_binary(path) and path != "" do
    {:ok, path}
  end

  defp drive_section_folder_name(%{label: label}) when is_binary(label) and label != "" do
    {:ok, label}
  end

  defp drive_section_folder_name(%{id: id}) when is_atom(id) do
    {:ok,
     id
     |> Atom.to_string()
     |> String.replace("_", " ")
     |> String.split(" ", trim: true)
     |> Enum.map_join(" ", &String.capitalize/1)}
  end

  defp drive_section_folder_name(_), do: {:error, :invalid_section_folder}
end
