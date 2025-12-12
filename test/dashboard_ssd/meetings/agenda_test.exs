defmodule DashboardSSD.Meetings.AgendaTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Meetings.Agenda
  alias DashboardSSD.Meetings.AgendaItem

  test "create, list, update, reorder and delete items" do
    event_id = "evt-agenda-1"

    # initially empty
    assert [] == Agenda.list_items(event_id)

    {:ok, a} = Agenda.create_item(%{calendar_event_id: event_id, text: "A", position: 0})
    {:ok, b} = Agenda.create_item(%{calendar_event_id: event_id, text: "B", position: 1})
    {:ok, c} = Agenda.create_item(%{calendar_event_id: event_id, text: "C", position: 2})

    # order by position
    assert ["A", "B", "C"] == Agenda.list_items(event_id) |> Enum.map(& &1.text)

    # update
    {:ok, _} = Agenda.update_item(b, %{text: "B2"})
    assert ["A", "B2", "C"] == Agenda.list_items(event_id) |> Enum.map(& &1.text)

    # reorder (reverse)
    new_order = [c.id, b.id, a.id]
    assert :ok == Agenda.reorder_items(event_id, new_order)
    assert ["C", "B2", "A"] == Agenda.list_items(event_id) |> Enum.map(& &1.text)

    # delete
    [first | _] = Agenda.list_items(event_id)
    {:ok, %AgendaItem{}} = Agenda.delete_item(first)
    assert ["B2", "A"] == Agenda.list_items(event_id) |> Enum.map(& &1.text)

    # replace_manual_text collapses to a single item
    assert :ok == Agenda.replace_manual_text(event_id, "Line 1\nLine 2\n")
    items = Agenda.list_items(event_id)
    assert length(items) == 1
    assert hd(items).text == "Line 1\nLine 2"
  end
end
