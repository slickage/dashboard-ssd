defmodule DashboardSSDWeb.AnalyticsLive.IndexTest do
  use DashboardSSDWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias DashboardSSD.{Accounts, Analytics, Clients, Projects}

  setup %{conn: conn} do
    admin_role = Accounts.ensure_role!("admin")
    Accounts.ensure_role!("employee")

    {:ok, client} = Clients.create_client(%{name: "Acme"})
    {:ok, project} = Projects.create_project(%{name: "Proj", client_id: client.id})

    {:ok, admin} =
      Accounts.create_user(%{
        email: "admin-analytics@example.com",
        role_id: admin_role.id
      })

    {:ok, _} = Analytics.create_metric(%{project_id: project.id, type: "uptime", value: 99.5})
    {:ok, _} = Analytics.create_metric(%{project_id: project.id, type: "mttr", value: 10})

    conn = init_test_session(conn, %{user_id: admin.id})

    {:ok, conn: conn, project: project}
  end

  test "authorized user sees analytics dashboard", %{conn: conn, project: project} do
    {:ok, view, html} = live(conn, ~p"/analytics")

    assert html =~ "Analytics"
    assert html =~ project.name

    view |> element("button", "Refresh") |> render_click()

    view |> element("button", "Export CSV") |> render_click()

    assert_push_event(view, "download", %{filename: filename, data: data})
    assert filename =~ "analytics_metrics"
    assert data =~ "uptime"

    view
    |> element("form[phx-change=\"select_project\"]")
    |> render_change(%{"project_id" => ""})
  end

  test "unauthorized user is redirected" do
    Accounts.replace_role_capabilities("employee", [], granted_by_id: nil)

    {:ok, user} =
      Accounts.create_user(%{
        email: "emp-analytics@example.com",
        role_id: Accounts.ensure_role!("employee").id
      })

    conn = init_test_session(Phoenix.ConnTest.build_conn(), %{user_id: user.id})
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/analytics")
  end
end
