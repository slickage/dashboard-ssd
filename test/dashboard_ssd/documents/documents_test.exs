defmodule DashboardSSD.DocumentsTest do
  use DashboardSSD.DataCase, async: false

  alias DashboardSSD.Accounts.User
  alias DashboardSSD.Cache.SharedDocumentsCache
  alias DashboardSSD.Clients.Client
  alias DashboardSSD.Documents
  alias DashboardSSD.Documents.DocumentAccessLog
  alias DashboardSSD.Documents.SharedDocument
  alias DashboardSSD.Projects.Project

  setup do
    SharedDocumentsCache.invalidate_listing(:all)

    original_blueprint =
      Application.get_env(:dashboard_ssd, DashboardSSD.Documents.WorkspaceBlueprint)

    on_exit(fn ->
      if is_nil(original_blueprint) do
        Application.delete_env(:dashboard_ssd, DashboardSSD.Documents.WorkspaceBlueprint)
      else
        Application.put_env(
          :dashboard_ssd,
          DashboardSSD.Documents.WorkspaceBlueprint,
          original_blueprint
        )
      end
    end)

    :ok
  end

  test "list_client_documents returns only client-visible docs" do
    client = Repo.insert!(%Client{name: "Acme"})
    other_client = Repo.insert!(%Client{name: "Other"})
    project = Repo.insert!(%Project{name: "Proj", client_id: client.id})

    doc = insert_document(%{client_id: client.id, project_id: project.id, visibility: :client})
    insert_document(%{client_id: client.id, visibility: :internal})
    insert_document(%{client_id: other_client.id, visibility: :client})

    user = Repo.insert!(%User{email: "client@acme.com", client_id: client.id})

    assert {:ok, docs} = Documents.list_client_documents(user, project_id: project.id)
    assert Enum.map(docs, & &1.id) == [doc.id]
  end

  test "list_client_documents includes client-wide docs when filtering by project" do
    client = Repo.insert!(%Client{name: "Acme"})
    project = Repo.insert!(%Project{name: "Proj", client_id: client.id})

    doc_project =
      insert_document(%{client_id: client.id, project_id: project.id, visibility: :client})

    doc_global =
      insert_document(%{client_id: client.id, project_id: nil, visibility: :client})

    user = Repo.insert!(%User{email: "client2@acme.com", client_id: client.id})

    assert {:ok, docs} = Documents.list_client_documents(user, project_id: project.id)
    ids = Enum.map(docs, & &1.id) |> Enum.sort()
    assert ids == Enum.sort([doc_project.id, doc_global.id])
  end

  test "returns error when client scope missing" do
    user = %User{id: 10, client_id: nil}
    assert {:error, :client_scope_missing} = Documents.list_client_documents(user, [])
  end

  test "download descriptor returns basic metadata" do
    doc = insert_document(%{})
    descriptor = Documents.download_descriptor(doc)
    assert descriptor.source == :drive
    assert descriptor.source_id == doc.source_id
  end

  test "log_access inserts DocumentAccessLog entry" do
    doc = insert_document(%{})
    user = Repo.insert!(%User{email: "logger@example.com"})
    assert {:ok, _} = Documents.log_access(doc, user, :download, %{source: "drive"})

    assert Repo.aggregate(DocumentAccessLog, :count, :id) == 1
  end

  test "list_staff_documents returns documents with preloads" do
    client = Repo.insert!(%Client{name: "Acme"})
    project = Repo.insert!(%Project{name: "Proj", client_id: client.id})
    insert_document(%{client_id: client.id, project_id: project.id, title: "Doc"})

    docs = Documents.list_staff_documents()
    assert length(docs) == 1
    assert hd(docs).client.name == "Acme"
  end

  test "list_staff_documents filters by client id" do
    client = Repo.insert!(%Client{name: "Acme"})
    other = Repo.insert!(%Client{name: "Other"})
    project = Repo.insert!(%Project{name: "Proj", client_id: client.id})
    other_project = Repo.insert!(%Project{name: "Other", client_id: other.id})

    insert_document(%{client_id: client.id, project_id: project.id, title: "Primary"})
    insert_document(%{client_id: other.id, project_id: other_project.id, title: "Secondary"})

    docs = Documents.list_staff_documents(client_id: client.id)
    assert Enum.map(docs, & &1.title) == ["Primary"]
  end

  test "update_document_settings toggles visibility" do
    client = Repo.insert!(%Client{name: "Acme"})

    project =
      Repo.insert!(%Project{name: "Proj", client_id: client.id, drive_folder_id: "folder"})

    doc = insert_document(%{client_id: client.id, project_id: project.id, visibility: :internal})
    user = Repo.insert!(%User{email: "staff@example.com"})

    assert {:ok, updated} =
             Documents.update_document_settings(doc, %{visibility: :client}, user)

    assert updated.visibility == :client
    assert Repo.aggregate(DocumentAccessLog, :count, :id) == 1
  end

  test "fetch_client_document enforces client scoping" do
    client = Repo.insert!(%Client{name: "Acme"})
    other_client = Repo.insert!(%Client{name: "Other"})

    project =
      Repo.insert!(%Project{name: "Proj", client_id: client.id, drive_folder_id: "folder"})

    doc = insert_document(%{client_id: client.id, project_id: project.id})

    user = Repo.insert!(%User{email: "client@acme.com", client_id: client.id})

    assert {:ok, %SharedDocument{} = fetched} =
             Documents.fetch_client_document(user, doc.id)

    assert fetched.id == doc.id

    unauthorized =
      Repo.insert!(%User{email: "client-other@example.com", client_id: other_client.id})

    assert {:error, :not_found} = Documents.fetch_client_document(unauthorized, doc.id)

    scope_missing = Repo.insert!(%User{email: "client-missing@example.com", client_id: nil})

    assert {:error, :client_scope_missing} =
             Documents.fetch_client_document(scope_missing, doc.id)
  end

  test "log_access returns error for invalid document input" do
    user = Repo.insert!(%User{email: "invalid@example.com"})
    assert {:error, :invalid_document} = Documents.log_access(%{}, user, :download, %{})
  end

  test "workspace_section_options filters enabled sections" do
    Application.put_env(:dashboard_ssd, DashboardSSD.Documents.WorkspaceBlueprint, %{
      sections: [
        %{id: :drive_contracts, enabled?: true},
        %{id: :notion_runbook, enabled?: false}
      ]
    })

    assert [%{id: :drive_contracts}] = Documents.workspace_section_options()
  end

  test "workspace_section_options returns empty list when blueprint missing" do
    Application.delete_env(:dashboard_ssd, DashboardSSD.Documents.WorkspaceBlueprint)
    assert [] == Documents.workspace_section_options()
  end

  test "bootstrap_workspace delegates to configured module" do
    project = %Project{id: 999, name: "Bootstrap"}

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

    assert :ok = Documents.bootstrap_workspace(project, sections: [:drive_contracts])
    assert_receive {:workspace_bootstrap, 999, [:drive_contracts]}, 1_000
  end

  defp insert_document(attrs) do
    base = %{
      client_id: attrs[:client_id] || Repo.insert!(%Client{name: "Default"}).id,
      project_id: attrs[:project_id],
      source: :drive,
      source_id: Ecto.UUID.generate(),
      doc_type: "sow",
      title: Map.get(attrs, :title, "Doc"),
      visibility: Map.get(attrs, :visibility, :client)
    }

    {:ok, record} =
      %SharedDocument{}
      |> SharedDocument.changeset(base)
      |> Repo.insert()

    record
  end
end
