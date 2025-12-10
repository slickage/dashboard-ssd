defmodule DashboardSSD.Meetings.AgendaUnitTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Meetings.{Agenda, AgendaItem}
  alias DashboardSSD.Repo

  test "list/create/update/delete/reorder items" do
    meeting_id = "evt-agenda"

    {:ok, a1} = Agenda.create_item(%{calendar_event_id: meeting_id, text: "A", position: 1})
    {:ok, a2} = Agenda.create_item(%{calendar_event_id: meeting_id, text: "B", position: 0})

    items = Agenda.list_items(meeting_id)
    assert Enum.map(items, & &1.text) == ["B", "A"]

    {:ok, a2u} = Agenda.update_item(a2, %{text: "B2"})
    assert a2u.text == "B2"

    # Reorder to [A, B2]
    :ok = Agenda.reorder_items(meeting_id, [a1.id, a2.id])
    items2 = Agenda.list_items(meeting_id)
    assert Enum.map(items2, & &1.text) == ["A", "B2"]

    {:ok, _} = Agenda.delete_item(a1)
    remain = Agenda.list_items(meeting_id)
    assert Enum.map(remain, & &1.text) == ["B2"]
  end

  test "merged_items_for_event de-duplicates by normalized text and ignores derived when series nil" do
    meeting_id = "evt-merge"
    {:ok, _} = Agenda.create_item(%{calendar_event_id: meeting_id, text: "Hello", position: 0})
    {:ok, _} = Agenda.create_item(%{calendar_event_id: meeting_id, text: "hello  ", position: 1})

    items = Agenda.merged_items_for_event(meeting_id, nil)
    assert Enum.map(items, & &1.text) == ["Hello"]
    assert Enum.all?(items, &(&1.source == "manual"))
  end
end
