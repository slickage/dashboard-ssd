defmodule DashboardSSD.Projects.DrivePermissionWorkerTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import Tesla.Mock

  alias DashboardSSD.Projects.DrivePermissionWorker

  setup do
    envs = %{
      env: Application.get_env(:dashboard_ssd, :env),
      inline: Application.get_env(:dashboard_ssd, :drive_permission_worker_inline),
      disabled: Application.get_env(:dashboard_ssd, :drive_permission_worker_disabled),
      backoff: Application.get_env(:dashboard_ssd, :drive_permission_worker_backoff_ms),
      test_env: Application.get_env(:dashboard_ssd, :test_env?)
    }

    Application.put_env(:dashboard_ssd, :env, :dev)
    Application.put_env(:dashboard_ssd, :drive_permission_worker_inline, true)
    Application.put_env(:dashboard_ssd, :drive_permission_worker_disabled, false)
    Application.put_env(:dashboard_ssd, :drive_permission_worker_backoff_ms, 0)
    Application.put_env(:dashboard_ssd, :test_env?, true)

    on_exit(fn ->
      restore_env(:env, envs.env)
      restore_env(:drive_permission_worker_inline, envs.inline)
      restore_env(:drive_permission_worker_disabled, envs.disabled)
      restore_env(:drive_permission_worker_backoff_ms, envs.backoff)
      restore_env(:test_env?, envs.test_env)
    end)

    :ok
  end

  test "share returns :ok when no retries needed" do
    mock(fn
      %{method: :post, url: "https://www.googleapis.com/drive/v3/files/folder/permissions"} ->
        {:ok, %Tesla.Env{status: 200, body: %{"id" => "perm"}}}
    end)

    assert :ok =
             DrivePermissionWorker.share("folder", %{role: "reader", email: "user@example.com"})
  end

  test "share logs when retries exceed max attempts" do
    {:ok, counter} = Agent.start_link(fn -> 0 end)
    on_exit(fn -> if Process.alive?(counter), do: Agent.stop(counter) end)

    mock(fn
      %{method: :post, url: "https://www.googleapis.com/drive/v3/files/folder/permissions"} ->
        Agent.update(counter, &(&1 + 1))
        {:ok, %Tesla.Env{status: 500, body: %{"error" => "boom"}}}
    end)

    log =
      capture_log(fn ->
        assert :ok =
                 DrivePermissionWorker.share("folder", %{
                   role: "reader",
                   email: "user@example.com"
                 })
      end)

    assert log =~ "Drive permission worker exceeded retries"
    assert log =~ "Drive permission share failed on attempt 1"
    assert Agent.get(counter, & &1) == 4
  end

  test "unshare succeeds" do
    mock(fn
      %{
        method: :delete,
        url: "https://www.googleapis.com/drive/v3/files/folder/permissions/perm-1"
      } ->
        {:ok, %Tesla.Env{status: 204}}
    end)

    assert :ok = DrivePermissionWorker.unshare("folder", "perm-1")
  end

  test "revoke_email deletes matching permission" do
    mock(fn
      %{method: :get, url: "https://www.googleapis.com/drive/v3/files/folder/permissions"} ->
        {:ok,
         %Tesla.Env{
           status: 200,
           body: %{
             "permissions" => [
               %{"id" => "perm-123", "emailAddress" => "user@example.com"}
             ]
           }
         }}

      %{
        method: :delete,
        url: "https://www.googleapis.com/drive/v3/files/folder/permissions/perm-123"
      } ->
        {:ok, %Tesla.Env{status: 204}}
    end)

    log =
      capture_log(fn ->
        assert :ok = DrivePermissionWorker.revoke_email("folder", "User@example.com")
      end)

    assert log == ""
  end

  test "revoke_email retries when permission lookup fails" do
    {:ok, counter} = Agent.start_link(fn -> 0 end)
    on_exit(fn -> if Process.alive?(counter), do: Agent.stop(counter) end)

    mock(fn
      %{method: :get, url: "https://www.googleapis.com/drive/v3/files/folder/permissions"} ->
        Agent.update(counter, &(&1 + 1))
        {:error, :boom}
    end)

    log =
      capture_log(fn ->
        assert :ok = DrivePermissionWorker.revoke_email("folder", "user@example.com")
      end)

    assert log =~ "Drive permission unshare_lookup failed on attempt 1"
    assert log =~ "Drive permission worker exceeded retries"
    assert Agent.get(counter, & &1) == 4
  end

  test "revoke_email ignores nil" do
    assert :ok = DrivePermissionWorker.revoke_email("folder", nil)
  end

  defp restore_env(key, nil), do: Application.delete_env(:dashboard_ssd, key)
  defp restore_env(key, value), do: Application.put_env(:dashboard_ssd, key, value)
end
