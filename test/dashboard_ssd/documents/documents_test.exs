defmodule DashboardSSD.DocumentsTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Accounts.User
  alias DashboardSSD.Clients.Client
  alias DashboardSSD.Documents
  alias DashboardSSD.Documents.SharedDocument
  alias DashboardSSD.Projects.Project
  alias DashboardSSD.Cache.SharedDocumentsCache

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
