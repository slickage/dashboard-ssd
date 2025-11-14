defmodule DashboardSSDWeb.ProjectsLive.ContractsTest do
  use DashboardSSDWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts
  alias DashboardSSD.Clients
  alias DashboardSSD.Documents.SharedDocument
  alias DashboardSSD.Projects.Project
  alias DashboardSSD.Repo

  setup do
    Accounts.ensure_role!("admin")
    Accounts.ensure_role!("employee")

    Application.put_env(
      :dashboard_ssd,
      :workspace_bootstrap_module,
      DashboardSSD.WorkspaceBootstrapStub
    )

    :persistent_term.put({:workspace_test_pid}, self())

    on_exit(fn ->
      :persistent_term.erase({:workspace_test_pid})
      Application.delete_env(:dashboard_ssd, :workspace_bootstrap_module)
    end)

    :ok
  end

  test "admin sees staff contracts", %{conn: conn} do
    {:ok, client} = Clients.create_client(%{name: "Acme"})
    {:ok, project} = Repo.insert(%Project{name: "Proj", client_id: client.id})
    insert_document(client.id, project.id, title: "SOW")

    {:ok, admin} =
      Accounts.create_user(%{
        email: "admin-contracts@example.com",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = init_test_session(conn, %{user_id: admin.id})
    {:ok, _view, html} = live(conn, ~p"/projects/contracts")
    assert html =~ "Contracts (Staff)"
    assert html =~ "SOW"
  end

  test "employee without contract capability is redirected", %{conn: conn} do
    {:ok, _} =
      Accounts.replace_role_capabilities("employee", [], granted_by_id: nil)

    {:ok, employee} =
      Accounts.create_user(%{
        email: "employee-contracts@example.com",
        role_id: Accounts.ensure_role!("employee").id
      })

    conn = init_test_session(conn, %{user_id: employee.id})
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/projects/contracts")
  end

  test "admin can select sections when regenerating workspace", %{conn: conn} do
    {:ok, client} = Clients.create_client(%{name: "Acme"})

    {:ok, project} =
      Repo.insert(%Project{
        name: "Proj",
        client_id: client.id,
        drive_folder_id: "folder"
      })

    insert_document(client.id, project.id, title: "Doc")

    {:ok, admin} =
      Accounts.create_user(%{
        email: "admin2@example.com",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = init_test_session(conn, %{user_id: admin.id})
    {:ok, view, _html} = live(conn, ~p"/projects/contracts")

    project_id = project.id
    view |> element("button[phx-value-id=\"#{project_id}\"]", "Regenerate") |> render_click()
    assert render(view) =~ "Regenerate workspace for"

    form_params = %{
      "project_id" => "#{project_id}",
      "sections" => ["drive_contracts", "notion_runbook"]
    }

    view |> form("#workspace-bootstrap-form", form_params) |> render_submit()

    assert_receive {:workspace_bootstrap, ^project_id, sections}
    assert sections == [:drive_contracts, :notion_runbook]
  end

  test "regen form requires selecting at least one section", %{conn: conn} do
    {:ok, client} = Clients.create_client(%{name: "Acme"})

    {:ok, project} =
      Repo.insert(%Project{
        name: "Proj",
        client_id: client.id,
        drive_folder_id: "folder"
      })

    insert_document(client.id, project.id, title: "Doc")

    {:ok, admin} =
      Accounts.create_user(%{
        email: "admin3@example.com",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = init_test_session(conn, %{user_id: admin.id})
    {:ok, view, _html} = live(conn, ~p"/projects/contracts")

    project_id = project.id
    view |> element("button[phx-value-id=\"#{project_id}\"]", "Regenerate") |> render_click()

    html =
      view
      |> form("#workspace-bootstrap-form", %{
        "project_id" => "#{project_id}",
        "sections" => []
      })
      |> render_submit()

    assert html =~ "Select at least one section"

    refute_received {:workspace_bootstrap, ^project_id, _}
  end

  defp insert_document(client_id, project_id, attrs) do
    params = %{
      client_id: client_id,
      project_id: project_id,
      source: :drive,
      source_id: Ecto.UUID.generate(),
      doc_type: "sow",
      title: attrs[:title] || "Doc",
      visibility: :client
    }

    %SharedDocument{}
    |> SharedDocument.changeset(params)
    |> Repo.insert!()
  end
end
