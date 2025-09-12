defmodule DashboardSSDWeb.AuthControllerUeberauthTest do
  use DashboardSSDWeb.ConnCase, async: false

  alias DashboardSSD.{Accounts, Repo}
  alias DashboardSSD.Accounts.ExternalIdentity
  alias DashboardSSD.Accounts.User
  alias Ueberauth.Auth
  alias Ueberauth.Auth.{Credentials, Info}

  setup do
    # Make sure default role exists for user creation
    Accounts.ensure_role!("employee")
    :ok
  end

  test "callback (real mode) creates user from ueberauth assigns and sets session", %{conn: conn} do
    auth = %Auth{
      provider: :google,
      uid: "google-uid-123",
      info: %Info{email: "oauth-user@example.com", name: "OAuth User"},
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
    assert user.email == "oauth-user@example.com"
  end

  test "callback (real mode) logs in existing user without duplicating", %{conn: conn} do
    # First login
    auth = %Auth{
      provider: :google,
      uid: "uid-1",
      info: %Info{email: "exist@example.com", name: "Exist"}
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
      info: %Info{email: "exist@example.com", name: "Exist"}
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
      info: %Info{email: "post-user@example.com", name: "Post User"}
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
      info: %Info{email: "cred-user@example.com", name: "Cred User"},
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
      info: %Info{email: "cred-user@example.com", name: "Cred User"},
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
end
