defmodule DashboardSSDWeb.AuthControllerUeberauthTest do
  use DashboardSSDWeb.ConnCase, async: false

  alias DashboardSSD.{Accounts, Clients, Repo}
  alias DashboardSSD.Accounts.ExternalIdentity
  alias DashboardSSD.Accounts.User
  alias Ueberauth.Auth
  alias Ueberauth.Auth.{Credentials, Info}

  setup do
    Enum.each(["admin", "employee", "client"], &Accounts.ensure_role!/1)

    prev = Application.get_env(:dashboard_ssd, DashboardSSD.Accounts)

    Application.put_env(
      :dashboard_ssd,
      DashboardSSD.Accounts,
      Keyword.merge(prev || [], slickage_allowed_domains: ["slickage.com", "example.com"])
    )

    on_exit(fn ->
      if prev do
        Application.put_env(:dashboard_ssd, DashboardSSD.Accounts, prev)
      else
        Application.delete_env(:dashboard_ssd, DashboardSSD.Accounts)
      end
    end)

    :ok
  end

  test "callback (real mode) creates user from ueberauth assigns and sets session", %{conn: conn} do
    auth = %Auth{
      provider: :google,
      uid: "google-uid-123",
      info: %Info{email: "oauth-user@slickage.com", name: "OAuth User"},
      credentials: %Credentials{
        token: "tok",
        refresh_token: "ref",
        expires_at: DateTime.utc_now()
      }
    }

    conn =
      conn
      |> init_test_session(%{})
      |> Plug.Conn.assign(:ueberauth_auth, auth)
      |> get(~p"/auth/google/callback")

    assert get_session(conn, :user_id)
    assert redirected_to(conn) == ~p"/"

    user = Repo.get(User, get_session(conn, :user_id))
    assert user.email == "oauth-user@slickage.com"
  end

  test "callback (real mode) logs in existing user without duplicating", %{conn: conn} do
    # First login
    auth = %Auth{
      provider: :google,
      uid: "uid-1",
      info: %Info{email: "exist@slickage.com", name: "Exist"}
    }

    conn =
      conn
      |> init_test_session(%{})
      |> Plug.Conn.assign(:ueberauth_auth, auth)
      |> get(~p"/auth/google/callback")

    user_id_1 = get_session(conn, :user_id)

    # Second login (same email, different uid)
    auth2 = %Auth{
      provider: :google,
      uid: "uid-2",
      info: %Info{email: "exist@slickage.com", name: "Exist"}
    }

    conn2 =
      build_conn()
      |> init_test_session(%{})
      |> Plug.Conn.assign(:ueberauth_auth, auth2)
      |> get(~p"/auth/google/callback")

    user_id_2 = get_session(conn2, :user_id)

    assert user_id_1 == user_id_2
  end

  test "callback handles ueberauth failure by redirecting", %{conn: conn} do
    failure = %Ueberauth.Failure{
      provider: :google,
      errors: [%Ueberauth.Failure.Error{message: "bad"}]
    }

    conn =
      conn
      |> init_test_session(%{})
      |> Plug.Conn.assign(:ueberauth_failure, failure)
      |> get(~p"/auth/google/callback")

    assert redirected_to(conn) == ~p"/"
  end

  test "ueberauth provider configured" do
    providers = Application.get_env(:ueberauth, Ueberauth)[:providers] || []
    assert Enum.any?(providers, fn {name, _} -> name == :google end)
  end

  test "callback supports POST with ueberauth assigns", %{conn: conn} do
    auth = %Auth{
      provider: :google,
      uid: "uid-post-1",
      info: %Info{email: "post-user@slickage.com", name: "Post User"}
    }

    conn =
      conn
      |> init_test_session(%{})
      |> Plug.Conn.assign(:ueberauth_auth, auth)
      |> post(~p"/auth/google/callback")

    assert get_session(conn, :user_id)
    assert redirected_to(conn) == ~p"/"
  end

  test "persists credentials and converts integer expires_at; updates on subsequent login", %{
    conn: conn
  } do
    now_sec = System.os_time(:second)

    auth = %Auth{
      provider: :google,
      uid: "cred-uid-1",
      info: %Info{email: "cred-user@slickage.com", name: "Cred User"},
      credentials: %Credentials{token: "tok-1", refresh_token: "ref-1", expires_at: now_sec}
    }

    conn =
      conn
      |> init_test_session(%{})
      |> Plug.Conn.assign(:ueberauth_auth, auth)
      |> get(~p"/auth/google/callback")

    user_id = get_session(conn, :user_id)
    assert user_id

    identity = Repo.get_by(ExternalIdentity, user_id: user_id, provider: "google")
    assert identity
    assert identity.token == "tok-1"
    assert identity.refresh_token == "ref-1"
    assert match?(%DateTime{}, identity.expires_at)
    assert DateTime.to_unix(identity.expires_at) == now_sec

    # Second login updates tokens and expires_at
    later = now_sec + 3600

    auth2 = %Auth{
      provider: :google,
      uid: "cred-uid-1",
      info: %Info{email: "cred-user@slickage.com", name: "Cred User"},
      credentials: %Credentials{token: "tok-2", refresh_token: "ref-2", expires_at: later}
    }

    conn2 =
      build_conn()
      |> init_test_session(%{})
      |> Plug.Conn.assign(:ueberauth_auth, auth2)
      |> get(~p"/auth/google/callback")

    user_id2 = get_session(conn2, :user_id)
    assert user_id2 == user_id

    identity2 = Repo.get_by(ExternalIdentity, user_id: user_id, provider: "google")
    assert identity2.token == "tok-2"
    assert identity2.refresh_token == "ref-2"
    assert DateTime.to_unix(identity2.expires_at) == later
  end

  test "applies invite token on successful oauth login", %{conn: conn} do
    client = Clients.ensure_client!("InviteCo")
    admin_role = Accounts.ensure_role!("admin")

    {:ok, admin} =
      Accounts.create_user(%{
        email: "admin-invite@slickage.com",
        name: "Admin Invite",
        role_id: admin_role.id
      })

    {:ok, invite} =
      Accounts.create_user_invite(%{
        "email" => "invited-user@example.com",
        "role" => "client",
        "client_id" => client.id,
        "invited_by_id" => admin.id
      })

    auth = %Auth{
      provider: :google,
      uid: "invite-uid-1",
      info: %Info{email: invite.email, name: "Invited User"}
    }

    conn =
      conn
      |> init_test_session(%{invite_token: invite.token})
      |> Plug.Conn.assign(:ueberauth_auth, auth)
      |> get(~p"/auth/google/callback")

    assert redirected_to(conn) == ~p"/"
    assert get_session(conn, :invite_token) == nil

    flash_info = Phoenix.Flash.get(conn.assigns.flash, :info)
    assert flash_info =~ "Invitation applied"

    user =
      Accounts.get_user_by_email(invite.email)
      |> Repo.preload([:role, :client])

    assert user.role.name == "client"
    assert user.client_id == client.id

    updated_invite = Accounts.get_invite_by_token(invite.token)
    assert updated_invite.used_at
    assert updated_invite.accepted_user_id == user.id
  end
end
