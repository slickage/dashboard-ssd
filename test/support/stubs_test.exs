defmodule DashboardSSD.SupportStubsTest do
  use ExUnit.Case, async: true

  alias DashboardSSD.DrivePermissionWorkerStub
  alias DashboardSSD.WorkspaceBootstrapStub

  test "drive permission stub routes share and unshare messages" do
    DrivePermissionWorkerStub.share("folder-1", %{role: "reader"})
    assert_received {:drive_share, "folder-1", %{role: "reader"}}

    DrivePermissionWorkerStub.unshare("folder-1", "perm-1")
    assert_received {:drive_unshare, "folder-1", "perm-1"}

    DrivePermissionWorkerStub.revoke_email("folder-2", "user@example.com")
    assert_received {:drive_revoke, "folder-2", "user@example.com"}
  end

  test "workspace bootstrap stub emits message when pid configured" do
    :persistent_term.put({:workspace_test_pid}, self())

    assert {:ok, %{sections: []}} =
             WorkspaceBootstrapStub.bootstrap(%{id: 7}, sections: [:drive, :notion])

    assert_received {:workspace_bootstrap, 7, [:drive, :notion]}
  after
    :persistent_term.erase({:workspace_test_pid})
  end

  test "workspace bootstrap stub no-ops without pid" do
    :persistent_term.erase({:workspace_test_pid})
    assert {:ok, %{sections: []}} = WorkspaceBootstrapStub.bootstrap(%{id: 8}, sections: [])
    refute_received {:workspace_bootstrap, _, _}
  end
end
