defmodule DashboardSSD.Projects.BasicProjectsTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.{Clients, Projects}

  test "basic project queries and helpers" do
    {:ok, client} = Clients.create_client(%{name: "Coverage"})
    {:ok, project} = Projects.create_project(%{name: "Coverage Project", client_id: client.id})

    assert Enum.any?(Projects.list_projects(), &(&1.id == project.id))
    assert Enum.any?(Projects.list_projects_by_client(client.id), &(&1.id == project.id))

    assert Projects.workflow_state_metadata(nil) == %{}
    assert Projects.workflow_state_metadata("unknown") == %{}

    assert Projects.team_members_by_team_ids([]) == %{}
    assert Projects.team_members_by_team_ids(["missing"]) == %{}

    changeset = Projects.change_project(project)
    assert changeset.valid?

    {:ok, renamed} = Projects.update_project(project, %{name: "Renamed"})
    assert renamed.name == "Renamed"

    {:ok, _deleted} = Projects.delete_project(renamed)
    assert Projects.list_projects_by_client(client.id) == []
  end
end
