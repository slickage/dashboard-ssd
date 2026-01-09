defmodule DashboardSSDWeb.MeetingsLive.IndexNotesIntegrationTest do
  use DashboardSSDWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts
  alias DashboardSSD.Meetings.FirefliesStore
  alias DashboardSSD.Meetings.NotesStore

  setup %{conn: conn} do
    {:ok, user} =
      Accounts.create_user(%{
        email: "meetings_notes@example.com",
        name: "Mtg Notes",
        role_id: Accounts.ensure_role!("admin").id
      })

    prev = Application.get_env(:dashboard_ssd, :integrations)

    Application.put_env(
      :dashboard_ssd,
      :integrations,
      Keyword.merge(prev || [], fireflies_api_token: "tok")
    )

    on_exit(fn ->
      if prev,
        do: Application.put_env(:dashboard_ssd, :integrations, prev),
        else: Application.delete_env(:dashboard_ssd, :integrations)
    end)

    {:ok, conn: init_test_session(conn, %{user_id: user.id})}
  end

  test "renders notes from DB per occurrence (mock mode skips remote)", %{conn: conn} do
    # Seed MeetingNote records for the two sample mock events
    selected_date = Date.utc_today()
    start_date = Date.add(selected_date, -6)
    {:ok, start_dt} = DateTime.new(start_date, ~T[00:00:00], "Etc/UTC")
    ev1_date = DateTime.to_date(start_dt)
    ev2_date = DateTime.to_date(DateTime.add(start_dt, 2 * 3600, :second))

    :ok =
      NotesStore.upsert("evt-1", ev1_date, %{
        accomplished: "Alpha notes",
        action_items: ["AX", "AY"],
        transcript_id: "t-alpha"
      })

    :ok =
      NotesStore.upsert("evt-2", ev2_date, %{
        accomplished: "Contoso notes",
        action_items: ["CX"],
        transcript_id: "t-contoso"
      })

    {:ok, _view, html} = live(conn, ~p"/meetings?mock=1")

    assert html =~ "Agenda"
    # Prefers action_items over accomplished text when present
    assert html =~ "AX"
    assert html =~ "AY"
    assert html =~ "CX"
  end

  test "shows placeholder when no per-occurrence notes and no manual agenda (no series fallback)",
       %{conn: conn} do
    # Seed series artifacts that would previously have appeared via fallback
    :ok =
      FirefliesStore.upsert("series-alpha", %{accomplished: "Series Alpha", action_items: ["SA"]})

    :ok =
      FirefliesStore.upsert("series-contoso", %{
        accomplished: "Series Contoso",
        action_items: ["SC"]
      })

    # Do not seed meeting_notes; in mock mode, remote is skipped and per-occurrence is :not_found
    {:ok, _view, html} = live(conn, ~p"/meetings?mock=1")

    assert html =~ "No notes for this occurrence yet"
    refute html =~ "Series Alpha"
    refute html =~ "SA"
    refute html =~ "Series Contoso"
    refute html =~ "SC"
  end
end
