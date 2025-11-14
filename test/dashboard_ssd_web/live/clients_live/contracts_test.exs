defmodule DashboardSSDWeb.ClientsLive.ContractsTest do
  use DashboardSSDWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts
  alias DashboardSSD.Clients
  alias DashboardSSD.Documents.SharedDocument
  alias DashboardSSD.Projects.Project
  alias DashboardSSD.Cache.SharedDocumentsCache
  alias DashboardSSD.Repo

  setup do
    Accounts.ensure_role!("client")
    SharedDocumentsCache.invalidate_listing(:all)
    :ok
  end

  test "client sees documents list", %{conn: conn} do
    {:ok, client} = Clients.create_client(%{name: "Acme"})
    {:ok, project} = Repo.insert(%Project{name: "Proj", client_id: client.id})
    doc = insert_document(client.id, project.id, title: "SOW 1")

    {:ok, user} =
      Accounts.create_user(%{
        email: "client@example.com",
        name: "Client",
        role_id: Accounts.ensure_role!("client").id,
        client_id: client.id
      })

    conn = init_test_session(conn, %{user_id: user.id})
    {:ok, _view, html} = live(conn, ~p"/clients/contracts")

    assert html =~ "Contracts &amp; Docs"
    assert html =~ doc.title
  end

  test "client can filter by project", %{conn: conn} do
    {:ok, client} = Clients.create_client(%{name: "Acme"})
    {:ok, project_a} = Repo.insert(%Project{name: "A", client_id: client.id})
    {:ok, project_b} = Repo.insert(%Project{name: "B", client_id: client.id})

    insert_document(client.id, project_a.id, title: "Doc A")
    insert_document(client.id, project_b.id, title: "Doc B")

    {:ok, user} =
      Accounts.create_user(%{
        email: "client-filter@example.com",
        role_id: Accounts.ensure_role!("client").id,
        client_id: client.id
      })

    conn = init_test_session(conn, %{user_id: user.id})
    {:ok, _view, html} = live(conn, ~p"/clients/contracts?project_id=#{project_b.id}")
    assert html =~ "Doc B"
    refute html =~ "Doc A"
  end

  test "client without assignment sees warning", %{conn: conn} do
    {:ok, user} =
      Accounts.create_user(%{
        email: "client-unassigned@example.com",
        role_id: Accounts.ensure_role!("client").id
      })

    conn = init_test_session(conn, %{user_id: user.id})
    {:ok, _view, html} = live(conn, ~p"/clients/contracts")
    assert html =~ "not linked to a client"
  end

  test "non-client is redirected", %{conn: conn} do
    Accounts.ensure_role!("employee")

    {:ok, emp} =
      Accounts.create_user(%{
        email: "emp@example.com",
        role_id: Accounts.ensure_role!("employee").id
      })

    conn = init_test_session(conn, %{user_id: emp.id})
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/clients/contracts")
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

    {:ok, doc} = %SharedDocument{} |> SharedDocument.changeset(params) |> Repo.insert()
    doc
  end
end
