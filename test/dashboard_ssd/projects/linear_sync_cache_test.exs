defmodule DashboardSSD.Projects.LinearSyncCacheTest do
  use ExUnit.Case, async: false

  alias DashboardSSD.KnowledgeBase.Cache
  alias DashboardSSD.Projects.LinearSyncCache

  setup do
    # Ensure the cache table exists and starts clean
    Cache.reset()
    LinearSyncCache.delete()
    :ok
  rescue
    RuntimeError ->
      # DashboardSSD.KnowledgeBase.Cache may not be started in isolated tests.
      start_supervised!(DashboardSSD.KnowledgeBase.Cache)
      Cache.reset()
      LinearSyncCache.delete()
      :ok
  end

  test "puts and gets cache entry" do
    entry = %{
      payload: %{inserted: 1, updated: 2},
      synced_at: DateTime.utc_now(),
      synced_at_mono: System.monotonic_time(:millisecond),
      next_allowed_sync_mono: nil,
      rate_limit_message: nil
    }

    assert :ok = LinearSyncCache.put(entry, :timer.minutes(5))
    assert {:ok, fetched} = LinearSyncCache.get()
    assert fetched.payload == entry.payload
  end

  test "delete clears cache entry" do
    LinearSyncCache.put(%{payload: %{}, synced_at: nil, synced_at_mono: nil}, :timer.minutes(5))
    assert {:ok, _} = LinearSyncCache.get()
    assert :ok = LinearSyncCache.delete()
    assert :miss = LinearSyncCache.get()
  end
end
