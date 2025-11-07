defmodule DashboardSSDWeb.InviteControllerTest do
  use DashboardSSDWeb.ConnCase, async: true

  alias DashboardSSD.Accounts
  alias DashboardSSD.Accounts.UserInvite
  alias DashboardSSD.Clients
  alias DashboardSSD.Repo

  setup do
    Enum.each(["admin", "employee", "client"], &Accounts.ensure_role!/1)
    :ok
  end

  test "saves invite token and redirects unauthenticated users to Google", %{conn: conn} do
    {:ok, invite} =
      Accounts.create_user_invite(%{
        "email" => "new-invite@example.com",
        "role" => "client"
      })

    conn = get(conn, ~p"/invites/#{invite.token}")

    assert get_session(conn, :invite_token) == invite.token
    assert redirected_to(conn) == ~p"/auth/google"

    flash = Phoenix.Flash.get(conn.assigns.flash, :info)
    assert flash =~ "Invitation saved"
  end

  test "applies invite immediately for authenticated user", %{conn: conn} do
    client = Clients.ensure_client!("InviteCo")

    {:ok, invite} =
      Accounts.create_user_invite(%{
        "email" => "existing-invitee@example.com",
        "role" => "client",
        "client_id" => client.id
      })

    {:ok, user} =
      Accounts.create_user(%{
        email: invite.email,
        name: "Existing Invitee",
        role_id: Accounts.ensure_role!("employee").id
      })

    conn =
      conn
      |> init_test_session(%{user_id: user.id})
      |> get(~p"/invites/#{invite.token}")

    assert redirected_to(conn) == ~p"/"
    assert get_session(conn, :invite_token) == nil

    flash = Phoenix.Flash.get(conn.assigns.flash, :info)
    assert flash =~ "Invitation accepted"

    updated_user = Accounts.get_user!(user.id) |> Repo.preload([:role, :client])
    assert updated_user.role.name == "client"
    assert updated_user.client_id == client.id

    updated_invite = Accounts.get_invite_by_token(invite.token)
    assert updated_invite.used_at
    assert updated_invite.accepted_user_id == updated_user.id
  end

  test "rejects used invite tokens", %{conn: conn} do
    {:ok, invite} =
      Accounts.create_user_invite(%{
        "email" => "used-invite@example.com",
        "role" => "client"
      })

    invite
    |> UserInvite.changeset(%{used_at: DateTime.utc_now(), accepted_user_id: nil})
    |> Repo.update!()

    conn = get(conn, ~p"/invites/#{invite.token}")

    assert redirected_to(conn) == ~p"/login"

    flash = Phoenix.Flash.get(conn.assigns.flash, :error)
    assert flash =~ "already been used"
  end

  test "rejects invalid invite tokens", %{conn: conn} do
    conn = get(conn, ~p"/invites/not-a-real-token")

    assert redirected_to(conn) == ~p"/login"

    flash = Phoenix.Flash.get(conn.assigns.flash, :error)
    assert flash =~ "Invalid invitation token"
  end
end
