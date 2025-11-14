defmodule DashboardSSD.Documents.WorkspaceBootstrap do
  @moduledoc """
  Provision Drive + Notion workspace artifacts using repository-managed templates.

  Reads the workspace blueprint (configured via `:workspace_blueprint`) to decide which
  sections to create, loads each Markdown template, and delegates creation to the
  configured Drive/Notion adapters. Adapters can be swapped out (and mocked in tests)
  by passing `:drive_client` / `:notion_client` options.
  """
  alias DashboardSSD.Projects.Project

  @type section_id :: atom()
  @type section :: map()

  @drive_behaviour DashboardSSD.Documents.WorkspaceBootstrap.DriveClient
  @notion_behaviour DashboardSSD.Documents.WorkspaceBootstrap.NotionClient

  @doc """
  Returns the configured workspace blueprint map (sections, defaults, flags).
  """
  @spec blueprint() :: {:ok, map()} | {:error, term()}
  def blueprint do
    fetch_blueprint()
  end

  @doc """
  Bootstraps workspace sections for the given project using the configured blueprint.

  The optional keyword list lets callers restrict the sections or swap Drive/Notion clients.
  """
  @spec bootstrap(Project.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def bootstrap(%Project{} = project, opts \\ []) do
    with {:ok, blueprint} <- fetch_blueprint(),
         {:ok, sections} <- resolve_sections(blueprint, opts[:sections]) do
      drive_client = Keyword.get(opts, :drive_client, default_drive_client())
      notion_client = Keyword.get(opts, :notion_client, default_notion_client())
      drive_client_opts = Keyword.get(opts, :drive_client_opts, [])
      notion_client_opts = Keyword.get(opts, :notion_client_opts, [])

      Enum.reduce_while(sections, {:ok, %{results: []}}, fn section, {:ok, acc} ->
        case provision_section(
               section,
               project,
               drive_client,
               notion_client,
               drive_client_opts,
               notion_client_opts
             ) do
          {:ok, result} -> {:cont, {:ok, %{results: [result | acc.results]}}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
      |> case do
        {:ok, %{results: results}} -> {:ok, %{sections: Enum.reverse(results)}}
        error -> error
      end
    end
  end

  defp provision_section(
         %{type: :drive} = section,
         project,
         drive_client,
         _notion_client,
         drive_opts,
         _notion_opts
       ) do
    ensure_drive_client!(drive_client)

    with :ok <- ensure_drive_folder!(project),
         {:ok, template} <- load_template(section),
         {:ok, folder} <- drive_client.ensure_section_folder(project, section, drive_opts),
         {:ok, doc} <- drive_client.upsert_document(project, section, template, drive_opts) do
      {:ok, %{section: section.id, type: :drive, folder: folder, document: doc}}
    end
  end

  defp provision_section(
         %{type: :notion} = section,
         project,
         _drive_client,
         notion_client,
         _drive_opts,
         notion_opts
       ) do
    ensure_notion_client!(notion_client)

    with {:ok, template} <- load_template(section),
         {:ok, page} <- notion_client.upsert_page(project, section, template, notion_opts) do
      {:ok, %{section: section.id, type: :notion, page: page}}
    end
  end

  defp fetch_blueprint do
    case Application.get_env(:dashboard_ssd, DashboardSSD.Documents.WorkspaceBlueprint) do
      nil -> {:error, :workspace_blueprint_not_configured}
      blueprint when is_list(blueprint) -> {:ok, Map.new(blueprint)}
      blueprint -> {:ok, blueprint}
    end
  end

  defp resolve_sections(%{sections: _all_sections} = blueprint, nil) do
    resolve_sections(blueprint, Map.get(blueprint, :default_sections, []))
  end

  defp resolve_sections(%{sections: all_sections}, section_ids) when is_list(section_ids) do
    selected =
      section_ids
      |> Enum.map(fn id ->
        case Enum.find(all_sections, &(&1.id == id)) do
          nil -> {:error, {:unknown_section, id}}
          section -> {:ok, section}
        end
      end)

    case Enum.find(selected, fn
           {:error, _} -> true
           _ -> false
         end) do
      {:error, reason} -> {:error, reason}
      _ -> {:ok, Enum.map(selected, fn {:ok, section} -> section end)}
    end
  end

  defp resolve_sections(_, other), do: {:error, {:invalid_sections, other}}

  # sobelow_skip ["Traversal.FileModule"]
  defp load_template(%{template_path: path}) do
    case File.read(path) do
      {:ok, content} -> {:ok, content}
      {:error, reason} -> {:error, {:template_read_failed, path, reason}}
    end
  end

  defp ensure_drive_folder!(%Project{drive_folder_id: id}) when is_binary(id) and id != "",
    do: :ok

  defp ensure_drive_folder!(_), do: {:error, :project_drive_folder_missing}

  defp ensure_drive_client!(client) do
    unless implements_behaviour?(client, @drive_behaviour) do
      raise ArgumentError,
            "Configured drive client does not implement #{inspect(@drive_behaviour)}"
    end
  end

  defp ensure_notion_client!(client) do
    unless implements_behaviour?(client, @notion_behaviour) do
      raise ArgumentError,
            "Configured notion client does not implement #{inspect(@notion_behaviour)}"
    end
  end

  defp implements_behaviour?(module, behaviour) when is_atom(module) do
    with true <- Code.ensure_loaded?(module),
         attrs when is_list(attrs) <- module.module_info(:attributes)[:behaviour] || [],
         true <- behaviour in attrs do
      true
    else
      _ -> false
    end
  end

  defp default_drive_client do
    Application.get_env(
      :dashboard_ssd,
      :workspace_bootstrap_drive_client,
      DashboardSSD.Documents.WorkspaceBootstrap.NoopDriveClient
    )
  end

  defp default_notion_client do
    Application.get_env(
      :dashboard_ssd,
      :workspace_bootstrap_notion_client,
      DashboardSSD.Documents.WorkspaceBootstrap.NoopNotionClient
    )
  end
end

defmodule DashboardSSD.Documents.WorkspaceBootstrap.DriveClient do
  @moduledoc """
  Behaviour for Drive workspace provisioning adapters used by WorkspaceBootstrap.
  """
  alias DashboardSSD.Projects.Project

  @callback ensure_section_folder(
              Project.t(),
              DashboardSSD.Documents.WorkspaceBootstrap.section(),
              keyword()
            ) ::
              {:ok, map()} | {:error, term()}

  @callback upsert_document(
              Project.t(),
              DashboardSSD.Documents.WorkspaceBootstrap.section(),
              binary(),
              keyword()
            ) ::
              {:ok, map()} | {:error, term()}
end

defmodule DashboardSSD.Documents.WorkspaceBootstrap.NotionClient do
  @moduledoc """
  Behaviour for Notion workspace provisioning adapters.
  """
  alias DashboardSSD.Projects.Project

  @callback upsert_page(
              Project.t(),
              DashboardSSD.Documents.WorkspaceBootstrap.section(),
              binary(),
              keyword()
            ) ::
              {:ok, map()} | {:error, term()}
end

defmodule DashboardSSD.Documents.WorkspaceBootstrap.NoopDriveClient do
  @moduledoc false
  @behaviour DashboardSSD.Documents.WorkspaceBootstrap.DriveClient

  @impl true
  def ensure_section_folder(_project, _section, _opts), do: {:error, :drive_client_not_configured}

  @impl true
  def upsert_document(_project, _section, _template, _opts),
    do: {:error, :drive_client_not_configured}
end

defmodule DashboardSSD.Documents.WorkspaceBootstrap.NoopNotionClient do
  @moduledoc false
  @behaviour DashboardSSD.Documents.WorkspaceBootstrap.NotionClient

  @impl true
  def upsert_page(_project, _section, _template, _opts),
    do: {:error, :notion_client_not_configured}
end
