defmodule DashboardSSDWeb.SharedDocumentControllerTest do
  use DashboardSSDWeb.ConnCase, async: false

  alias DashboardSSD.Accounts
  alias DashboardSSD.Cache.SharedDocumentsCache
  alias DashboardSSD.Clients
  alias DashboardSSD.Documents.DocumentAccessLog
  alias DashboardSSD.Documents.SharedDocument
  alias DashboardSSD.Projects.Project
  alias DashboardSSD.Repo

  defmodule NotionRendererStub do
    @behaviour DashboardSSD.Documents.NotionRenderer.RendererBehaviour

    @impl true
    def render_html(_page_id, _opts), do: {:ok, "<p>stub</p>"}

    @impl true
    def render_download(page_id, _opts) do
      {:ok,
       %{data: "#{page_id}-payload", mime_type: "application/pdf", filename: "Workspace.pdf"}}
    end
  end

  defmodule NotionRendererLargeStub do
    @behaviour DashboardSSD.Documents.NotionRenderer.RendererBehaviour

    @impl true
    def render_html(_page_id, _opts), do: {:ok, "<p>large</p>"}

    @impl true
    def render_download(page_id, _opts) do
      large_payload = :binary.copy("a", 26 * 1024 * 1024)
      {:ok, %{data: large_payload, mime_type: "application/pdf", filename: "#{page_id}.pdf"}}
    end
  end

  setup do
    Accounts.ensure_role!("client")

    Tesla.Mock.mock(fn _ ->
      %Tesla.Env{status: 200, body: "bin", headers: [{"content-type", "application/pdf"}]}
    end)

    Application.put_env(:dashboard_ssd, :integrations, drive_token: "drive-token")
    on_exit(fn -> Application.delete_env(:dashboard_ssd, :integrations) end)
    SharedDocumentsCache.invalidate_download(:all)

    previous_renderer = Application.get_env(:dashboard_ssd, :notion_renderer)

    on_exit(fn ->
      if is_nil(previous_renderer) do
        Application.delete_env(:dashboard_ssd, :notion_renderer)
      else
        Application.put_env(:dashboard_ssd, :notion_renderer, previous_renderer)
      end
    end)

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

  test "client downloads notion document", %{conn: conn} do
    Application.put_env(:dashboard_ssd, :notion_renderer, NotionRendererStub)

    {:ok, client} = Clients.create_client(%{name: "Acme"})

    doc =
      insert_document(client.id, nil, source: :notion, source_id: "page-123", title: "Runbook")

    {:ok, user} =
      Accounts.create_user(%{
        email: "client-notion@example.com",
        role_id: Accounts.ensure_role!("client").id,
        client_id: client.id
      })

    conn = init_test_session(conn, %{user_id: user.id})
    conn = post(conn, ~p"/shared_documents/#{doc.id}/download")

    assert conn.status == 200
    [disposition] = get_resp_header(conn, "content-disposition")
    assert disposition =~ "Workspace.pdf"
  end

  test "oversized notion downloads show friendly message", %{conn: conn} do
    Application.put_env(:dashboard_ssd, :notion_renderer, NotionRendererLargeStub)

    {:ok, client} = Clients.create_client(%{name: "Acme"})

    doc =
      insert_document(client.id, nil,
        source: :notion,
        source_id: "page-large",
        title: "Large Doc"
      )

    {:ok, user} =
      Accounts.create_user(%{
        email: "client-notion-oversized@example.com",
        role_id: Accounts.ensure_role!("client").id,
        client_id: client.id
      })

    conn = init_test_session(conn, %{user_id: user.id})
    conn = post(conn, ~p"/shared_documents/#{doc.id}/download")

    assert redirected_to(conn) == "/clients/contracts"
    conn = Phoenix.Controller.fetch_flash(conn)
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "View it in Notion instead"
  end

  defp insert_document(client_id, project_id, attrs \\ %{}) do
    attrs = Map.new(attrs)

    params = %{
      client_id: client_id,
      project_id: project_id,
      source: Map.get(attrs, :source, :drive),
      source_id: Map.get(attrs, :source_id, Ecto.UUID.generate()),
      doc_type: Map.get(attrs, :doc_type, "sow"),
      title: Map.get(attrs, :title, "Downloadable"),
      visibility: Map.get(attrs, :visibility, :client),
      mime_type: Map.get(attrs, :mime_type)
    }

    {:ok, doc} = %SharedDocument{} |> SharedDocument.changeset(params) |> Repo.insert()
    doc
  end
end
