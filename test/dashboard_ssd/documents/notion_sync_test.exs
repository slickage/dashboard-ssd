defmodule DashboardSSD.Documents.NotionSyncTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Cache.SharedDocumentsCache
  alias DashboardSSD.Clients.Client
  alias DashboardSSD.Documents.{NotionSync, SharedDocument}
  alias DashboardSSD.Repo

  setup do
    SharedDocumentsCache.invalidate_listing(:all)
    :ok
  end

  test "inserts and updates notion documents" do
    client = Repo.insert!(%Client{name: "Acme"})

    pages = [
      %{
        client_id: client.id,
        project_id: nil,
        source_id: "page-1",
        title: "Runbook",
        doc_type: "kb",
        visibility: :client,
        metadata: %{"notion_url" => "https://notion.so/page-1"}
      }
    ]

    assert {:ok, %{inserted: 1, updated: 0}} = NotionSync.sync(pages)

    update = [
      %{
        client_id: client.id,
        project_id: nil,
        source_id: "page-1",
        title: "Runbook V2",
        doc_type: "kb"
      }
    ]

    assert {:ok, %{inserted: 0, updated: 1}} = NotionSync.sync(update)
    assert Repo.get_by!(SharedDocument, source_id: "page-1").title == "Runbook V2"
  end
end
