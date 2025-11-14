defmodule Mix.Tasks.SharedDocuments.SyncTest do
  @moduledoc false
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  alias __MODULE__.RunnerStub
  alias Mix.Tasks.SharedDocuments.Sync, as: SharedDocumentsSyncTask

  setup do
    Application.delete_env(:dashboard_ssd, :shared_documents_sync_runner)
    :ok
  end

  test "raises on invalid source value" do
    assert_raise Mix.Error, fn ->
      SharedDocumentsSyncTask.run(["--source", "bogus"])
    end
  end

  test "skips when runner module is missing" do
    output =
      capture_io(fn ->
        SharedDocumentsSyncTask.run(["--source", "drive"])
      end)

    assert output =~ "runner DashboardSSD.Documents.SharedDocumentsSync is not available"
  end

  test "invokes configured runner with normalized options" do
    Application.put_env(:dashboard_ssd, :shared_documents_sync_runner, RunnerStub)

    output =
      capture_io(fn ->
        SharedDocumentsSyncTask.run(["--source", "drive", "--dry-run", "--force"])
      end)

    assert_receive {:sync_all,
                    %{
                      sources: [:drive],
                      dry_run?: true,
                      force?: true
                    }}

    assert output =~ "Shared documents sync finished"
  after
    Application.delete_env(:dashboard_ssd, :shared_documents_sync_runner)
  end

  defmodule RunnerStub do
    @moduledoc false
    def sync_all(opts), do: send(self(), {:sync_all, opts})
  end
end
