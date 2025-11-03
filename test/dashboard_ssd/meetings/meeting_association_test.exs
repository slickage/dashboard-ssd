defmodule DashboardSSD.Meetings.MeetingAssociationTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Meetings.MeetingAssociation
  alias DashboardSSD.{Clients, Projects}

  test "changeset enforces origin inclusion and required calendar_event_id" do
    cs = MeetingAssociation.changeset(%MeetingAssociation{}, %{})
    refute cs.valid?

    cs2 = MeetingAssociation.changeset(%MeetingAssociation{}, %{calendar_event_id: "evt-1", origin: "auto"})
    assert cs2.valid?
  end

  test "insert fails when neither client_id nor project_id set (DB constraint)" do
    # Only validates after insert due to DB check constraint
    changeset = MeetingAssociation.changeset(%MeetingAssociation{}, %{calendar_event_id: "evt-2"})
    assert {:error, cs} = Repo.insert(changeset)
    assert {:client_or_project, {msg, _opts}} = hd(cs.errors)
    assert msg =~ "either client_id or project_id must be present"
  end

  test "allows linking to either client or project" do
    {:ok, client} = Clients.create_client(%{name: "C"})
    {:ok, project} = Projects.create_project(%{name: "P", client_id: client.id})

    {:ok, _} =
      %MeetingAssociation{}
      |> MeetingAssociation.changeset(%{calendar_event_id: "evt-3", client_id: client.id, origin: "manual"})
      |> Repo.insert()

    {:ok, _} =
      %MeetingAssociation{}
      |> MeetingAssociation.changeset(%{calendar_event_id: "evt-4", project_id: project.id, origin: "manual"})
      |> Repo.insert()
  end
end
