defmodule DashboardSSDWeb.AuthControllerUeberauthTest do
  use DashboardSSDWeb.ConnCase, async: false

  alias DashboardSSD.{Accounts, Repo}
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

  test "ueberauth provider configured" do
    providers = Application.get_env(:ueberauth, Ueberauth)[:providers] || []
    assert Enum.any?(providers, fn {name, _} -> name == :google end)
  end
end
