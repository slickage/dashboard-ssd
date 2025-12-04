defmodule DashboardSSDWeb.MeetingsLive.IndexTest do
  use DashboardSSDWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts
  alias DashboardSSD.Meetings.AgendaItem
  alias DashboardSSD.Repo

  setup %{conn: conn} do
    {:ok, user} =
      Accounts.create_user(%{
        email: "meetings_index@example.com",
        name: "Mtg Index",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, conn: init_test_session(conn, %{user_id: user.id})}
  end

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
    today = Date.utc_today()
    prev_anchor = if today.month == 1, do: %Date{year: today.year - 1, month: 12, day: 1}, else: %Date{year: today.year, month: today.month - 1, day: 1}
    next_anchor = if today.month == 12, do: %Date{year: today.year + 1, month: 1, day: 1}, else: %Date{year: today.year, month: today.month + 1, day: 1}

    prev_d = Date.add(prev_anchor, 6) |> Date.to_iso8601()
    next_d = Date.add(next_anchor, 6) |> Date.to_iso8601()

    # Prev from initial view
    {:ok, view, _html} = live(conn, ~p"/meetings?mock=1")
    render_click(element(view, "button[phx-click='cal_prev_month']"))
    assert_patch(view, ~p"/meetings?mock=1&d=#{prev_d}")

    # Next from a fresh initial view (so it's relative to the current month, not prev)
    {:ok, view2, _html} = live(conn, ~p"/meetings?mock=1")
    render_click(element(view2, "button[phx-click='cal_next_month']"))
    assert_patch(view2, ~p"/meetings?mock=1&d=#{next_d}")
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

  test "formats times for same-day events with tz=0", %{conn: conn} do
    today = Date.utc_today() |> Date.to_iso8601()
    {:ok, _view, html} = live(conn, ~p"/meetings?mock=1&tz=0&d=#{today}")
    # First sample event starts at 00:00 UTC and ends at 01:00
    assert html =~ "00:00"
    assert html =~ "01:00"
  end

  test "meeting link patches include id, series and title params", %{conn: conn} do
    today = Date.utc_today() |> Date.to_iso8601()
    {:ok, _view, html} = live(conn, ~p"/meetings?mock=1&d=#{today}")

    # Asserts that the title link contains id, series_id, and title query params
    assert html =~ "id=evt-1"
    assert html =~ "series_id=series-alpha"
    assert html =~ "title="
  end

  test "association chip shows client name when mapping exists", %{conn: conn} do
    # Map evt-1 to a client via MeetingAssociation
    {:ok, client} = DashboardSSD.Clients.create_client(%{name: "Assoc Client"})
    _assoc =
      %DashboardSSD.Meetings.MeetingAssociation{}
      |> DashboardSSD.Meetings.MeetingAssociation.changeset(%{
        calendar_event_id: "evt-1",
        client_id: client.id,
        origin: "manual",
        persist_series: true
      })
      |> DashboardSSD.Repo.insert!()

    today = Date.utc_today() |> Date.to_iso8601()
    {:ok, _view, html} = live(conn, ~p"/meetings?mock=1&d=#{today}")

    assert html =~ "· Client:"
    assert html =~ client.name
  end
end
