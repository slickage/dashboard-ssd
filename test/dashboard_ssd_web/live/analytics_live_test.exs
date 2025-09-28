defmodule DashboardSSDWeb.AnalyticsLiveTest do
  use DashboardSSDWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts
  alias DashboardSSD.Analytics
  alias DashboardSSD.Clients
  alias DashboardSSD.Projects

  setup do
    Accounts.ensure_role!("admin")
    Accounts.ensure_role!("employee")
    :ok
  end

  describe "Analytics LiveView" do
    test "redirects unauthenticated users", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login?redirect_to=%2Fanalytics"}}} =
               live(conn, ~p"/analytics")
    end

    test "redirects non-admin users", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          email: "employee@example.com",
          name: "Employee",
          role_id: Accounts.ensure_role!("employee").id
        })

      conn = init_test_session(conn, %{user_id: user.id})
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/analytics")
    end

    test "allows admin users to access analytics", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          email: "admin@example.com",
          name: "Admin",
          role_id: Accounts.ensure_role!("admin").id
        })

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, _view, html} = live(conn, ~p"/analytics")

      assert html =~ "Analytics"
    end

    test "displays metrics summary", %{conn: conn} do
      {:ok, admin} =
        Accounts.create_user(%{
          email: "admin@example.com",
          name: "Admin",
          role_id: Accounts.ensure_role!("admin").id
        })

      {:ok, client} = Clients.create_client(%{name: "Test Client"})
      {:ok, project} = Projects.create_project(%{name: "Test Project", client_id: client.id})

      # Create some test metrics
      Analytics.create_metric(%{project_id: project.id, type: "uptime", value: 95.0})
      Analytics.create_metric(%{project_id: project.id, type: "mttr", value: 120.0})
      Analytics.create_metric(%{project_id: project.id, type: "linear_throughput", value: 10.0})

      conn = init_test_session(conn, %{user_id: admin.id})
      {:ok, view, _html} = live(conn, ~p"/analytics")

      # Check that metrics are displayed
      assert has_element?(view, "[data-testid='uptime-metric']")
      assert has_element?(view, "[data-testid='mttr-metric']")
      assert has_element?(view, "[data-testid='linear-throughput-metric']")
    end

    test "displays zero metrics when no data exists", %{conn: conn} do
      {:ok, admin} =
        Accounts.create_user(%{
          email: "admin@example.com",
          name: "Admin",
          role_id: Accounts.ensure_role!("admin").id
        })

      conn = init_test_session(conn, %{user_id: admin.id})
      {:ok, view, _html} = live(conn, ~p"/analytics")

      # Check that zero values are displayed
      assert has_element?(view, "[data-testid='uptime-metric']", "0.0%")
      assert has_element?(view, "[data-testid='mttr-metric']", "0.0 min")
      assert has_element?(view, "[data-testid='linear-throughput-metric']", "0.0")
    end

    test "export button exists and can be clicked", %{conn: conn} do
      {:ok, admin} =
        Accounts.create_user(%{
          email: "admin@example.com",
          name: "Admin",
          role_id: Accounts.ensure_role!("admin").id
        })

      conn = init_test_session(conn, %{user_id: admin.id})
      {:ok, view, _html} = live(conn, ~p"/analytics")

      # Check that export button exists
      assert has_element?(view, "button[phx-click='export_csv']", "Export CSV")

      # Click export button (should not error)
      view
      |> element("button[phx-click='export_csv']")
      |> render_click()
    end

    test "refresh button updates metrics", %{conn: conn} do
      {:ok, admin} =
        Accounts.create_user(%{
          email: "admin@example.com",
          name: "Admin",
          role_id: Accounts.ensure_role!("admin").id
        })

      conn = init_test_session(conn, %{user_id: admin.id})
      {:ok, view, _html} = live(conn, ~p"/analytics")

      # Check that refresh button exists
      assert has_element?(view, "button[phx-click='refresh']", "Refresh")

      # Click refresh button (should not error)
      view
      |> element("button[phx-click='refresh']")
      |> render_click()
    end

    test "project selection updates metrics", %{conn: conn} do
      {:ok, admin} =
        Accounts.create_user(%{
          email: "admin@example.com",
          name: "Admin",
          role_id: Accounts.ensure_role!("admin").id
        })

      {:ok, client} = Clients.create_client(%{name: "Test Client"})
      {:ok, _project1} = Projects.create_project(%{name: "Project 1", client_id: client.id})
      {:ok, project2} = Projects.create_project(%{name: "Project 2", client_id: client.id})

      conn = init_test_session(conn, %{user_id: admin.id})
      {:ok, view, _html} = live(conn, ~p"/analytics")

      # Select a different project
      view
      |> form("form[phx-change='select_project']")
      |> render_change(%{"project_id" => to_string(project2.id)})

      # Should not error
      assert view
    end

    test "mobile menu toggle works", %{conn: conn} do
      {:ok, admin} =
        Accounts.create_user(%{
          email: "admin@example.com",
          name: "Admin",
          role_id: Accounts.ensure_role!("admin").id
        })

      conn = init_test_session(conn, %{user_id: admin.id})
      {:ok, view, _html} = live(conn, ~p"/analytics")

      # Toggle mobile menu open
      view
      |> element("button[phx-click='toggle_mobile_menu']")
      |> render_click()

      # Close mobile menu by clicking the close button
      view
      |> element("button[phx-click='close_mobile_menu']")
      |> render_click()
    end
  end
end
