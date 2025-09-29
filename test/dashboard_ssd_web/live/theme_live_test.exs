defmodule DashboardSSDWeb.ThemeLiveTest do
  use DashboardSSDWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts

  setup do
    admin_role = Accounts.ensure_role!("admin")

    {:ok, user} =
      Accounts.create_user(%{
        email: "theme-admin@example.com",
        name: "Theme Admin",
        role_id: admin_role.id
      })

    %{user: user}
  end

  test "theme layout wraps live views", %{conn: conn, user: user} do
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ ~s(data-role="theme-shell")
  end

  test "navigation component is rendered once per page", %{conn: conn, user: user} do
    conn = init_test_session(conn, %{user_id: user.id})

    {:ok, _view, html} = live(conn, ~p"/clients")

    nav_instances = Regex.scan(~r/data-role="theme-nav"/, html) |> length()
    assert nav_instances == 1
  end
end
