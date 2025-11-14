defmodule DashboardSSD.Projects.DrivePermissionWorkerTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Projects.DrivePermissionWorker

  setup do
    Application.put_env(:dashboard_ssd, :drive_permission_worker_inline, true)
    Application.put_env(:dashboard_ssd, :drive_permission_worker_backoff_ms, 5)
    Application.put_env(:dashboard_ssd, :integrations, drive_token: "drive-token")

    on_exit(fn ->
      Application.delete_env(:dashboard_ssd, :drive_permission_worker_inline)
      Application.delete_env(:dashboard_ssd, :drive_permission_worker_backoff_ms)
      Application.delete_env(:dashboard_ssd, :integrations)
    end)

    :ok
  end

  test "share posts Drive permission request" do
    Tesla.Mock.mock(fn %Tesla.Env{method: :post, url: url, body: body} = env ->
      assert String.contains?(url, "/files/folder-123/permissions")
      params = Jason.decode!(body)
      assert params["emailAddress"] == "client@example.com"
      assert params["role"] == "reader"
      assert params["type"] == "user"

      %{env | status: 200, body: %{"id" => "perm-1"}}
    end)

    assert :ok =
             DrivePermissionWorker.share("folder-123", %{
               role: "reader",
               type: "user",
               email: "client@example.com"
             })
  end

  test "unshare deletes permission entry" do
    Tesla.Mock.mock(fn %Tesla.Env{method: :delete, url: url} = env ->
      assert String.contains?(url, "/files/folder-123/permissions/perm-2")
      %{env | status: 204, body: ""}
    end)

    assert :ok = DrivePermissionWorker.unshare("folder-123", "perm-2")
  end

  test "revoke_email finds permission id before unsharing" do
    Tesla.Mock.mock(fn
      %Tesla.Env{method: :get, url: url} = env ->
        assert String.contains?(url, "/files/folder-abc/permissions")

        %{
          env
          | status: 200,
            body: %{
              "permissions" => [%{"id" => "perm-9", "emailAddress" => "client@example.com"}]
            }
        }

      %Tesla.Env{method: :delete, url: url} = env ->
        assert String.contains?(url, "/files/folder-abc/permissions/perm-9")
        %{env | status: 204, body: ""}
    end)

    assert :ok = DrivePermissionWorker.revoke_email("folder-abc", "client@example.com")
  end

  test "share retries when Drive API errors" do
    parent = self()

    Tesla.Mock.mock(fn %Tesla.Env{method: :post} = env ->
      send(parent, {:share_attempt, env})
      {:error, :boom}
    end)

    assert :ok =
             DrivePermissionWorker.share("folder-error", %{
               role: "reader",
               type: "user",
               email: "client@example.com"
             })

    assert_receive {:share_attempt, _}
  end

  test "revoke_email handles permission lookup failures" do
    parent = self()

    Tesla.Mock.mock(fn %Tesla.Env{method: :get} = env ->
      send(parent, {:permission_lookup, env})
      {:error, :boom}
    end)

    assert :ok = DrivePermissionWorker.revoke_email("folder-error", "client@example.com")
    assert_receive {:permission_lookup, _}
  end
end
