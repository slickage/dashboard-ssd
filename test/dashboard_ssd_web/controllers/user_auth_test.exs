defmodule DashboardSSDWeb.UserAuthTest do
  use DashboardSSDWeb.ConnCase, async: true

  alias DashboardSSD.Accounts
  alias DashboardSSDWeb.UserAuth

  setup do
    Accounts.ensure_role!("admin")
    Accounts.ensure_role!("employee")
    :ok
  end

  test "fetch_current_user assigns user", %{conn: conn} do
    {:ok, u} =
      Accounts.create_user(%{
        email: "u@example.com",
        name: "U",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = Plug.Test.init_test_session(conn, %{user_id: u.id})
    conn = UserAuth.fetch_current_user(conn, %{})
    assert conn.assigns.current_user.id == u.id
  end

  test "fetch_current_user assigns nil for invalid user_id", %{conn: conn} do
    conn = Plug.Test.init_test_session(conn, %{user_id: -1})
    conn = UserAuth.fetch_current_user(conn, %{})
    assert conn.assigns.current_user == nil
  end

  test "fetch_current_user assigns nil when no user_id", %{conn: conn} do
    conn = Plug.Test.init_test_session(conn, %{})
    conn = UserAuth.fetch_current_user(conn, %{})
    assert conn.assigns.current_user == nil
  end

  test "on_mount :ensure_authenticated halts when unauthenticated and continues when authenticated" do
    socket = %Phoenix.LiveView.Socket{assigns: %{}}

    assert {:halt, %Phoenix.LiveView.Socket{}} =
             UserAuth.on_mount(
               :ensure_authenticated,
               %{},
               %{"current_path" => "/projects"},
               socket
             )

    socket2 = %Phoenix.LiveView.Socket{assigns: %{current_user: %{id: 1}}}

    assert {:cont, %Phoenix.LiveView.Socket{}} =
             UserAuth.on_mount(:ensure_authenticated, %{}, %{}, socket2)
  end

  test "on_mount :ensure_authenticated redirects to root when no current_path provided" do
    socket = %Phoenix.LiveView.Socket{assigns: %{}}

    assert {:halt, %Phoenix.LiveView.Socket{}} =
             UserAuth.on_mount(:ensure_authenticated, %{}, %{}, socket)
  end

  test "on_mount {:ensure_authorized, action, subject} allows admin for any subject" do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "admu@example.com",
        name: "AdmU",
        role_id: Accounts.ensure_role!("admin").id
      })

    adm = DashboardSSD.Repo.preload(adm, :role)
    socket = %Phoenix.LiveView.Socket{assigns: %{current_user: adm}}
    assert {:cont, _} = UserAuth.on_mount({:ensure_authorized, :read, :clients}, %{}, %{}, socket)

    assert {:cont, _} =
             UserAuth.on_mount({:ensure_authorized, :read, :projects}, %{}, %{}, socket)
  end

  test "on_mount {:ensure_authorized, action, subject} halts when forbidden and continues when permitted" do
    {:ok, emp} =
      Accounts.create_user(%{
        email: "e@example.com",
        name: "E",
        role_id: Accounts.ensure_role!("employee").id
      })

    emp = DashboardSSD.Repo.preload(emp, :role)
    socket = %Phoenix.LiveView.Socket{assigns: %{current_user: emp}}

    assert {:cont, _} =
             UserAuth.on_mount({:ensure_authorized, :read, :projects}, %{}, %{}, socket)

    assert {:halt, _} = UserAuth.on_mount({:ensure_authorized, :read, :clients}, %{}, %{}, socket)
  end

  test "on_mount {:require, action, subject} redirects when unauthenticated and continues when authorized" do
    socket = %Phoenix.LiveView.Socket{assigns: %{}}

    assert {:halt, _} =
             UserAuth.on_mount(
               {:require, :read, :projects},
               %{},
               %{"current_path" => "/projects"},
               socket
             )

    {:ok, adm} =
      Accounts.create_user(%{
        email: "a@example.com",
        name: "A",
        role_id: Accounts.ensure_role!("admin").id
      })

    adm = DashboardSSD.Repo.preload(adm, :role)
    socket2 = %Phoenix.LiveView.Socket{assigns: %{current_user: adm}}
    assert {:cont, _} = UserAuth.on_mount({:require, :read, :projects}, %{}, %{}, socket2)
  end

  test "on_mount {:require, action, subject} halts when authenticated but not authorized" do
    {:ok, emp} =
      Accounts.create_user(%{
        email: "emp@example.com",
        name: "Emp",
        role_id: Accounts.ensure_role!("employee").id
      })

    emp = DashboardSSD.Repo.preload(emp, :role)
    socket = %Phoenix.LiveView.Socket{assigns: %{current_user: emp}}

    assert {:halt, _} = UserAuth.on_mount({:require, :read, :clients}, %{}, %{}, socket)
  end

  test "on_mount :mount_current_user assigns user and current_path" do
    {:ok, u} =
      Accounts.create_user(%{
        email: "mount@example.com",
        name: "Mount",
        role_id: Accounts.ensure_role!("employee").id
      })

    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    session = %{"user_id" => u.id, "current_path" => "/kb"}

    assert {:cont, socket} = UserAuth.on_mount(:mount_current_user, %{}, session, socket)
    assert socket.assigns.current_user.id == u.id
    assert socket.assigns.current_path == "/kb"
  end
end
