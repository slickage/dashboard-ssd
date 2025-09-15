defmodule DashboardSSDWeb.ClientsLiveTest do
  use DashboardSSDWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts
  alias DashboardSSD.Clients

  setup do
    Accounts.ensure_role!("admin")
    Accounts.ensure_role!("employee")
    :ok
  end

  test "admin sees clients list", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "adm@example.com",
        name: "A",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, _} = Clients.create_client(%{name: "Acme"})
    {:ok, _} = Clients.create_client(%{name: "Globex"})

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, _view, html} = live(conn, ~p"/clients")

    assert html =~ "Clients"
    assert html =~ "Acme"
    assert html =~ "Globex"
  end

  test "employee is redirected with forbidden", %{conn: conn} do
    {:ok, emp} =
      Accounts.create_user(%{
        email: "emp@example.com",
        name: "E",
        role_id: Accounts.ensure_role!("employee").id
      })

    conn = init_test_session(conn, %{user_id: emp.id})
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/clients")
  end

  test "anonymous is redirected", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/auth/google?redirect_to=/clients"}}} =
             live(conn, ~p"/clients")
  end
end
