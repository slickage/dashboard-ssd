defmodule DashboardSSDWeb.MeetingLiveTest do
  use DashboardSSDWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts

  setup %{conn: conn} do
    {:ok, user} =
      Accounts.create_user(%{
        email: "meeting_tester@example.com",
        name: "Mtg Test",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, conn: init_test_session(conn, %{user_id: user.id})}
  end

  test "renders meeting detail", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/meetings/evt-demo")
    assert html =~ "Meeting"
  end

  test "shows 'What to bring' from manual items when text includes 'prepare'", %{conn: conn} do
    # Insert a manual agenda item containing the keyword 'prepare'
    evt = "evt-bring"
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(DashboardSSD.Repo)
    {:ok, _a} = DashboardSSD.Meetings.Agenda.create_item(%{calendar_event_id: evt, text: "Please prepare budget doc", position: 0})

    {:ok, _view, html} = live(conn, ~p"/meetings/#{evt}")
    assert html =~ "What to bring"
    assert html =~ "prepare budget"
  end
end
