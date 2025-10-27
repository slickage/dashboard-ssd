defmodule DashboardSSDWeb.PageControllerTest do
  use DashboardSSDWeb.ConnCase, async: true

  alias DashboardSSD.Accounts

  setup do
    admin_role = Accounts.ensure_role!("admin")
    Accounts.ensure_role!("employee")

    {:ok, user} =
      Accounts.create_user(%{
        email: "admin+home@example.com",
        name: "Admin Home",
        role_id: admin_role.id
      })

    %{user: user}
  end

  test "GET / redirects anonymous users to login", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == "/login?redirect_to=%2F"
  end

  test "renders home for authenticated users", %{conn: conn, user: user} do
    conn =
      conn
      |> init_test_session(%{user_id: user.id})
      |> get(~p"/")

    response = html_response(conn, 200)
    assert response =~ "Dashboard Home"
  end
end
