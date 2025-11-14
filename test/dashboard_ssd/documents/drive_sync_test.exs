defmodule DashboardSSD.Documents.DriveSyncTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Cache.SharedDocumentsCache
  alias DashboardSSD.Clients.Client
  alias DashboardSSD.Documents.{DriveSync, SharedDocument}
  alias DashboardSSD.Projects.Project
  alias DashboardSSD.Repo

  setup do
    SharedDocumentsCache.invalidate_listing(:all)
    SharedDocumentsCache.invalidate_download(:all)
    :ok
  end

  test "inserts and updates drive documents" do
    client = Repo.insert!(%Client{name: "Acme"})
    project = Repo.insert!(%Project{name: "Proj", client_id: client.id})

    docs = [
      %{
        client_id: client.id,
        project_id: project.id,
        source_id: "file-1",
        title: "Doc 1",
        doc_type: "sow",
        visibility: :client,
        mime_type: "application/pdf"
      },
      %{
        client_id: client.id,
        project_id: project.id,
        source_id: "file-2",
        title: "Doc 2",
        doc_type: "change_order",
        stale?: true
      }
    ]

    assert {:ok, %{inserted: 2, updated: 0}} = DriveSync.sync(docs)
    assert Repo.aggregate(SharedDocument, :count, :id) == 2

    update = [
      %{
        client_id: client.id,
        project_id: project.id,
        source_id: "file-1",
        title: "Doc 1 updated",
        doc_type: "sow"
      }
    ]

    assert {:ok, %{inserted: 0, updated: 1}} = DriveSync.sync(update)
    assert Repo.get_by!(SharedDocument, source_id: "file-1").title == "Doc 1 updated"
  end
end
