defmodule DashboardSSD.Documents.NotionSyncTest do
  use DashboardSSD.DataCase, async: true
  import ExUnit.CaptureLog

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
        title: "Project KB",
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
        title: "Project KB V2",
        doc_type: "kb"
      }
    ]

    assert {:ok, %{inserted: 0, updated: 1}} = NotionSync.sync(update)
    assert Repo.get_by!(SharedDocument, source_id: "page-1").title == "Project KB V2"
  end

  test "returns error when insert fails" do
    pages = [
      %{
        client_id: nil,
        project_id: nil,
        source_id: "page-invalid",
        title: "No Client",
        doc_type: "kb"
      }
    ]

    assert {:error, %Ecto.Changeset{}} = NotionSync.sync(pages)
  end

  test "logs warning when stale percentage exceeds threshold" do
    client = Repo.insert!(%Client{name: "Core"})

    pages =
      for idx <- 1..5 do
        %{
          client_id: client.id,
          project_id: nil,
          source_id: "page-stale-#{idx}",
          title: "Doc #{idx}",
          doc_type: "kb",
          stale?: rem(idx, 2) == 0
        }
      end

    log =
      capture_log(fn ->
        assert {:ok, %{inserted: 5, updated: 0}} = NotionSync.sync(pages)
      end)

    assert log =~ "Notion sync stale percentage above threshold"
  end
end
