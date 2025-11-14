defmodule DashboardSSD.DrivePermissionWorkerStub do
  @moduledoc false

  def share(folder_id, params) do
    send(self(), {:drive_share, folder_id, params})
    :ok
  end

  def unshare(folder_id, permission_id) do
    send(self(), {:drive_unshare, folder_id, permission_id})
    :ok
  end

  def revoke_email(folder_id, email) do
    send(self(), {:drive_revoke, folder_id, email})
    :ok
  end
end
