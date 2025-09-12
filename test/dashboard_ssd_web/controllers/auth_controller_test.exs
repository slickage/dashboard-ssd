defmodule DashboardSSDWeb.AuthControllerTest do
  use DashboardSSDWeb.ConnCase, async: true

  setup do
    original = Application.get_env(:dashboard_ssd, :oauth_mode)
    Application.put_env(:dashboard_ssd, :oauth_mode, :stub)
    on_exit(fn -> Application.put_env(:dashboard_ssd, :oauth_mode, original) end)
    :ok
  end

  test "GET /auth/google redirects to provider", %{conn: conn} do
    conn = get(conn, "/auth/google")
    assert conn.status in [301, 302]
    assert get_resp_header(conn, "location") != []
  end

  test "GET /auth/google/callback registers and logs in new user", %{conn: conn} do
    conn = init_test_session(conn, %{})
    conn = get(conn, "/auth/google/callback", %{"code" => "fake_auth_code"})

    # Expect a user session to be set and redirect to home on success
    user_id = get_session(conn, :user_id)
    assert is_nil(user_id) == false
    assert conn.status in [301, 302]
  end

  test "GET /auth/google/callback logs in existing user", %{conn: conn} do
    conn = init_test_session(conn, %{})
    conn = get(conn, "/auth/google/callback", %{"code" => "fake_auth_code_existing"})

    user_id = get_session(conn, :user_id)
    assert is_nil(user_id) == false
    assert conn.status in [301, 302]
  end
end
