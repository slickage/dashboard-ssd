defmodule DashboardSSD.Documents.WorkspaceBootstrap.GoogleDriveClient do
  @moduledoc """
  Drive client for WorkspaceBootstrap that creates section subfolders and Google Docs.

  Uses the configured Drive service account token via `Integrations.drive_service_token/0`.
  """
  @behaviour DashboardSSD.Documents.WorkspaceBootstrap.DriveClient

  alias DashboardSSD.Integrations
  alias DashboardSSD.Integrations.Drive
  alias DashboardSSD.Projects
  alias DashboardSSD.Projects.Project
  require Logger

  @impl true
  def ensure_section_folder(%Project{} = project, section, _opts) do
    with {:ok, %Project{} = project} <- ensure_project_drive_folder(project),
         {:ok, token} <- Integrations.drive_service_token(),
         {:ok, name} <- section_folder_name(section) do
      drive_api().ensure_project_folder(token, %{
        parent_id: project.drive_folder_id,
        name: name
      })
    end
  end

  @impl true
  def upsert_document(%Project{} = project, section, template, _opts) do
    with {:ok, %Project{} = project} <- ensure_project_drive_folder(project),
         {:ok, token} <- Integrations.drive_service_token(),
         {:ok, folder_name} <- section_folder_name(section),
         {:ok, folder} <-
           drive_api().ensure_project_folder(token, %{
             parent_id: project.drive_folder_id,
             name: folder_name
           }),
         {:ok, folder_meta} <- drive_api().get_file(token, folder["id"]),
         {:ok, doc_name} <- section_doc_name(section),
         {:ok, existing} <- drive_api().find_file(token, folder["id"], doc_name) do
      Logger.debug(
        "Drive bootstrap upsert section=#{section.id} folder=#{folder["id"]} drive=#{folder_meta["driveId"]} doc=#{doc_name}"
      )

      case existing do
        nil ->
          case drive_api().create_doc_with_content(token, folder["id"], doc_name, template || "") do
            {:ok, doc} ->
              {:ok, Map.put(doc, "webViewLink", doc_web_view_link(doc, folder_meta))}

            other ->
              other
          end

        doc ->
          with {:ok, updated} <-
                 drive_api().update_file_with_content(
                   token,
                   doc["id"],
                   template || ""
                 ) do
            {:ok, Map.put(updated, "webViewLink", doc_web_view_link(doc, folder_meta))}
          end
      end
    else
      {:error, reason} = error ->
        Logger.error(
          "Drive bootstrap upsert failed section=#{section.id} parent=#{project.drive_folder_id} reason=#{inspect(reason)}"
        )

        error
    end
  end

  defp doc_web_view_link(doc, folder_meta) do
    case Map.get(doc, "id") do
      nil ->
        nil

      id ->
        drive_id = folder_meta["driveId"] || folder_meta[:driveId]

        if is_binary(drive_id) and drive_id != "" do
          "https://docs.google.com/document/d/#{id}/edit?usp=drivesdk"
        else
          nil
        end
    end
  end

  defp section_folder_name(%{folder_path: path}) when is_binary(path) and path != "" do
    {:ok, path}
  end

  defp section_folder_name(%{label: label}) when is_binary(label) and label != "" do
    {:ok, label}
  end

  defp section_folder_name(%{id: id}) when is_atom(id) do
    {:ok, humanize(id)}
  end

  defp section_folder_name(_), do: {:error, :invalid_section_folder}

  defp section_doc_name(%{label: label}) when is_binary(label) and label != "" do
    {:ok, label}
  end

  defp section_doc_name(%{id: id}) when is_atom(id) do
    {:ok, humanize(id)}
  end

  defp section_doc_name(_), do: {:error, :invalid_section_name}

  defp humanize(atom) do
    atom
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split(" ", trim: true)
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp drive_api do
    Application.get_env(:dashboard_ssd, :drive_api_module, Drive)
  end

  defp ensure_project_drive_folder(%Project{drive_folder_id: folder_id} = project)
       when is_binary(folder_id) and folder_id != "" do
    {:ok, project}
  end

  defp ensure_project_drive_folder(project), do: Projects.ensure_drive_folder(project)
end
