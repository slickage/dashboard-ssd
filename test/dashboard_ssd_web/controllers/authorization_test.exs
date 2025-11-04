defmodule DashboardSSDWeb.AuthorizationTest do
  use DashboardSSDWeb.ConnCase, async: true

  alias DashboardSSD.Accounts
  alias DashboardSSD.Auth.Capabilities

  setup do
    Enum.each(["admin", "employee", "client"], &Accounts.ensure_role!/1)

    Capabilities.default_assignments()
    |> Enum.each(fn {role, caps} ->
      Accounts.replace_role_capabilities(role, caps, granted_by_id: nil)
    end)

    :ok
  end

  test "employee can read projects and clients", %{conn: conn} do
    {:ok, emp} =
      Accounts.create_user(%{
        email: "emp@slickage.com",
        name: "E",
        role_id: Accounts.ensure_role!("employee").id
      })

    conn =
      conn
      |> init_test_session(%{user_id: emp.id})
      |> get(~p"/protected/projects")

    assert response(conn, 200) =~ "projects ok"

    conn =
      build_conn()
      |> init_test_session(%{user_id: emp.id})
      |> get(~p"/protected/clients")

    assert response(conn, 200) =~ "clients ok"
  end

  test "client can read projects and clients", %{conn: conn} do
    {:ok, cli} =
      Accounts.create_user(%{
        email: "cli@slickage.com",
        name: "C",
        role_id: Accounts.ensure_role!("client").id
      })

    conn =
      conn
      |> init_test_session(%{user_id: cli.id})
      |> get(~p"/protected/projects")

    assert response(conn, 200) =~ "projects ok"

    conn =
      build_conn()
      |> init_test_session(%{user_id: cli.id})
      |> get(~p"/protected/clients")

    assert response(conn, 200) =~ "clients ok"
  end

  test "admin can read both projects and clients", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "adm@slickage.com",
        name: "A",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn =
      conn
      |> init_test_session(%{user_id: adm.id})
      |> get(~p"/protected/projects")

    assert response(conn, 200) =~ "projects ok"

    conn =
      build_conn()
      |> init_test_session(%{user_id: adm.id})
      |> get(~p"/protected/clients")

    assert response(conn, 200) =~ "clients ok"
  end
end
