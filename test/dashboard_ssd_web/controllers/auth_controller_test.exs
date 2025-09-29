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

  test "DELETE /logout clears session and redirects", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{user_id: 123})
      |> delete("/logout")

    assert redirected_to(conn) == ~p"/"
    assert get_session(conn, :user_id) == nil
  end

  test "GET /logout clears session and redirects (GET route)", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{user_id: 456})
      |> get("/logout")

    assert redirected_to(conn) == ~p"/"
    assert get_session(conn, :user_id) == nil
  end

  test "callback without assigns and :real mode redirects with error", %{conn: conn} do
    original = Application.get_env(:dashboard_ssd, :oauth_mode)
    Application.put_env(:dashboard_ssd, :oauth_mode, :real)
    on_exit(fn -> Application.put_env(:dashboard_ssd, :oauth_mode, original) end)

    conn =
      conn
      |> init_test_session(%{})
      |> get(~p"/auth/google/callback")

    assert redirected_to(conn) == ~p"/"
  end

  test "GET /auth/google/callback with ueberauth failure redirects with error", %{conn: conn} do
    conn = init_test_session(conn, %{})
    conn = assign(conn, :ueberauth_failure, %Ueberauth.Failure{errors: []})
    conn = get(conn, "/auth/google/callback")

    assert redirected_to(conn) == ~p"/"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "Authentication failed. Please try again."
  end
end
