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
end

