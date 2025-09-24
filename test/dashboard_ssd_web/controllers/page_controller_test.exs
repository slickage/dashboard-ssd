defmodule DashboardSSDWeb.PageControllerTest do
  use DashboardSSDWeb.ConnCase

  test "GET / redirects anonymous users to auth", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == "/auth/google?redirect_to=/"
  end
end
