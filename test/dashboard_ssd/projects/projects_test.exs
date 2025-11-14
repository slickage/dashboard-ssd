defmodule DashboardSSD.ProjectsTest do
  use DashboardSSD.DataCase, async: false

  alias DashboardSSD.Clients
  alias DashboardSSD.Projects
  alias DashboardSSD.Projects.Project

  setup do
    {:ok, client} = Clients.create_client(%{name: "Client A"})
    %{client: client}
  end

  test "create_project/1 requires name and validates client if provided", %{client: client} do
    assert {:error, cs} = Projects.create_project(%{})
    assert %{name: ["can't be blank"]} = errors_on(cs)

    assert {:error, cs} = Projects.create_project(%{name: "X", client_id: -1})
    assert %{client_id: ["does not exist"]} = errors_on(cs)

    assert {:ok, %Project{} = p} = Projects.create_project(%{name: "X", client_id: client.id})
    assert p.client_id == client.id
  end

  test "list/get/update/delete project", %{client: client} do
    {:ok, p} = Projects.create_project(%{name: "P1", client_id: client.id})

    assert Enum.any?(Projects.list_projects(), &(&1.id == p.id))
    assert Projects.get_project!(p.id).name == "P1"

    {:ok, p} = Projects.update_project(p, %{name: "P2"})
    assert p.name == "P2"

    assert {:error, cs} = Projects.update_project(p, %{name: nil})
    assert %{name: ["can't be blank"]} = errors_on(cs)

    assert {:ok, _} = Projects.delete_project(p)
    assert_raise Ecto.NoResultsError, fn -> Projects.get_project!(p.id) end
  end

  test "list_projects_by_client/1 filters by client", %{client: client} do
    {:ok, c2} = Clients.create_client(%{name: "Client B"})
    {:ok, p1} = Projects.create_project(%{name: "P1", client_id: client.id})
    {:ok, _p2} = Projects.create_project(%{name: "P2", client_id: c2.id})

    ids = Projects.list_projects_by_client(client.id) |> Enum.map(& &1.id)
    assert ids == [p1.id]
  end

  test "create_project triggers workspace bootstrap", %{client: client} do
    Application.put_env(
      :dashboard_ssd,
      :workspace_bootstrap_module,
      DashboardSSD.WorkspaceBootstrapStub
    )

    :persistent_term.put({:workspace_test_pid}, self())

    {:ok, project} =
      Projects.create_project(%{
        name: "Workspace",
        client_id: client.id,
        drive_folder_id: "folder"
      })

    project_id = project.id
    assert_receive {:workspace_bootstrap, ^project_id, sections}
    assert sections == Projects.workspace_sections()
  after
    :persistent_term.erase({:workspace_test_pid})
    Application.delete_env(:dashboard_ssd, :workspace_bootstrap_module)
  end
end
