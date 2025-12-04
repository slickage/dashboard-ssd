defmodule DashboardSSDWeb.MeetingsLive.IndexTest do
  use DashboardSSDWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias DashboardSSD.Meetings.AgendaItem
  alias DashboardSSD.Repo

  test "renders sample meetings with mock=1", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/meetings?mock=1")
    assert html =~ "Upcoming"
    assert html =~ "Weekly Sync – Project Alpha"
    assert html =~ "Client Review – Contoso"
  end

  test "calendar_pick patches to clicked date", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/meetings?mock=1")

    iso = Date.utc_today() |> Date.to_iso8601()
    el = element(view, "div[phx-click='calendar_pick'][phx-value-date='#{iso}']")
    render_click(el)
    assert_patch(view, ~p"/meetings?mock=1&d=#{iso}")
  end

  test "prev/next month buttons patch d param anchored to month start", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/meetings?mock=1")

    today = Date.utc_today()
    prev_anchor = if today.month == 1, do: %Date{year: today.year - 1, month: 12, day: 1}, else: %Date{year: today.year, month: today.month - 1, day: 1}
    next_anchor = if today.month == 12, do: %Date{year: today.year + 1, month: 1, day: 1}, else: %Date{year: today.year, month: today.month + 1, day: 1}

    prev_d = Date.add(prev_anchor, 6) |> Date.to_iso8601()
    next_d = Date.add(next_anchor, 6) |> Date.to_iso8601()

    render_click(element(view, "button[phx-click='cal_prev_month']"))
    assert_patch(view, ~p"/meetings?mock=1&d=#{prev_d}")

    render_click(element(view, "button[phx-click='cal_next_month']"))
    assert_patch(view, ~p"/meetings?mock=1&d=#{next_d}")
  end

  test "agenda summary shows manual text when present", %{conn: conn} do
    # Seed a manual agenda item for the first sample meeting id "evt-1"
    %AgendaItem{}
    |> AgendaItem.changeset(%{calendar_event_id: "evt-1", text: "Manual agenda A", position: 0, source: "manual"})
    |> Repo.insert!()

    {:ok, _view, html} = live(conn, ~p"/meetings?mock=1")
    assert html =~ "Agenda"
    assert html =~ "Manual agenda A"
  end
end

