defmodule DashboardSSDWeb.ProjectsLive.ContractsTest do
  use DashboardSSDWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts
  alias DashboardSSD.Clients
  alias DashboardSSD.Documents.SharedDocument
  alias DashboardSSD.Projects.Project
  alias DashboardSSD.Repo

  setup do
    Accounts.ensure_role!("admin")
    Accounts.ensure_role!("employee")
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
