defmodule DashboardSSD.Meetings.AgendaTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Meetings.{Agenda, AgendaItem}

  test "create, list, update, delete agenda items" do
    event = "evt-1"
    {:ok, a1} = Agenda.create_item(%{calendar_event_id: event, text: "Intro", position: 2})
    {:ok, a2} = Agenda.create_item(%{calendar_event_id: event, text: "Main", position: 0})

    items = Agenda.list_items(event)
    assert Enum.map(items, &{&1.text, &1.position}) == [{"Main", 0}, {"Intro", 2}]

    {:ok, a2u} = Agenda.update_item(a2, %{text: "Updated"})
    assert a2u.text == "Updated"

    {:ok, _} = Agenda.delete_item(a1)
    items2 = Agenda.list_items(event)
    assert Enum.map(items2, & &1.text) == ["Updated"]
  end

  test "reorder_items updates positions accordingly" do
    event = "evt-2"
    {:ok, a1} = Agenda.create_item(%{calendar_event_id: event, text: "A", position: 0})
    {:ok, a2} = Agenda.create_item(%{calendar_event_id: event, text: "B", position: 1})
    {:ok, a3} = Agenda.create_item(%{calendar_event_id: event, text: "C", position: 2})

    assert :ok == Agenda.reorder_items(event, [a3.id, a1.id, a2.id])

    items = Agenda.list_items(event)
    # order by position
    assert Enum.map(items, &{&1.text, &1.position}) == [{"C", 0}, {"A", 1}, {"B", 2}]
  end

  test "replace_manual_text clears and creates single item at position 0" do
    event = "evt-3"
    {:ok, _} = Agenda.create_item(%{calendar_event_id: event, text: "Old 1", position: 0})
    {:ok, _} = Agenda.create_item(%{calendar_event_id: event, text: "Old 2", position: 1})

    assert :ok == Agenda.replace_manual_text(event, "New One")

    items = Agenda.list_items(event)
    assert length(items) == 1
    assert [%AgendaItem{text: "New One", position: 0}] = items
  end

  test "merged_items_for_event includes only manual when no series id and de-duplicates" do
    event = "evt-4"
    {:ok, _} = Agenda.create_item(%{calendar_event_id: event, text: "Discuss Plan", position: 0})

    {:ok, _} =
      Agenda.create_item(%{calendar_event_id: event, text: " discuss   plan  ", position: 1})

    merged = Agenda.merged_items_for_event(event, nil)
    # deduplicated to a single normalized entry
    assert Enum.map(merged, & &1.text) == ["Discuss Plan"]
    assert Enum.all?(merged, &(&1.source == "manual"))
  end
end
