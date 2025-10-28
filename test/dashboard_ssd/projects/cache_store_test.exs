defmodule DashboardSSD.Projects.CacheStoreTest do
  use ExUnit.Case, async: false

  alias DashboardSSD.Cache
  alias DashboardSSD.Projects.CacheStore

  setup do
    # Ensure the cache table exists and starts clean
    Cache.reset()
    CacheStore.delete()
    :ok
  rescue
    RuntimeError ->
      # DashboardSSD.Cache may not be started in isolated tests.
      start_supervised!(DashboardSSD.Cache)
      Cache.reset()
      CacheStore.delete()
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

    assert :ok = CacheStore.put(entry, :timer.minutes(5))
    assert {:ok, fetched} = CacheStore.get()
    assert fetched.payload == entry.payload
  end

  test "delete clears cache entry" do
    CacheStore.put(%{payload: %{}, synced_at: nil, synced_at_mono: nil}, :timer.minutes(5))
    assert {:ok, _} = CacheStore.get()
    assert :ok = CacheStore.delete()
    assert :miss = CacheStore.get()
  end
end
