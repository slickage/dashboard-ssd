defmodule DashboardSSD.Meetings.AssociationsTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Clients
  alias DashboardSSD.Meetings.{Associations, MeetingAssociation}
  alias DashboardSSD.Projects
  alias DashboardSSD.Repo

  test "set_manual/2 sets origin manual for client and project" do
    {:ok, client} = Clients.create_client(%{name: "Assoc C"})
    {:ok, project} = Projects.create_project(%{name: "Assoc P"})

    {:ok, assoc_c} = Associations.set_manual("evt-a", %{client_id: client.id})
    assert assoc_c.origin == "manual"
    assert assoc_c.client_id == client.id

    {:ok, assoc_p} = Associations.set_manual("evt-b", %{project_id: project.id})
    assert assoc_p.origin == "manual"
    assert assoc_p.project_id == project.id
  end

  test "set_manual/4 persists series flags when provided and truthy? accepts strings" do
    {:ok, client} = Clients.create_client(%{name: "Persist C"})

    # string "on" should be treated as truthy
    {:ok, assoc} =
      Associations.set_manual("evt-s1", %{client_id: client.id}, "series-1", "on")

    assert assoc.persist_series == true
    assert assoc.recurring_series_id == "series-1"

    # nil persist argument defaults to true
    {:ok, assoc2} = Associations.set_manual("evt-s2", %{client_id: client.id}, "series-2", nil)
    assert assoc2.persist_series == true
    assert assoc2.recurring_series_id == "series-2"
  end

  test "get_for_event_or_series falls back to series when event missing" do
    {:ok, client} = Clients.create_client(%{name: "Fallback C"})

    Repo.insert!(%MeetingAssociation{
      calendar_event_id: "evt-x",
      recurring_series_id: "series-x",
      client_id: client.id,
      persist_series: true,
      origin: "manual"
    })

    assoc = Associations.get_for_event_or_series("evt-other", "series-x")
    assert %MeetingAssociation{} = assoc
    assert assoc.client_id == client.id
  end

  test "guess_from_title returns client/project/unknown based on matches" do
    {:ok, client} = Clients.create_client(%{name: "ACME"})
    {:ok, project} = Projects.create_project(%{name: "Phoenix"})

    assert {:client, ^client} = Associations.guess_from_title("Weekly – ACME")
    assert {:project, ^project} = Associations.guess_from_title("Phoenix sync")
    assert :unknown = Associations.guess_from_title("Something else")
  end
end
