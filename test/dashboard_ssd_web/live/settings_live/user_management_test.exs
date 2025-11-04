defmodule DashboardSSDWeb.SettingsLive.UserManagementTest do
  use DashboardSSDWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts
  alias DashboardSSD.Auth.Capabilities
  alias DashboardSSD.Clients
  alias DashboardSSD.Repo

  setup do
    Enum.each(["admin", "employee", "client"], &Accounts.ensure_role!/1)

    {:ok, admin} =
      Accounts.create_user(%{
        email: "admin-settings@example.com",
        name: "Admin Settings",
        role_id: Accounts.ensure_role!("admin").id
      })

    Capabilities.default_assignments()
    |> Enum.each(fn {role, caps} ->
      Accounts.replace_role_capabilities(role, caps, granted_by_id: admin.id)
    end)

    Clients.ensure_client!("Acme Corp")

    {:ok, conn: init_test_session(build_conn(), %{user_id: admin.id}), admin: admin}
  end

  test "send_invite creates a pending invite and shows confirmation", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings")

    params = %{
      "invite" => %{
        "email" => "new-client@example.com",
        "role" => "client",
        "client_id" => ""
      }
    }

    view
    |> element("form[phx-submit='send_invite']")
    |> render_submit(params)

    html = render(view)
    assert html =~ "Invitation sent."
    assert html =~ "new-client@example.com"
  end

  test "send_invite returns error when user already exists", %{conn: conn} do
    {:ok, _user} =
      Accounts.create_user(%{
        email: "existing-client@example.com",
        name: "Existing Client",
        role_id: Accounts.ensure_role!("client").id
      })

    {:ok, view, _html} = live(conn, ~p"/settings")

    params = %{
      "invite" => %{
        "email" => "existing-client@example.com",
        "role" => "client",
        "client_id" => ""
      }
    }

    view
    |> element("form[phx-submit='send_invite']")
    |> render_submit(params)

    assert render(view) =~ "A user with that email already exists."
  end

  test "send_invite surfaces validation errors", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings")

    params = %{
      "invite" => %{
        "email" => "not-an-email",
        "role" => "client",
        "client_id" => ""
      }
    }

    view
    |> element("form[phx-submit='send_invite']")
    |> render_submit(params)

    assert render(view) =~ "Email has invalid format"
  end

  test "update_user persists new role and client", %{conn: conn} do
    client = Clients.ensure_client!("Beta LLC")

    {:ok, employee} =
      Accounts.create_user(%{
        email: "managed-user@example.com",
        name: "Managed User",
        role_id: Accounts.ensure_role!("employee").id
      })

    {:ok, view, _html} = live(conn, ~p"/settings")

    params = %{
      "user_id" => "#{employee.id}",
      "role" => "client",
      "client_id" => "#{client.id}"
    }

    view
    |> element("form#manage-user-#{employee.id}")
    |> render_submit(params)

    html = render(view)
    assert html =~ "User updated."

    updated =
      Accounts.get_user!(employee.id)
      |> Repo.preload([:role, :client])

    assert updated.role.name == "client"
    assert updated.client_id == client.id
  end

  test "used invites are assigned when present", %{conn: conn} do
    {:ok, admin} =
      Accounts.create_user(%{
        email: "used-admin@slickage.com",
        name: "Used Admin",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, invite} =
      Accounts.create_user_invite(%{
        "email" => "used-client@example.com",
        "role" => "client",
        "invited_by_id" => admin.id
      })

    {:ok, invited} =
      Accounts.create_user(%{
        email: invite.email,
        name: "Used Client",
        role_id: Accounts.ensure_role!("client").id
      })

    {:ok, _} = Accounts.apply_invite(Repo.preload(invited, [:role, :client]), invite.token)

    {:ok, view, _html} = live(conn, ~p"/settings")

    state = :sys.get_state(view.pid)
    socket = Map.fetch!(state, :socket)

    assert Enum.any?(socket.assigns.used_invites, &(&1.email == invite.email))
  end
end
