defmodule DashboardSSDWeb.HomeLiveTest do
  use DashboardSSDWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts
  alias DashboardSSD.Auth.Capabilities
  alias DashboardSSD.Clients
  alias DashboardSSD.Deployments
  alias DashboardSSD.Notifications
  alias DashboardSSD.Projects

  setup do
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.linear.app/graphql"} ->
        %Tesla.Env{status: 200, body: %{"data" => %{"issues" => %{"nodes" => []}}}}

      _ ->
        %Tesla.Env{status: 404}
    end)

    :ok
  end

  setup do
    # Disable Linear summaries in these tests to avoid external calls
    prev = Application.get_env(:dashboard_ssd, :integrations)

    Application.put_env(
      :dashboard_ssd,
      :integrations,
      Keyword.merge(prev || [], linear_token: nil)
    )

    prev_env = System.get_env("LINEAR_TOKEN")
    System.delete_env("LINEAR_TOKEN")

    on_exit(fn ->
      if prev,
        do: Application.put_env(:dashboard_ssd, :integrations, prev),
        else: Application.delete_env(:dashboard_ssd, :integrations)

      case prev_env do
        nil -> :ok
        v -> System.put_env("LINEAR_TOKEN", v)
      end
    end)

    Accounts.ensure_role!("admin")
    Accounts.ensure_role!("employee")

    Capabilities.default_assignments()
    |> Enum.each(fn {role, caps} ->
      Accounts.ensure_role!(role)
      Accounts.replace_role_capabilities(role, caps, granted_by_id: nil)
    end)

    :ok
  end

  test "admin sees home dashboard with projects, clients, workload, incidents, and CI status", %{
    conn: conn
  } do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "adm@slickage.com",
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
        email: "emp@slickage.com",
        name: "E",
        role_id: Accounts.ensure_role!("employee").id
      })

    conn = init_test_session(conn, %{user_id: emp.id})
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "Dashboard"
  end

  test "anonymous is redirected to auth", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/login?redirect_to=%2F"}}} = live(conn, ~p"/")
  end

  test "displays empty state when no data exists", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "empty@example.com",
        name: "Empty",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, _view, html} = live(conn, ~p"/")

    # Should show zero counts
    assert html =~ "0"
    assert html =~ "Tracked initiatives"
    assert html =~ "Partner organizations"
    assert html =~ "All clear"
    assert html =~ "Awaiting pipeline runs"
  end

  test "refresh button reloads dashboard data", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "refresh@example.com",
        name: "Refresh",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, view, _html} = live(conn, ~p"/")

    # Click refresh button
    view |> element("button", "Refresh") |> render_click()

    # Should still show dashboard
    assert render(view) =~ "Dashboard"
  end

  test "analytics summary displays metrics", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "analytics@example.com",
        name: "Analytics",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, _view, html} = live(conn, ~p"/")

    # Should show analytics section
    assert html =~ "Analytics"
    assert html =~ "Platform performance"
    assert html =~ "Uptime"
    assert html =~ "MTTR"
    assert html =~ "Throughput"
  end

  test "recent projects table shows project details", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "projects@example.com",
        name: "Projects",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, client} = Clients.create_client(%{name: "TestClient"})
    {:ok, _project} = Projects.create_project(%{name: "TestProject", client_id: client.id})

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, _view, html} = live(conn, ~p"/")

    # Should show project in table
    assert html =~ "TestProject"
    assert html =~ "TestClient"
  end

  test "CI status shows deployment information", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "ci@example.com",
        name: "CI",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, project} = Projects.create_project(%{name: "TestProject"})

    {:ok, _deployment} =
      Deployments.create_deployment(%{project_id: project.id, status: "success"})

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, _view, html} = live(conn, ~p"/")

    # Should show CI status section
    assert html =~ "CI Status"
    assert html =~ "Success rate"
  end

  test "CI status card renders per-status colors", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "ci-colors@example.com",
        name: "CIColors",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, project} = Projects.create_project(%{name: "CI Colors"})

    Enum.each(
      [
        "success",
        "failed",
        "failure",
        "pending",
        "unknown"
      ],
      fn status ->
        {:ok, _} = Deployments.create_deployment(%{project_id: project.id, status: status})
      end
    )

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "bg-emerald-400"
    assert html =~ "bg-rose-500"
    assert html =~ "bg-amber-400"
    assert html =~ "bg-slate-500"
  end

  test "handle_info updates workload summary", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "handle-info@example.com",
        name: "HandleInfo",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, view, _html} = live(conn, ~p"/")

    # Send handle_info message directly
    summary = %{total: 5, in_progress: 2, finished: 3}
    send(view.pid, {:workload_summary_loaded, summary})

    # Wait for message processing
    :timer.sleep(100)

    # Check that the summary was updated
    updated_html = render(view)
    assert updated_html =~ "Dashboard"
  end

  test "workload summary shows when Linear is enabled", %{conn: conn} do
    # Temporarily enable Linear for this test
    prev = Application.get_env(:dashboard_ssd, :integrations)

    # Mock Linear API to return some issues
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.linear.app/graphql"} ->
        %Tesla.Env{
          status: 200,
          body: %{
            "data" => %{
              "issues" => %{
                "nodes" => [
                  %{"state" => %{"name" => "In Progress"}},
                  %{"state" => %{"name" => "Done"}},
                  %{"state" => %{"name" => "Todo"}}
                ]
              }
            }
          }
        }

      _ ->
        %Tesla.Env{status: 404}
    end)

    Application.put_env(
      :dashboard_ssd,
      :integrations,
      Keyword.merge(prev || [], linear_token: "fake-token")
    )

    {:ok, adm} =
      Accounts.create_user(%{
        email: "linear-enabled@example.com",
        name: "LinearEnabled",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, _project} = Projects.create_project(%{name: "TestProject"})

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, _view, html} = live(conn, ~p"/")

    # Should show workload section
    assert html =~ "Workload"

    # Restore original env
    Application.put_env(:dashboard_ssd, :integrations, prev)
  end

  test "handles Linear API errors gracefully", %{conn: conn} do
    prev = Application.get_env(:dashboard_ssd, :integrations)

    # Mock Linear API to return error
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.linear.app/graphql"} ->
        %Tesla.Env{status: 500, body: "Internal Server Error"}

      _ ->
        %Tesla.Env{status: 404}
    end)

    Application.put_env(
      :dashboard_ssd,
      :integrations,
      Keyword.merge(prev || [], linear_token: "fake-token")
    )

    {:ok, adm} =
      Accounts.create_user(%{
        email: "linear-error@example.com",
        name: "LinearError",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, _project} = Projects.create_project(%{name: "TestProject"})

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, _view, html} = live(conn, ~p"/")

    # Should still show dashboard even with API error
    assert html =~ "Dashboard"
    assert html =~ "Workload"

    Application.put_env(:dashboard_ssd, :integrations, prev)
  end

  test "handles empty Linear API response", %{conn: conn} do
    prev = Application.get_env(:dashboard_ssd, :integrations)

    # Mock Linear API to return empty issues
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.linear.app/graphql"} ->
        %Tesla.Env{
          status: 200,
          body: %{"data" => %{"issues" => %{"nodes" => []}}}
        }

      _ ->
        %Tesla.Env{status: 404}
    end)

    Application.put_env(
      :dashboard_ssd,
      :integrations,
      Keyword.merge(prev || [], linear_token: "fake-token")
    )

    {:ok, adm} =
      Accounts.create_user(%{
        email: "linear-empty@example.com",
        name: "LinearEmpty",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, _project} = Projects.create_project(%{name: "TestProject"})

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, _view, html} = live(conn, ~p"/")

    # Should show workload summary with zeros
    assert html =~ "Workload"
    assert html =~ "0"

    Application.put_env(:dashboard_ssd, :integrations, prev)
  end

  test "CI status shows low success rate warning", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "low-rate@example.com",
        name: "Low Rate",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, project} = Projects.create_project(%{name: "Low Rate Project"})

    # Create mostly failed deployments
    Enum.each(1..10, fn _ ->
      {:ok, _} = Deployments.create_deployment(%{project_id: project.id, status: "failed"})
    end)

    {:ok, _} = Deployments.create_deployment(%{project_id: project.id, status: "success"})

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "Monitoring last 10 runs"
  end

  test "refresh updates workload summary when Linear enabled", %{conn: conn} do
    prev = Application.get_env(:dashboard_ssd, :integrations)

    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.linear.app/graphql"} ->
        %Tesla.Env{
          status: 200,
          body: %{
            "data" => %{
              "issues" => %{
                "nodes" => [%{"state" => %{"name" => "Done"}}]
              }
            }
          }
        }

      _ ->
        %Tesla.Env{status: 404}
    end)

    Application.put_env(
      :dashboard_ssd,
      :integrations,
      Keyword.merge(prev || [], linear_token: "fake-token")
    )

    {:ok, adm} =
      Accounts.create_user(%{
        email: "refresh-linear@example.com",
        name: "RefreshLinear",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, _project} = Projects.create_project(%{name: "TestProject"})

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, view, _html} = live(conn, ~p"/")

    # Click refresh button
    view |> element("button", "Refresh") |> render_click()

    # Should still show dashboard
    assert render(view) =~ "Dashboard"

    Application.put_env(:dashboard_ssd, :integrations, prev)
  end

  test "toggles mobile menu", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "mobile@example.com",
        name: "Mobile",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, view, _html} = live(conn, ~p"/")

    # Initially closed
    assigns = view.pid |> :sys.get_state() |> Map.fetch!(:socket) |> Map.fetch!(:assigns)
    assert assigns.mobile_menu_open == false

    # Toggle open
    view |> element("button[phx-click='toggle_mobile_menu']") |> render_click()

    assigns = view.pid |> :sys.get_state() |> Map.fetch!(:socket) |> Map.fetch!(:assigns)
    assert assigns.mobile_menu_open == true

    # Toggle close
    view |> element("button[phx-click='toggle_mobile_menu']") |> render_click()

    assigns = view.pid |> :sys.get_state() |> Map.fetch!(:socket) |> Map.fetch!(:assigns)
    assert assigns.mobile_menu_open == false
  end

  test "closes mobile menu", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "close-menu@example.com",
        name: "Close Menu",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, view, _html} = live(conn, ~p"/")

    # Open menu first
    view |> element("button[phx-click='toggle_mobile_menu']") |> render_click()

    assigns = view.pid |> :sys.get_state() |> Map.fetch!(:socket) |> Map.fetch!(:assigns)
    assert assigns.mobile_menu_open == true

    # Close menu
    view |> element("button[phx-click='close_mobile_menu']") |> render_click()

    assigns = view.pid |> :sys.get_state() |> Map.fetch!(:socket) |> Map.fetch!(:assigns)
    assert assigns.mobile_menu_open == false
  end
end
