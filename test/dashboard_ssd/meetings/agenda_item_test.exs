defmodule DashboardSSD.Meetings.AgendaItemTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Meetings.AgendaItem

  test "changeset requires calendar_event_id and text" do
    cs = AgendaItem.changeset(%AgendaItem{}, %{})
    refute cs.valid?

    cs2 = AgendaItem.changeset(%AgendaItem{}, %{calendar_event_id: "evt-1", text: "Discuss"})
    assert cs2.valid?
  end

  test "source must be either manual or derived" do
    bad =
      AgendaItem.changeset(%AgendaItem{}, %{calendar_event_id: "evt-1", text: "x", source: "nope"})

    refute bad.valid?
  end
end
