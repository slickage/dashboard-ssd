defmodule DashboardSSD.Meetings.AssociationsTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Meetings.Associations
  alias DashboardSSD.{Clients, Projects}

  test "upsert and set_manual store associations" do
    {:ok, client} = Clients.create_client(%{name: "C"})
    {:ok, project} = Projects.create_project(%{name: "P", client_id: client.id})

    {:ok, assoc1} =
      Associations.upsert_for_event("evt-1", %{client_id: client.id, origin: "auto"})

    assert assoc1.client_id == client.id

    {:ok, assoc2} = Associations.set_manual("evt-2", %{project_id: project.id})
    assert assoc2.project_id == project.id
    assert assoc2.origin == "manual"
  end
end
