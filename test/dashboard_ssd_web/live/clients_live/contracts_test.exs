defmodule DashboardSSDWeb.ClientsLive.ContractsTest do
  use DashboardSSDWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts
  alias DashboardSSD.Cache.SharedDocumentsCache
  alias DashboardSSD.Clients
  alias DashboardSSD.Documents
  alias DashboardSSD.Documents.SharedDocument
  alias DashboardSSD.Projects.Project
  alias DashboardSSD.Repo
  alias DashboardSSDWeb.ClientsLive.Contracts, as: ClientsContractsLive

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

  test "client loses access when document visibility changes", %{conn: conn} do
    {:ok, client} = Clients.create_client(%{name: "Acme"})
    {:ok, project} = Repo.insert(%Project{name: "Proj", client_id: client.id})
    doc = insert_document(client.id, project.id, title: "Doc")

    {:ok, user} =
      Accounts.create_user(%{
        email: "client-visibility@example.com",
        role_id: Accounts.ensure_role!("client").id,
        client_id: client.id
      })

    conn = init_test_session(conn, %{user_id: user.id})
    {:ok, _view, html} = live(conn, ~p"/clients/contracts")
    assert html =~ "Doc"

    {:ok, _} = Documents.update_document_settings(doc, %{visibility: :internal}, nil)

    conn2 = Phoenix.ConnTest.build_conn() |> init_test_session(%{user_id: user.id})
    conn2 = post(conn2, ~p"/shared_documents/#{doc.id}/download")
    assert conn2.status == 404
  end

  test "removing client assignment revokes portal access", %{conn: conn} do
    {:ok, client} = Clients.create_client(%{name: "Acme"})
    {:ok, project} = Repo.insert(%Project{name: "Proj", client_id: client.id})
    doc = insert_document(client.id, project.id, title: "Doc")

    {:ok, user} =
      Accounts.create_user(%{
        email: "client-revoke@example.com",
        role_id: Accounts.ensure_role!("client").id,
        client_id: client.id
      })

    conn = init_test_session(conn, %{user_id: user.id})
    {:ok, _view, html} = live(conn, ~p"/clients/contracts")
    assert html =~ "Doc"

    {:ok, _} = Accounts.update_user_role_and_client(user.id, "client", nil)

    conn2 = Phoenix.ConnTest.build_conn() |> init_test_session(%{user_id: user.id})
    {:ok, _view, html2} = live(conn2, ~p"/clients/contracts")
    assert html2 =~ "not linked to a client"

    conn3 = Phoenix.ConnTest.build_conn() |> init_test_session(%{user_id: user.id})
    conn3 = post(conn3, ~p"/shared_documents/#{doc.id}/download")
    assert redirected_to(conn3) == "/clients"
  end

  describe "clients liveview inline events" do
    test "filter event normalizes project id" do
      socket = base_socket(%{project_id: nil, client_assignment_missing?: true})

      {:noreply, updated} =
        ClientsContractsLive.handle_event("filter", %{"project_id" => "42"}, socket)

      assert updated.assigns.project_id == 42
      assert updated.assigns.documents == []
    end

    test "handle_params clears invalid project id" do
      socket = base_socket(%{project_id: 10, client_assignment_missing?: false})

      {:noreply, updated} =
        ClientsContractsLive.handle_params(%{"project_id" => "abc"}, "", socket)

      assert updated.assigns.project_id == nil
    end

    test "toggle_mobile_menu flips state" do
      socket = base_socket(%{mobile_menu_open: false})

      {:noreply, updated} = ClientsContractsLive.handle_event("toggle_mobile_menu", %{}, socket)
      assert updated.assigns.mobile_menu_open
    end

    test "close_mobile_menu sets state to false" do
      socket = base_socket(%{mobile_menu_open: true})

      {:noreply, updated} = ClientsContractsLive.handle_event("close_mobile_menu", %{}, socket)
      refute updated.assigns.mobile_menu_open
    end
  end

  defp insert_document(client_id, project_id, attrs) do
    attrs = Map.new(attrs)

    params = %{
      client_id: client_id,
      project_id: project_id,
      source: :drive,
      source_id: Ecto.UUID.generate(),
      doc_type: "sow",
      title: attrs[:title] || "Doc",
      visibility: Map.get(attrs, :visibility, :client),
      metadata: Map.get(attrs, :metadata, %{})
    }

    {:ok, doc} =
      %SharedDocument{}
      |> SharedDocument.changeset(params)
      |> Repo.insert()

    doc
  end

  defp base_socket(assigns) do
    %Phoenix.LiveView.Socket{
      endpoint: DashboardSSDWeb.Endpoint,
      view: ClientsContractsLive,
      root_pid: self(),
      transport_pid: self(),
      private: %{live_action: :index},
      assigns:
        %{
          __changed__: %{},
          flash: %{},
          current_user: %{id: 1, client_id: 1},
          client_assignment_missing?: false,
          project_id: nil,
          mobile_menu_open: false,
          documents: [],
          projects: [],
          can_manage_contracts?: false
        }
        |> Map.merge(assigns)
    }
  end
end
