defmodule DashboardSSDWeb.SharedDocumentControllerTest do
  use DashboardSSDWeb.ConnCase, async: true

  alias DashboardSSD.Accounts
  alias DashboardSSD.Cache.SharedDocumentsCache
  alias DashboardSSD.Clients
  alias DashboardSSD.Documents.DocumentAccessLog
  alias DashboardSSD.Documents.SharedDocument
  alias DashboardSSD.Projects.Project
  alias DashboardSSD.Repo

  setup do
    Accounts.ensure_role!("client")

    Tesla.Mock.mock(fn _ ->
      %Tesla.Env{status: 200, body: "bin", headers: [{"content-type", "application/pdf"}]}
    end)

    Application.put_env(:dashboard_ssd, :integrations, drive_token: "drive-token")
    on_exit(fn -> Application.delete_env(:dashboard_ssd, :integrations) end)
    SharedDocumentsCache.invalidate_download(:all)
    :ok
  end

  test "client downloads drive document", %{conn: conn} do
    {:ok, client} = Clients.create_client(%{name: "Acme"})
    {:ok, project} = Repo.insert(%Project{name: "Proj", client_id: client.id})
    doc = insert_document(client.id, project.id)

    {:ok, user} =
      Accounts.create_user(%{
        email: "client@example.com",
        role_id: Accounts.ensure_role!("client").id,
        client_id: client.id
      })

    conn = init_test_session(conn, %{user_id: user.id})

    conn = post(conn, ~p"/shared_documents/#{doc.id}/download")

    assert conn.status == 200
    assert get_resp_header(conn, "content-disposition") != []
    assert Repo.aggregate(DocumentAccessLog, :count, :id) == 1
  end

  test "client without assignment is redirected", %{conn: conn} do
    {:ok, client} = Clients.create_client(%{name: "Acme"})
    {:ok, project} = Repo.insert(%Project{name: "Proj", client_id: client.id})
    doc = insert_document(client.id, project.id)

    {:ok, user} =
      Accounts.create_user(%{
        email: "client-unlinked@example.com",
        role_id: Accounts.ensure_role!("client").id
      })

    conn = init_test_session(conn, %{user_id: user.id})
    conn = post(conn, ~p"/shared_documents/#{doc.id}/download")

    assert redirected_to(conn) == "/clients"
    conn = Phoenix.Controller.fetch_flash(conn)
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not linked to a client"
  end

  test "missing document returns 404", %{conn: conn} do
    {:ok, client} = Clients.create_client(%{name: "Acme"})

    {:ok, user} =
      Accounts.create_user(%{
        email: "client-missing@example.com",
        role_id: Accounts.ensure_role!("client").id,
        client_id: client.id
      })

    conn = init_test_session(conn, %{user_id: user.id})
    conn = post(conn, ~p"/shared_documents/#{Ecto.UUID.generate()}/download")
    assert conn.status == 404
  end

  test "drive download failure shows friendly message", %{conn: conn} do
    {:ok, client} = Clients.create_client(%{name: "Acme"})
    {:ok, project} = Repo.insert(%Project{name: "Proj", client_id: client.id})
    doc = insert_document(client.id, project.id)

    {:ok, user} =
      Accounts.create_user(%{
        email: "client-failure@example.com",
        role_id: Accounts.ensure_role!("client").id,
        client_id: client.id
      })

    Tesla.Mock.mock(fn _ -> {:error, :boom} end)

    conn = init_test_session(conn, %{user_id: user.id})
    conn = post(conn, ~p"/shared_documents/#{doc.id}/download")

    assert redirected_to(conn) == "/clients/contracts"
    conn = Phoenix.Controller.fetch_flash(conn)
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "couldn't download"
  end

  test "employee is redirected", %{conn: conn} do
    Accounts.ensure_role!("employee")

    {:ok, employee} =
      Accounts.create_user(%{
        email: "emp@example.com",
        role_id: Accounts.ensure_role!("employee").id
      })

    conn = init_test_session(conn, %{user_id: employee.id})
    conn = post(conn, ~p"/shared_documents/#{Ecto.UUID.generate()}/download")

    assert redirected_to(conn) == "/clients/contracts"
  end

  test "oversized drive download shows friendly message", %{conn: conn} do
    Tesla.Mock.mock(fn _ ->
      %Tesla.Env{
        status: 200,
        body: :binary.copy("a", 100),
        headers: [
          {"content-type", "application/pdf"},
          {"content-length", "30000000"}
        ]
      }
    end)

    {:ok, client} = Clients.create_client(%{name: "Acme"})
    {:ok, project} = Repo.insert(%Project{name: "Proj", client_id: client.id})
    doc = insert_document(client.id, project.id)

    {:ok, user} =
      Accounts.create_user(%{
        email: "client-large@example.com",
        role_id: Accounts.ensure_role!("client").id,
        client_id: client.id
      })

    conn = init_test_session(conn, %{user_id: user.id})
    conn = post(conn, ~p"/shared_documents/#{doc.id}/download")

    assert redirected_to(conn) == "/clients/contracts"
    conn = Phoenix.Controller.fetch_flash(conn)
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Open it directly in Drive"
  end

  test "client cannot download docs from other clients", %{conn: conn} do
    {:ok, client_a} = Clients.create_client(%{name: "A"})
    {:ok, client_b} = Clients.create_client(%{name: "B"})
    {:ok, project} = Repo.insert(%Project{name: "Proj", client_id: client_b.id})
    doc = insert_document(client_b.id, project.id)

    {:ok, user} =
      Accounts.create_user(%{
        email: "client-a@example.com",
        role_id: Accounts.ensure_role!("client").id,
        client_id: client_a.id
      })

    conn = init_test_session(conn, %{user_id: user.id})
    conn = post(conn, ~p"/shared_documents/#{doc.id}/download")
    assert conn.status == 404
  end

  defp insert_document(client_id, project_id) do
    params = %{
      client_id: client_id,
      project_id: project_id,
      source: :drive,
      source_id: Ecto.UUID.generate(),
      doc_type: "sow",
      title: "Downloadable",
      visibility: :client
    }

    {:ok, doc} = %SharedDocument{} |> SharedDocument.changeset(params) |> Repo.insert()
    doc
  end
end
