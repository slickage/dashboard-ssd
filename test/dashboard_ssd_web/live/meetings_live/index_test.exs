defmodule DashboardSSDWeb.MeetingsLive.IndexTest do
  use DashboardSSDWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts
  alias DashboardSSD.Clients
  alias DashboardSSD.Meetings.{AgendaItem, CacheStore, MeetingAssociation}
  alias DashboardSSD.Projects
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

    prev_anchor =
      if today.month == 1,
        do: %Date{year: today.year - 1, month: 12, day: 1},
        else: %Date{year: today.year, month: today.month - 1, day: 1}

    next_anchor =
      if today.month == 12,
        do: %Date{year: today.year + 1, month: 1, day: 1},
        else: %Date{year: today.year, month: today.month + 1, day: 1}

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
    |> AgendaItem.changeset(%{
      calendar_event_id: "evt-1",
      text: "Manual agenda A",
      position: 0,
      source: "manual"
    })
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
    {:ok, client} = Clients.create_client(%{name: "Assoc Client"})

    _assoc =
      %MeetingAssociation{}
      |> MeetingAssociation.changeset(%{
        calendar_event_id: "evt-1",
        client_id: client.id,
        origin: "manual",
        persist_series: true
      })
      |> Repo.insert!()

    today = Date.utc_today() |> Date.to_iso8601()
    {:ok, _view, html} = live(conn, ~p"/meetings?mock=1&d=#{today}")

    assert html =~ "· Client:"
    assert html =~ client.name
  end

  test "calendar highlights days that have meetings (font-bold) with mock=1", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/meetings?mock=1")
    # Bold class is applied to days found in has_meetings map
    assert html =~ "font-bold"
  end

  test "association chip shows project name when mapping exists", %{conn: conn} do
    {:ok, project} = Projects.create_project(%{name: "Assoc Project"})

    _assoc =
      %MeetingAssociation{}
      |> MeetingAssociation.changeset(%{
        calendar_event_id: "evt-2",
        project_id: project.id,
        origin: "manual",
        persist_series: true
      })
      |> Repo.insert!()

    today = Date.utc_today() |> Date.to_iso8601()
    {:ok, _view, html} = live(conn, ~p"/meetings?mock=1&d=#{today}")
    assert html =~ "· Project:"
    assert html =~ project.name
  end

  test "shows Unassigned when no mapping", %{conn: conn} do
    today = Date.utc_today() |> Date.to_iso8601()
    {:ok, _view, html} = live(conn, ~p"/meetings?mock=1&d=#{today}")
    assert html =~ "· Unassigned"
  end

  test "meeting title link preserves tz and d and mock params", %{conn: conn} do
    d = Date.utc_today() |> Date.to_iso8601()
    {:ok, _view, html} = live(conn, ~p"/meetings?mock=1&d=#{d}&tz=120")
    # Title link should include preserved flags
    assert html =~ ~s(mock=1)
    assert html =~ ~s(d=#{d})
    assert html =~ ~s(tz=120)
  end

  test "meeting modal renders when id param present", %{conn: conn} do
    # Seed series artifacts to avoid external HTTP in the detail component
    CacheStore.put(
      {:series_artifacts, "series-alpha"},
      %{accomplished: nil, action_items: []},
      :timer.minutes(5)
    )

    today_plus_6 = Date.add(Date.utc_today(), 6) |> Date.to_iso8601()
    # Use d=today+6 so first sample event aligns with today-start window
    {:ok, _view, html} =
      live(
        conn,
        ~p"/meetings?mock=1&d=#{today_plus_6}&id=evt-1&series_id=series-alpha&title=Weekly%20Sync"
      )

    assert html =~ "meeting-modal"
  end

  test "time formatting uses full datetime when range crosses local day", %{conn: conn} do
    # Select d=today+6 so first event aligns to start of window; tz=+1380 (~+23h) crosses day
    today_plus_6 = Date.add(Date.utc_today(), 6) |> Date.to_iso8601()
    year = Date.utc_today().year |> Integer.to_string()
    {:ok, _view, html} = live(conn, ~p"/meetings?mock=1&d=#{today_plus_6}&tz=1380")
    assert html =~ " – "
    assert html =~ year
  end

  test "client_show and project_show modals render when params present", %{conn: conn} do
    {:ok, c} = DashboardSSD.Clients.create_client(%{name: "Modal Client"})
    {:ok, p} = DashboardSSD.Projects.create_project(%{name: "Modal Project"})

    {:ok, _view, html} = live(conn, ~p"/meetings?mock=1&client_id=#{c.id}")
    assert html =~ "client-read-modal"

    {:ok, _view2, html2} = live(conn, ~p"/meetings?mock=1&project_id=#{p.id}")
    assert html2 =~ "project-read-modal"
  end

  test "client and project chips patch to add respective ids preserving params", %{conn: conn} do
    {:ok, client} = Clients.create_client(%{name: "Chip C"})
    {:ok, project} = Projects.create_project(%{name: "Chip P"})

    # Create mappings so chips render
    %MeetingAssociation{}
    |> MeetingAssociation.changeset(%{
      calendar_event_id: "evt-1",
      client_id: client.id,
      origin: "manual",
      persist_series: true
    })
    |> Repo.insert!()

    %MeetingAssociation{}
    |> MeetingAssociation.changeset(%{
      calendar_event_id: "evt-2",
      project_id: project.id,
      origin: "manual",
      persist_series: true
    })
    |> Repo.insert!()

    d = Date.utc_today() |> Date.to_iso8601()
    {:ok, view, _} = live(conn, ~p"/meetings?mock=1&d=#{d}&tz=120")

    # Click client chip
    render_click(element(view, ~s(a[href*="client_id="])))
    assert_patch(view, ~p"/meetings?mock=1&d=#{d}&tz=120" <> ~s(&client_id=#{client.id}))

    # Click project chip
    {:ok, view2, _} = live(conn, ~p"/meetings?mock=1&d=#{d}&tz=120")
    render_click(element(view2, ~s(a[href*="project_id="])))
    assert_patch(view2, ~p"/meetings?mock=1&d=#{d}&tz=120" <> ~s(&project_id=#{project.id}))
  end

  test "prev from January wraps to December and next from December wraps to January", %{
    conn: conn
  } do
    # Use a known January and December anchor to test wrap-around
    jan = Date.new!(2025, 1, 7) |> Date.to_iso8601()
    dec = Date.new!(2025, 12, 7) |> Date.to_iso8601()

    # Prev from Jan → Dec of previous year
    {:ok, view, _} = live(conn, ~p"/meetings?mock=1&d=#{jan}")
    render_click(element(view, "button[phx-click='cal_prev_month']"))
    assert_patch(view, ~p"/meetings?mock=1&d=2024-12-07")

    # Next from Dec → Jan of next year
    {:ok, view2, _} = live(conn, ~p"/meetings?mock=1&d=#{dec}")
    render_click(element(view2, "button[phx-click='cal_next_month']"))
    assert_patch(view2, ~p"/meetings?mock=1&d=2026-01-07")
  end
end
