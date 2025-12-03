defmodule DashboardSSD.Projects.BasicTest do
  use DashboardSSD.DataCase, async: false

  alias DashboardSSD.Clients
  alias DashboardSSD.Projects

  setup do
    {:ok, client} = Clients.create_client(%{name: "Acme"})
    {:ok, project} = Projects.create_project(%{name: "Phoenix", client_id: client.id})
    %{client: client, project: project}
  end

  test "list_projects helpers include preloaded clients", %{client: client, project: project} do
    assert Enum.any?(Projects.list_projects(), &(&1.id == project.id))
    assert Enum.map(Projects.list_projects_by_client(client.id), & &1.id) == [project.id]
    assert Projects.list_projects_for_clients([]) == []
    assert Enum.map(Projects.list_projects_for_clients([client.id]), & &1.id) == [project.id]
  end

  test "drive_folder_configured?/1 detects missing metadata", %{project: project} do
    refute Projects.drive_folder_configured?(project)

    assert {:ok, updated} =
             Projects.upsert_drive_folder_metadata(project, %{
               drive_folder_id: "folder-123",
               drive_folder_sharing_inherited: true
             })

    assert Projects.drive_folder_configured?(updated)
    assert updated.drive_folder_sharing_inherited
  end

  test "mark_drive_permission_sync stores timestamp", %{project: project} do
    ts = DateTime.utc_now() |> DateTime.truncate(:second)
    assert {:ok, updated} = Projects.mark_drive_permission_sync(project, ts)
    assert DateTime.compare(updated.drive_folder_last_permission_sync_at, ts) == :eq
  end
end
