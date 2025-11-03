defmodule DashboardSSD.Meetings.AgendaTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Meetings.Agenda

  test "create/list/reorder agenda items" do
    evt = "evt-abc"

    {:ok, a1} = Agenda.create_item(%{calendar_event_id: evt, text: "A", position: 0})
    {:ok, a2} = Agenda.create_item(%{calendar_event_id: evt, text: "B", position: 1})

    items = Agenda.list_items(evt)
    assert Enum.map(items, & &1.text) == ["A", "B"]

    :ok = Agenda.reorder_items(evt, [a2.id, a1.id])
    items2 = Agenda.list_items(evt)
    assert Enum.map(items2, & &1.text) == ["B", "A"]

    {:ok, _} = Agenda.update_item(a1, %{text: "A!"})
    items3 = Agenda.list_items(evt)
    assert Enum.any?(items3, &(&1.text == "A!"))

    {:ok, _} = Agenda.delete_item(a2)
    items4 = Agenda.list_items(evt)
    refute Enum.any?(items4, &(&1.id == a2.id))
  end
end
