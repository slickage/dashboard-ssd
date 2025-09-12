defmodule DashboardSSDWeb.AuthorizationTest do
  use DashboardSSDWeb.ConnCase, async: true

  alias DashboardSSD.Accounts

  setup do
    Accounts.ensure_role!("admin")
    Accounts.ensure_role!("employee")
    Accounts.ensure_role!("client")
    :ok
  end

  test "employee can read projects but not clients", %{conn: conn} do
    {:ok, emp} =
      Accounts.create_user(%{
        email: "emp@example.com",
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

    assert conn.status == 403
  end

  test "client can read projects but not clients", %{conn: conn} do
    {:ok, cli} =
      Accounts.create_user(%{
        email: "cli@example.com",
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

    assert conn.status == 403
  end

  test "admin can read both projects and clients", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "adm@example.com",
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
