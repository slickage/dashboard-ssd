defmodule DashboardSSDWeb.HomeLiveTest do
  use DashboardSSDWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias DashboardSSD.{Accounts, Clients, Projects, Notifications, Deployments}

  setup do
    Accounts.ensure_role!("admin")
    Accounts.ensure_role!("employee")
    :ok
  end

  test "admin sees home dashboard with projects, clients, workload, incidents, and CI status", %{
    conn: conn
  } do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "adm@example.com",
        name: "A",
        role_id: Accounts.ensure_role!("admin").id
      })

    # Create test data
    {:ok, client} = Clients.create_client(%{name: "TestClient"})
    {:ok, project} = Projects.create_project(%{name: "TestProject", client_id: client.id})

    {:ok, _alert} =
      Notifications.create_alert(%{
        project_id: project.id,
        message: "Test incident",
        status: "active"
      })

    {:ok, _deployment} =
      Deployments.create_deployment(%{project_id: project.id, status: "success"})

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, _view, html} = live(conn, ~p"/")

    # Check that key elements are present
    assert html =~ "Dashboard"
    assert html =~ "TestClient"
    assert html =~ "TestProject"
    assert html =~ "Test incident"
    assert html =~ "success"
  end

  test "employee sees home dashboard", %{conn: conn} do
    {:ok, emp} =
      Accounts.create_user(%{
        email: "emp@example.com",
        name: "E",
        role_id: Accounts.ensure_role!("employee").id
      })

    conn = init_test_session(conn, %{user_id: emp.id})
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "Dashboard"
  end

  test "anonymous is redirected to auth", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/auth/google?redirect_to=/"}}} = live(conn, ~p"/")
  end
end
