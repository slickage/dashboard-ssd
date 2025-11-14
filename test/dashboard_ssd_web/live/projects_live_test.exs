defmodule DashboardSSDWeb.ProjectsLiveTest do
  use DashboardSSDWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts
  alias DashboardSSD.Auth.Capabilities
  alias DashboardSSD.Clients
  alias DashboardSSD.Projects
  alias DashboardSSD.Projects.LinearTeamMember
  alias DashboardSSD.Repo

  setup do
    Tesla.Mock.mock(fn
      %{method: :get, url: "https://api.linear.app/graphql"} ->
        %Tesla.Env{status: 200, body: %{"data" => %{"issues" => %{"nodes" => []}}}}

      _ ->
        %Tesla.Env{status: 404}
    end)

    :ok
  end

  setup do
    Accounts.ensure_role!("admin")
    Accounts.ensure_role!("employee")

    Capabilities.default_assignments()
    |> Enum.each(fn {role, caps} ->
      Accounts.ensure_role!(role)
      Accounts.replace_role_capabilities(role, caps, granted_by_id: nil)
    end)

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

    :ok
  end

  test "admin sees projects list", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "adm@slickage.com",
        name: "A",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, c} = Clients.create_client(%{name: "Acme"})

    {:ok, _} =
      Projects.create_project(%{
        name: "Website",
        client_id: c.id,
        linear_team_id: "team-1",
        linear_team_name: "Platform"
      })

    Repo.insert!(%LinearTeamMember{
      linear_team_id: "team-1",
      linear_user_id: "user-1",
      name: "Alice",
      display_name: "Alice Example"
    })

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, _view, html} = live(conn, ~p"/projects")

    assert html =~ "Projects"
    assert html =~ "Website"
    assert html =~ "Acme"
    assert html =~ "Platform"
    assert html =~ "Alice Example"
    assert html =~ ~s/data-team-name="Platform"/
    # Linear disabled in setup; should show N/A instead of totals
    assert html =~ "N/A"
  end

  test "admin can collapse and expand a team group", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "adm-team-toggle@example.com",
        name: "A",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, c} = Clients.create_client(%{name: "Acme"})

    {:ok, _} =
      Projects.create_project(%{
        name: "Website",
        client_id: c.id,
        linear_team_id: "team-1",
        linear_team_name: "Platform"
      })

    Repo.insert!(%LinearTeamMember{
      linear_team_id: "team-1",
      linear_user_id: "user-2",
      name: "Bob",
      display_name: "Bob Example"
    })

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, view, _html} = live(conn, ~p"/projects")

    assert render(view) =~ "Website"
    assert render(view) =~ "Bob Example"

    view |> element(~s(button[data-team-name="Platform"])) |> render_click()
    refute render(view) =~ "Website"

    view |> element(~s(button[data-team-name="Platform"])) |> render_click()
    assert render(view) =~ "Website"
  end

  test "initial load with no projects shows empty state", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "adm-empty@example.com",
        name: "A",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, _view, html} = live(conn, ~p"/projects")
    assert html =~ "No projects found"
  end

  test "anonymous is redirected to auth", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/login?redirect_to=%2Fprojects"}}} =
             live(conn, ~p"/projects")
  end

  test "filter by client from dropdown updates view and URL", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "adm@slickage.com",
        name: "A",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, c1} = Clients.create_client(%{name: "Acme"})
    {:ok, c2} = Clients.create_client(%{name: "Globex"})
    {:ok, _} = Projects.create_project(%{name: "Website", client_id: c1.id})
    {:ok, _} = Projects.create_project(%{name: "Mobile App", client_id: c2.id})

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, view, _html} = live(conn, ~p"/projects")

    # change dropdown to c1
    assert view
           |> element("#client-filter-form")
           |> render_change(%{"client_id" => to_string(c1.id)})

    assert_patch(view, ~p"/projects?client_id=#{c1.id}")
    html = render(view)
    assert html =~ "Website"
    refute html =~ "Mobile App"
    # Switch back to All Clients
    assert view
           |> element("#client-filter-form")
           |> render_change(%{"client_id" => ""})

    assert_patch(view, ~p"/projects")
    html2 = render(view)
    assert html2 =~ "Website"
    assert html2 =~ "Mobile App"
  end

  test "client sees only their assigned projects", %{conn: conn} do
    client_role = Accounts.ensure_role!("client")
    {:ok, c1} = Clients.create_client(%{name: "Acme"})
    {:ok, c2} = Clients.create_client(%{name: "Globex"})

    {:ok, _} = Projects.create_project(%{name: "Website", client_id: c1.id})
    {:ok, _} = Projects.create_project(%{name: "Mobile App", client_id: c2.id})

    {:ok, client_user} =
      Accounts.create_user(%{
        email: "client-1@slickage.com",
        name: "Client User",
        role_id: client_role.id,
        client_id: c1.id
      })

    conn = init_test_session(conn, %{user_id: client_user.id})
    {:ok, _view, html} = live(conn, ~p"/projects")

    assert html =~ "Website"
    assert html =~ "Acme"
    refute html =~ "Mobile App"
    refute html =~ "Globex"
    refute html =~ "Filter by client"
  end

  test "admin sees edit actions column", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "adm-actions@example.com",
        name: "Admin",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, client} = Clients.create_client(%{name: "Acme"})

    {:ok, project} =
      Projects.create_project(%{
        name: "Website",
        client_id: client.id
      })

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, _view, html} = live(conn, ~p"/projects")

    assert html =~ "Actions"
    assert html =~ ~p"/projects/#{project.id}/edit"
  end

  test "employee without manage capability cannot see edit actions", %{conn: conn} do
    employee_role = Accounts.ensure_role!("employee")

    {:ok, employee} =
      Accounts.create_user(%{
        email: "employee-no-manage@example.com",
        name: "Employee",
        role_id: employee_role.id
      })

    {:ok, client} = Clients.create_client(%{name: "Acme"})

    {:ok, project} =
      Projects.create_project(%{
        name: "Website",
        client_id: client.id,
        linear_team_id: "team-1",
        linear_team_name: "Platform"
      })

    conn = init_test_session(conn, %{user_id: employee.id})

    {:ok, _view, html} = live(conn, ~p"/projects")

    assert html =~ "Website"
    refute html =~ "Actions"
    refute html =~ ~p"/projects/#{project.id}/edit"
  end

  test "edit modal opens and saves project", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "adm@slickage.com",
        name: "A",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, c1} = Clients.create_client(%{name: "Acme"})
    {:ok, c2} = Clients.create_client(%{name: "Globex"})
    {:ok, p} = Projects.create_project(%{name: "Legacy", client_id: c1.id})

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, _view, _} = live(conn, ~p"/projects")

    {:ok, view, _html} = live(conn, ~p"/projects/#{p.id}/edit")
    form = element(view, "#project-form")
    render_change(form, %{"project" => %{"name" => "Rebranded", "client_id" => to_string(c2.id)}})
    render_submit(form, %{"project" => %{"name" => "Rebranded", "client_id" => to_string(c2.id)}})

    # Modal should close and project should be updated in place
    html = render(view)
    assert html =~ "Rebranded"
    assert html =~ "Globex"
    # Modal should be closed
    refute html =~ "Edit Project"
  end

  test "edit modal forbids non-admin", %{conn: conn} do
    {:ok, emp} =
      Accounts.create_user(%{
        email: "emp2@slickage.com",
        name: "E2",
        role_id: Accounts.ensure_role!("employee").id
      })

    {:ok, c} = Clients.create_client(%{name: "Acme"})
    {:ok, p} = Projects.create_project(%{name: "Legacy", client_id: c.id})

    conn = init_test_session(conn, %{user_id: emp.id})
    {:ok, view, _html} = live(conn, ~p"/projects/#{p.id}/edit")
    form = element(view, "#project-form")
    _html_before = render(view)
    render_submit(form, %{"project" => %{"name" => "Nope"}})
    html_after = render(view)
    # Should stay on edit modal (no patch back) and not change name
    assert html_after =~ "Edit Project"
  end

  test "unassign client via edit modal shows Assign Client", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "adm4@example.com",
        name: "A4",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, c} = Clients.create_client(%{name: "Acme"})
    {:ok, p} = Projects.create_project(%{name: "Legacy", client_id: c.id})

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, _view, _} = live(conn, ~p"/projects")
    {:ok, view, _} = live(conn, ~p"/projects/#{p.id}/edit")
    form = element(view, "#project-form")
    render_submit(form, %{"project" => %{"name" => "Legacy", "client_id" => ""}})
    # Modal should close and project should be updated in place
    html = render(view)
    assert html =~ "Assign Client"
    # Modal should be closed
    refute html =~ "Edit Project"
  end

  test "validation error on missing name stays on modal", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "adm5@example.com",
        name: "A5",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, p} = Projects.create_project(%{name: "P", client_id: nil})

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, view, _} = live(conn, ~p"/projects/#{p.id}/edit")
    form = element(view, "#project-form")
    render_submit(form, %{"project" => %{"name" => ""}})
    html = render(view)
    assert html =~ "can&#39;t be blank"
    assert html =~ "Edit Project"
  end

  test "modal cancel path without client_id uses /projects", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "adm6@example.com",
        name: "A6",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, p} = Projects.create_project(%{name: "Solo"})
    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, view, _} = live(conn, ~p"/projects/#{p.id}/edit")
    _ = render_patch(view, ~p"/projects")
    html = render(view)
    assert html =~ "Projects"
    assert html =~ "Solo"
  end

  test "cached reuse path on closing modal (no recompute) and forced refresh with r=1", %{
    conn: conn
  } do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "adm3@example.com",
        name: "A3",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, c} = Clients.create_client(%{name: "Acme"})
    {:ok, p} = Projects.create_project(%{name: "Legacy", client_id: c.id})

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, view, _} = live(conn, ~p"/projects?client_id=#{c.id}")

    # Open modal and simulate closing via patch back to same filter → cached reuse path
    {:ok, view2, _} = live(conn, ~p"/projects/#{p.id}/edit")
    _ = render_patch(view2, ~p"/projects?client_id=#{c.id}")
    html = render(view)
    assert html =~ "Legacy"

    # Force refresh with r=1 (simulate by patching URL)
    _ = render_patch(view, ~p"/projects?client_id=#{c.id}&r=1")
    html2 = render(view)
    assert html2 =~ "Legacy"
  end

  test "project_updated message refreshes project list when changes detected", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "adm-refresh@example.com",
        name: "Manager",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, client} = Clients.create_client(%{name: "Acme"})
    {:ok, project} = Projects.create_project(%{name: "Legacy", client_id: client.id})

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, view, html} = live(conn, ~p"/projects")
    assert html =~ "Legacy"

    {:ok, _updated} = Projects.update_project(project, %{name: "Rebuilt"})

    send(view.pid, {:project_updated, project, "Project saved", true})
    assert_patch(view, ~p"/projects")
    html_after = render(view)

    assert html_after =~ "Rebuilt"
    assert html_after =~ "Project saved"
  end

  test "project_updated message without changes keeps existing list", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "adm-nochange@example.com",
        name: "Manager",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, client} = Clients.create_client(%{name: "Acme"})
    {:ok, project} = Projects.create_project(%{name: "Stable", client_id: client.id})

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, view, html} = live(conn, ~p"/projects")
    assert html =~ "Stable"

    send(view.pid, {:project_updated, project, "No changes", false})
    assert_patch(view, ~p"/projects")
    html_after = render(view)

    assert html_after =~ "Stable"
    assert html_after =~ "No changes"
  end
end
