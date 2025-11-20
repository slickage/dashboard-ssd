defmodule DashboardSSD.Meetings.AssociationsTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.{Clients, Projects}
  alias DashboardSSD.Meetings.Associations

  test "upsert/get/delete association for event" do
    event = "evt-10"
    assert Associations.get_for_event(event) == nil

    {:ok, c} = Clients.create_client(%{name: "Acme"})
    {:ok, assoc1} = Associations.upsert_for_event(event, %{client_id: c.id, origin: "manual"})

    assert assoc1.client_id == c.id
    assert Associations.get_for_event(event).id == assoc1.id

    {:ok, p} = Projects.create_project(%{name: "Portal"})
    {:ok, assoc2} = Associations.upsert_for_event(event, %{project_id: p.id})
    assert assoc2.project_id == p.id

    assert :ok == Associations.delete_for_event(event)
    assert Associations.get_for_event(event) == nil
  end

  test "set_manual with series and persist flag affects fallback lookup" do
    event = "evt-11"
    series = "ser-11"
    {:ok, c} = Clients.create_client(%{name: "Globex"})

    # Persist for series = false -> should not be used for fallback
    {:ok, _} = Associations.set_manual(event, %{client_id: c.id}, series, false)
    assert Associations.get_for_event_or_series("evt-other", series) == nil

    # Persist for series = true -> should be used for fallback
    {:ok, _} = Associations.set_manual(event, %{client_id: c.id}, series, true)
    assert %{} = Associations.get_for_event_or_series("evt-other", series)

    # Clean up series-level associations
    assert :ok == Associations.delete_series(series)
    assert Associations.get_for_event_or_series("evt-other-2", series) == nil
  end

  test "guess_from_title returns client/project/ambiguous/unknown" do
    {:ok, c1} = Clients.create_client(%{name: "Acme"})
    {:ok, _c2} = Clients.create_client(%{name: "Globex"})
    {:ok, _p1} = Projects.create_project(%{name: "Website"})
    {:ok, p2} = Projects.create_project(%{name: "Globex Portal"})

    assert {:client, ^c1} = Associations.guess_from_title("Acme Weekly")
    assert {:ambiguous, list2} = Associations.guess_from_title("Globex Portal Sprint")
    pid = p2.id
    assert Enum.any?(list2, fn m -> match?(%DashboardSSD.Projects.Project{id: ^pid}, m) end)

    assert {:ambiguous, list} = Associations.guess_from_title("Acme Globex Planning")
    assert length(list) >= 2

    assert :unknown == Associations.guess_from_title("Random Sync")
  end
end
