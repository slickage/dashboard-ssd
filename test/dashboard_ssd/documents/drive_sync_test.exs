defmodule DashboardSSD.Documents.DriveSyncTest do
  use DashboardSSD.DataCase, async: false

  alias DashboardSSD.Clients.Client
  alias DashboardSSD.Documents.DriveSync
  alias DashboardSSD.Documents.SharedDocument
  alias DashboardSSD.Projects.Project
  alias DashboardSSD.Repo

  describe "sync/2" do
    setup do
      client = Repo.insert!(%Client{name: "Sync Client"})
      project = Repo.insert!(%Project{name: "Sync Project", client_id: client.id})
      %{client: client, project: project}
    end

    test "inserts and updates shared documents", %{client: client, project: project} do
      attrs = [
        %{
          client_id: client.id,
          project_id: project.id,
          source_id: "file-1",
          doc_type: "contract",
          title: "Original",
          metadata: %{webViewLink: "https://example.com"}
        }
      ]

      assert {:ok, %{inserted: 1, updated: 0, deleted: 0}} = DriveSync.sync(attrs)

      original = Repo.get_by!(SharedDocument, source_id: "file-1")
      assert original.title == "Original"

      updated_attrs = [
        %{
          client_id: client.id,
          project_id: project.id,
          source_id: "file-1",
          doc_type: "contract",
          title: "Updated",
          metadata: %{webViewLink: "https://example.com/doc"}
        }
      ]

      assert {:ok, %{inserted: 0, updated: 1, deleted: 0}} = DriveSync.sync(updated_attrs)
      assert Repo.get!(SharedDocument, original.id).title == "Updated"
    end

    test "prunes documents missing from Drive when prune_missing? true", %{
      client: client,
      project: project
    } do
      stale =
        Repo.insert!(%SharedDocument{
          client_id: client.id,
          project_id: project.id,
          source: :drive,
          source_id: "stale",
          doc_type: "contract",
          title: "Stale",
          visibility: :client
        })

      fresh_attrs = [
        %{
          client_id: client.id,
          project_id: project.id,
          source_id: "fresh",
          doc_type: "contract",
          title: "Fresh"
        }
      ]

      assert {:ok, %{inserted: 1, updated: 0, deleted: 1}} =
               DriveSync.sync(fresh_attrs, prune_missing?: true)

      assert Repo.get(SharedDocument, stale.id) == nil
      assert Repo.get_by!(SharedDocument, source_id: "fresh")
    end

    test "prunes projects provided via project_ids option when no remote docs", %{
      client: client,
      project: project
    } do
      stale =
        Repo.insert!(%SharedDocument{
          client_id: client.id,
          project_id: project.id,
          source: :drive,
          source_id: "prune-me",
          doc_type: "contract",
          title: "Prune Me",
          visibility: :client
        })

      assert {:ok, %{inserted: 0, updated: 0, deleted: 1}} =
               DriveSync.sync([], prune_missing?: true, project_ids: [project.id])

      refute Repo.get(SharedDocument, stale.id)
    end

    test "returns error when validation fails", %{client: client} do
      attrs = [
        %{
          client_id: client.id,
          project_id: nil,
          source_id: nil,
          doc_type: "contract",
          title: "Invalid"
        }
      ]

      assert {:error, %Ecto.Changeset{}} = DriveSync.sync(attrs)
    end
  end
end
