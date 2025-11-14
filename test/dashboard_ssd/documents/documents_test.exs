defmodule DashboardSSD.DocumentsTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Accounts.User
  alias DashboardSSD.Cache.SharedDocumentsCache
  alias DashboardSSD.Clients.Client
  alias DashboardSSD.Documents
  alias DashboardSSD.Documents.DocumentAccessLog
  alias DashboardSSD.Documents.SharedDocument
  alias DashboardSSD.Projects.Project

  setup do
    SharedDocumentsCache.invalidate_listing(:all)
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

  defp insert_document(attrs) do
    base = %{
      client_id: attrs[:client_id] || Repo.insert!(%Client{name: "Default"}).id,
      project_id: attrs[:project_id],
      source: :drive,
      source_id: Ecto.UUID.generate(),
      doc_type: "sow",
      title: "Doc",
      visibility: Map.get(attrs, :visibility, :client)
    }

    {:ok, record} =
      %SharedDocument{}
      |> SharedDocument.changeset(base)
      |> Repo.insert()

    record
  end
end
