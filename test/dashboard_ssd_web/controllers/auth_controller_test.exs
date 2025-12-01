defmodule DashboardSSDWeb.AuthControllerTest do
  use DashboardSSDWeb.ConnCase, async: true

  alias DashboardSSD.Accounts
  alias DashboardSSD.Accounts.UserInvite
  alias DashboardSSD.Clients
  alias DashboardSSD.DrivePermissionWorkerStub
  alias DashboardSSD.Repo

  setup do
    original = Application.get_env(:dashboard_ssd, :oauth_mode)
    Application.put_env(:dashboard_ssd, :oauth_mode, :stub)

    accounts_prev = Application.get_env(:dashboard_ssd, Accounts)

    Application.put_env(:dashboard_ssd, Accounts,
      slickage_allowed_domains: ["slickage.com", "example.com"]
    )

    on_exit(fn ->
      Application.put_env(:dashboard_ssd, :oauth_mode, original)

      if accounts_prev,
        do: Application.put_env(:dashboard_ssd, Accounts, accounts_prev),
        else: Application.delete_env(:dashboard_ssd, Accounts)
    end)

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

  test "callback rejects unauthorized domains", %{conn: conn} do
    Application.put_env(:dashboard_ssd, Accounts, slickage_allowed_domains: ["slickage.com"])

    conn =
      conn
      |> init_test_session(%{})
      |> get("/auth/google/callback", %{"code" => "fake_auth_code"})

    assert redirected_to(conn) == ~p"/login"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "This Google account is not permitted. Ask an admin to invite you."
  end

  test "GET /auth/google/callback with ueberauth failure redirects with error", %{conn: conn} do
    conn = init_test_session(conn, %{})
    conn = assign(conn, :ueberauth_failure, %Ueberauth.Failure{errors: []})
    conn = get(conn, "/auth/google/callback")

    assert redirected_to(conn) == ~p"/"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "Authentication failed. Please try again."
  end

  test "callback redirects to stored redirect_to", %{conn: conn} do
    conn = init_test_session(conn, %{})
    conn = put_session(conn, :redirect_to, "/settings")
    conn = get(conn, "/auth/google/callback", %{"code" => "fake_auth_code"})

    assert conn.status in [301, 302]
    location = get_resp_header(conn, "location") |> List.first()
    assert location =~ "/settings"
  end

  test "callback renders close page when test env flag disabled", %{conn: conn} do
    prev_env = Application.get_env(:dashboard_ssd, :test_env?, true)
    Application.put_env(:dashboard_ssd, :test_env?, false)

    on_exit(fn -> Application.put_env(:dashboard_ssd, :test_env?, prev_env) end)

    conn = init_test_session(conn, %{})
    conn = get(conn, "/auth/google/callback", %{"code" => "fake_auth_code"})

    assert html_response(conn, 200) =~ "Authentication Complete"
  end

  test "applies invite token during callback", %{conn: conn} do
    Application.put_env(:dashboard_ssd, :drive_permission_worker, DrivePermissionWorkerStub)

    on_exit(fn -> Application.delete_env(:dashboard_ssd, :drive_permission_worker) end)

    client = Repo.insert!(%Clients.Client{name: "Invite Client"})

    invite =
      %UserInvite{}
      |> UserInvite.creation_changeset(%{
        email: "invitee@example.com",
        token: "invite-token",
        role_name: "client",
        client_id: client.id
      })
      |> Repo.insert!()

    conn =
      conn
      |> init_test_session(%{invite_token: invite.token})
      |> assign(:ueberauth_auth, %Ueberauth.Auth{
        info: %Ueberauth.Auth.Info{email: invite.email, name: "Invitee"},
        credentials: %Ueberauth.Auth.Credentials{}
      })
      |> get("/auth/google/callback")

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Invitation applied."

    user_id = get_session(conn, :user_id)
    user = Accounts.get_user!(user_id)
    assert user.client_id == client.id
  end
end
