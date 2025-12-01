defmodule DashboardSSD.ProjectsTest do
  use DashboardSSD.DataCase, async: false

  import Tesla.Mock

  alias DashboardSSD.Accounts
  alias DashboardSSD.Cache.SharedDocumentsCache
  alias DashboardSSD.Clients
  alias DashboardSSD.Documents.DocumentAccessLog
  alias DashboardSSD.Documents.SharedDocument
  alias DashboardSSD.Projects
  alias DashboardSSD.Projects.Project

  setup do
    {:ok, client} = Clients.create_client(%{name: "Client A"})
    %{client: client}
  end

  test "create_project/1 requires name and validates client if provided", %{client: client} do
    assert {:error, cs} = Projects.create_project(%{})
    assert %{name: ["can't be blank"]} = errors_on(cs)

    assert {:error, cs} = Projects.create_project(%{name: "X", client_id: -1})
    assert %{client_id: ["does not exist"]} = errors_on(cs)

    assert {:ok, %Project{} = p} = Projects.create_project(%{name: "X", client_id: client.id})
    assert p.client_id == client.id
  end

  test "list/get/update/delete project", %{client: client} do
    {:ok, p} = Projects.create_project(%{name: "P1", client_id: client.id})

    assert Enum.any?(Projects.list_projects(), &(&1.id == p.id))
    assert Projects.get_project!(p.id).name == "P1"

    {:ok, p} = Projects.update_project(p, %{name: "P2"})
    assert p.name == "P2"

    assert {:error, cs} = Projects.update_project(p, %{name: nil})
    assert %{name: ["can't be blank"]} = errors_on(cs)

    assert {:ok, _} = Projects.delete_project(p)
    assert_raise Ecto.NoResultsError, fn -> Projects.get_project!(p.id) end
  end

  test "list_projects_by_client/1 filters by client", %{client: client} do
    {:ok, c2} = Clients.create_client(%{name: "Client B"})
    {:ok, p1} = Projects.create_project(%{name: "P1", client_id: client.id})
    {:ok, _p2} = Projects.create_project(%{name: "P2", client_id: c2.id})

    ids = Projects.list_projects_by_client(client.id) |> Enum.map(& &1.id)
    assert ids == [p1.id]
  end

  test "list_projects_for_clients/1 aggregates across IDs", %{client: client} do
    {:ok, c2} = Clients.create_client(%{name: "Client B"})
    {:ok, p1} = Projects.create_project(%{name: "P1", client_id: client.id})
    {:ok, p2} = Projects.create_project(%{name: "P2", client_id: c2.id})

    ids =
      Projects.list_projects_for_clients([client.id, c2.id])
      |> Enum.map(& &1.id)
      |> Enum.sort()

    assert ids == Enum.sort([p1.id, p2.id])
    assert Projects.list_projects_for_clients([]) == []
  end

  test "drive_folder_configured?/1 checks presence of folder id", %{client: client} do
    project =
      Repo.insert!(%Project{name: "Configured", client_id: client.id, drive_folder_id: "folder"})

    assert Projects.drive_folder_configured?(project)
    refute Projects.drive_folder_configured?(%Project{project | drive_folder_id: nil})
  end

  test "create_project triggers workspace bootstrap", %{client: client} do
    Application.put_env(
      :dashboard_ssd,
      :workspace_bootstrap_module,
      DashboardSSD.WorkspaceBootstrapStub
    )

    :persistent_term.put({:workspace_test_pid}, self())

    {:ok, project} =
      Projects.create_project(%{
        name: "Workspace",
        client_id: client.id,
        drive_folder_id: "folder"
      })

    project_id = project.id
    assert_receive {:workspace_bootstrap, ^project_id, sections}
    assert sections == Projects.workspace_sections()
  after
    :persistent_term.erase({:workspace_test_pid})
    Application.delete_env(:dashboard_ssd, :workspace_bootstrap_module)
  end

  describe "client assignment drive permissions" do
    setup do
      Application.put_env(
        :dashboard_ssd,
        :drive_permission_worker,
        DashboardSSD.DrivePermissionWorkerStub
      )

      SharedDocumentsCache.invalidate_listing(:all)
      SharedDocumentsCache.invalidate_download(:all)
      Repo.delete_all(DocumentAccessLog)

      on_exit(fn ->
        Application.delete_env(:dashboard_ssd, :drive_permission_worker)
      end)

      {:ok, client} = Clients.create_client(%{name: "Drive Client"})

      project =
        Repo.insert!(%Project{
          name: "Drive Proj",
          client_id: client.id,
          drive_folder_id: "drive-folder"
        })

      doc = insert_drive_document(client.id, project.id)

      %{client: client, project: project, document: doc}
    end

    test "granting client assignment invalidates caches and logs permissions", %{
      client: client,
      project: project,
      document: document
    } do
      user = %{id: 501, email: "client-share@example.com", client_id: client.id}

      SharedDocumentsCache.put_listing({user.id, nil}, %{documents: []})
      SharedDocumentsCache.put_listing({user.id, project.id}, %{documents: []})
      SharedDocumentsCache.put_download_descriptor(document.id, %{token: "cached"})

      Projects.handle_client_assignment_change(user, nil)

      assert_receive {:drive_share, "drive-folder", params}
      assert params[:email] == "client-share@example.com"
      assert params[:role] == "reader"

      assert Repo.aggregate(DocumentAccessLog, :count, :id) == 1
      assert SharedDocumentsCache.get_listing({user.id, nil}) == :miss
      assert SharedDocumentsCache.get_listing({user.id, project.id}) == :miss
      assert SharedDocumentsCache.get_download_descriptor(document.id) == :miss
    end

    test "revoking client assignment removes permissions", %{
      client: client
    } do
      user = %{id: 777, email: "client-revoke@example.com", client_id: client.id}

      Projects.handle_client_assignment_change(user, nil)
      Projects.handle_client_assignment_change(%{user | client_id: nil}, client.id)

      assert_receive {:drive_revoke, "drive-folder", "client-revoke@example.com"}
      assert Repo.aggregate(DocumentAccessLog, :count, :id) == 2
    end
  end

  defp insert_drive_document(client_id, project_id) do
    params = %{
      client_id: client_id,
      project_id: project_id,
      source: :drive,
      source_id: Ecto.UUID.generate(),
      doc_type: "sow",
      title: "Drive Doc",
      visibility: :client,
      client_edit_allowed: false
    }

    %SharedDocument{}
    |> SharedDocument.changeset(params)
    |> Repo.insert!()
  end

  test "sync_drive_permissions_for_client shares folders for all users" do
    Application.put_env(
      :dashboard_ssd,
      :drive_permission_worker,
      DashboardSSD.DrivePermissionWorkerStub
    )

    on_exit(fn ->
      Application.delete_env(:dashboard_ssd, :drive_permission_worker)
    end)

    {:ok, client} = Clients.create_client(%{name: "Sync Client"})

    project =
      Repo.insert!(%Project{
        name: "Drive Project A",
        client_id: client.id,
        drive_folder_id: "folder-a"
      })

    insert_drive_document(client.id, project.id)

    {:ok, user} =
      Accounts.create_user(%{
        email: "drive-user@example.com",
        name: "Drive User",
        role_id: Accounts.ensure_role!("client").id,
        client_id: client.id
      })

    Projects.sync_drive_permissions_for_client(client.id)

    assert_receive {:drive_share, "folder-a", params}
    assert params[:email] == user.email
  end

  test "handle_client_assignment_change shares and revokes folders when client changes" do
    Application.put_env(
      :dashboard_ssd,
      :drive_permission_worker,
      DashboardSSD.DrivePermissionWorkerStub
    )

    SharedDocumentsCache.invalidate_listing(:all)
    SharedDocumentsCache.invalidate_download(:all)
    Repo.delete_all(DocumentAccessLog)

    on_exit(fn ->
      Application.delete_env(:dashboard_ssd, :drive_permission_worker)
    end)

    {:ok, client_a} = Clients.create_client(%{name: "Switch A"})
    {:ok, client_b} = Clients.create_client(%{name: "Switch B"})

    project_a =
      Repo.insert!(%Project{
        name: "Drive A",
        client_id: client_a.id,
        drive_folder_id: "folder-a"
      })

    project_b =
      Repo.insert!(%Project{
        name: "Drive B",
        client_id: client_b.id,
        drive_folder_id: "folder-b"
      })

    insert_drive_document(client_a.id, project_a.id)
    insert_drive_document(client_b.id, project_b.id)

    {:ok, user} =
      Accounts.create_user(%{
        email: "switch@example.com",
        name: "Switcher",
        role_id: Accounts.ensure_role!("client").id,
        client_id: client_a.id
      })

    Projects.handle_client_assignment_change(user, nil)
    assert_receive {:drive_share, "folder-a", %{email: "switch@example.com"}}

    Projects.handle_client_assignment_change(%{user | client_id: client_b.id}, client_a.id)

    assert_receive {:drive_revoke, "folder-a", "switch@example.com"}
    assert_receive {:drive_share, "folder-b", %{email: "switch@example.com"}}
  end

  test "handle_client_assignment_change no-ops for nil user" do
    assert :ok = Projects.handle_client_assignment_change(nil, 123)
  end

  test "sync_drive_permissions_for_user no-ops without client id" do
    assert :ok = Projects.sync_drive_permissions_for_user(%{client_id: nil})
  end

  test "handle_client_assignment_change ignores unchanged client" do
    assert :ok = Projects.handle_client_assignment_change(%{client_id: 5}, 5)
  end

  test "revoke_drive_permissions_for_user handles missing targets" do
    assert :ok = Projects.revoke_drive_permissions_for_user(%{email: "none@example.com"}, nil)
  end

  test "sync_drive_permissions_for_client ignores non-integer input" do
    assert :ok = Projects.sync_drive_permissions_for_client(nil)
  end

  test "revoke_drive_permissions_for_user revokes Drive access for user email" do
    Application.put_env(
      :dashboard_ssd,
      :drive_permission_worker,
      DashboardSSD.DrivePermissionWorkerStub
    )

    SharedDocumentsCache.invalidate_listing(:all)
    SharedDocumentsCache.invalidate_download(:all)
    Repo.delete_all(DocumentAccessLog)

    on_exit(fn ->
      Application.delete_env(:dashboard_ssd, :drive_permission_worker)
    end)

    {:ok, client} = Clients.create_client(%{name: "Revoke Client"})

    project =
      Repo.insert!(%Project{
        name: "Drive Revoker",
        client_id: client.id,
        drive_folder_id: "folder-revoke"
      })

    insert_drive_document(client.id, project.id)

    user = %{email: "revoke@example.com", client_id: client.id}

    Projects.revoke_drive_permissions_for_user(user, client.id)

    assert_receive {:drive_revoke, "folder-revoke", "revoke@example.com"}
  end

  test "sync_drive_permissions_for_user shares folders for provided user map" do
    Application.put_env(
      :dashboard_ssd,
      :drive_permission_worker,
      DashboardSSD.DrivePermissionWorkerStub
    )

    on_exit(fn ->
      Application.delete_env(:dashboard_ssd, :drive_permission_worker)
    end)

    {:ok, client} = Clients.create_client(%{name: "Direct Sync"})

    project =
      Repo.insert!(%Project{
        name: "Drive Direct",
        client_id: client.id,
        drive_folder_id: "folder-direct"
      })

    insert_drive_document(client.id, project.id)

    Projects.sync_drive_permissions_for_user(%{client_id: client.id, email: "direct@example.com"})

    assert_receive {:drive_share, "folder-direct", %{email: "direct@example.com"}}
  end

  describe "ensure_drive_folder/1" do
    setup do
      Application.put_env(:dashboard_ssd, :integrations, drive_token: "drive-token")

      Application.put_env(:dashboard_ssd, :shared_documents_integrations, %{
        drive: %{root_folder_id: "root-folder"}
      })

      on_exit(fn ->
        Application.delete_env(:dashboard_ssd, :integrations)
        Application.delete_env(:dashboard_ssd, :shared_documents_integrations)
      end)

      :ok
    end

    test "creates client and project folders when missing", %{client: client} do
      project =
        Repo.insert!(%Project{
          name: "Phoenix",
          client_id: client.id,
          drive_folder_id: nil
        })

      client_name = "Client #{client.id}"
      project_name = project.name

      mock(fn
        %{method: :get, url: "https://www.googleapis.com/drive/v3/files", query: query} ->
          q = Keyword.get(query, :q, "")

          cond do
            String.contains?(q, client_name) ->
              %Tesla.Env{status: 200, body: %{"files" => []}}

            String.contains?(q, project_name) ->
              %Tesla.Env{status: 200, body: %{"files" => []}}

            true ->
              %Tesla.Env{status: 200, body: %{"files" => []}}
          end

        %{method: :post, url: "https://www.googleapis.com/drive/v3/files", body: body} ->
          params = Jason.decode!(body)

          folder_id = "#{params["name"]}-folder"

          %Tesla.Env{status: 200, body: %{"id" => folder_id}}
      end)

      assert {:ok, updated} = Projects.ensure_drive_folder(project)
      assert updated.drive_folder_id == "#{project_name}-folder"
      assert updated.drive_folder_sharing_inherited
    end

    test "returns error when Drive API fails", %{client: client} do
      project =
        Repo.insert!(%Project{
          name: "Broken",
          client_id: client.id,
          drive_folder_id: nil
        })

      mock(fn
        %{method: :get, url: "https://www.googleapis.com/drive/v3/files"} ->
          {:ok, %Tesla.Env{status: 500, body: %{"error" => "boom"}}}
      end)

      assert {:error, {:http_error, 500, %{"error" => "boom"}}} =
               Projects.ensure_drive_folder(project)
    end

    test "uses env root folder id fallback", %{client: client} do
      Application.delete_env(:dashboard_ssd, :shared_documents_integrations)
      System.put_env("DRIVE_ROOT_FOLDER_ID", "env-root")

      on_exit(fn -> System.delete_env("DRIVE_ROOT_FOLDER_ID") end)

      project =
        Repo.insert!(%Project{
          name: "Env Root",
          client_id: client.id,
          drive_folder_id: nil
        })

      mock(fn
        %{method: :get, url: "https://www.googleapis.com/drive/v3/files", query: _query} ->
          %Tesla.Env{status: 200, body: %{"files" => []}}

        %{method: :post, url: "https://www.googleapis.com/drive/v3/files", body: body} ->
          params = Jason.decode!(body)
          %Tesla.Env{status: 200, body: %{"id" => "#{params["name"]}-folder"}}
      end)

      assert {:ok, updated} = Projects.ensure_drive_folder(project)
      assert updated.drive_folder_id == "Env Root-folder"
    end
  end

  test "mark_drive_permission_sync/2 updates timestamp", %{client: client} do
    synced_at = ~U[2024-01-01 00:00:00Z]

    project =
      Repo.insert!(%Project{
        name: "Sync Timestamp",
        client_id: client.id,
        drive_folder_id: "folder",
        drive_folder_last_permission_sync_at: nil
      })

    assert {:ok, updated} = Projects.mark_drive_permission_sync(project, synced_at)
    assert updated.drive_folder_last_permission_sync_at == synced_at
  end

  test "clear_drive_folder_metadata/1 resets metadata", %{client: client} do
    project =
      Repo.insert!(%Project{
        name: "Reset Metadata",
        client_id: client.id,
        drive_folder_id: "folder",
        drive_folder_sharing_inherited: false,
        drive_folder_last_permission_sync_at: ~U[2024-01-01 00:00:00Z]
      })

    assert {:ok, updated} = Projects.clear_drive_folder_metadata(project)
    refute updated.drive_folder_id
    assert updated.drive_folder_sharing_inherited
    assert is_nil(updated.drive_folder_last_permission_sync_at)
  end
end
