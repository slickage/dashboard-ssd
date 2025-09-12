defmodule DashboardSSD.ProjectsTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Clients
  alias DashboardSSD.Projects
  alias DashboardSSD.Projects.Project

  setup do
    {:ok, client} = Clients.create_client(%{name: "Client A"})
    %{client: client}
  end

  test "create_project/1 requires name and client_id", %{client: client} do
    assert {:error, cs} = Projects.create_project(%{})
    assert %{name: ["can't be blank"], client_id: ["can't be blank"]} = errors_on(cs)

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
end
