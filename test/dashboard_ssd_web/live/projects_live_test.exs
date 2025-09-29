defmodule DashboardSSDWeb.ProjectsLiveTest do
  use DashboardSSDWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts
  alias DashboardSSD.Clients
  alias DashboardSSD.Projects

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
        email: "adm@example.com",
        name: "A",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, c} = Clients.create_client(%{name: "Acme"})
    {:ok, _} = Projects.create_project(%{name: "Website", client_id: c.id})

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, _view, html} = live(conn, ~p"/projects")

    assert html =~ "Projects"
    assert html =~ "Website"
    assert html =~ "Acme"
    # Linear disabled in setup; should show N/A instead of totals
    assert html =~ "N/A"
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
        email: "adm@example.com",
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

  test "edit modal opens and saves project", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "adm@example.com",
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
        email: "emp2@example.com",
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
end
