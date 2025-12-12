defmodule DashboardSSDWeb.MeetingsLiveTest do
  use DashboardSSDWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts

  setup %{conn: conn} do
    {:ok, user} =
      Accounts.create_user(%{
        email: "meetings_tester@example.com",
        name: "M Test",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, conn: init_test_session(conn, %{user_id: user.id})}
  end

  test "renders meetings index", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/meetings")
    assert html =~ "Meetings"
  end

  test "renders sample meetings when mock=1", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/meetings?mock=1")
    assert html =~ "Weekly Sync – Project Alpha"
    assert html =~ "Client Review – Contoso"
  end

  # Note: agenda preview in mock mode skips Fireflies calls by design.
end
