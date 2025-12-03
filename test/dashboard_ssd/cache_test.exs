defmodule DashboardSSD.CacheTest do
  use ExUnit.Case, async: false

  alias DashboardSSD.Cache

  setup do
    Cache.reset()
    :ok
  end

  test "put and get returns cached value" do
    assert :miss == Cache.get(:collections, "a")
    Cache.put(:collections, "a", %{id: "a"})
    assert {:ok, %{id: "a"}} = Cache.get(:collections, "a")
  end

  test "get returns miss when entry expired" do
    Cache.put(:documents, "stale", :value, 5)
    Process.sleep(10)
    assert :miss == Cache.get(:documents, "stale")
  end

  test "fetch caches computed value and short-circuits subsequent calls" do
    hits = :counters.new(1, [])

    fun = fn ->
      :counters.add(hits, 1, 1)
      42
    end

    assert {:ok, 42} = Cache.fetch(:documents, "answer", fun)
    assert {:ok, 42} = Cache.fetch(:documents, "answer", fun)
    assert 1 == :counters.get(hits, 1)
  end

  test "fetch propagates errors without caching" do
    assert {:error, :oops} = Cache.fetch(:documents, "err", fn -> {:error, :oops} end)
    assert :miss == Cache.get(:documents, "err")
  end

  test "flush removes all entries for a namespace" do
    Cache.put(:collections, 1, :foo)
    Cache.put(:documents, 1, :bar)

    Cache.flush(:collections)
    assert :miss == Cache.get(:collections, 1)
    assert {:ok, :bar} = Cache.get(:documents, 1)
  end

  test "force_cleanup removes expired entries" do
    Cache.put(:documents, :temp, :value, 0)
    Cache.force_cleanup()
    assert :miss == Cache.get(:documents, :temp)
  end

  test "init reuses existing table and skips cleanup scheduling when interval is non-positive" do
    Cache.put(:documents, :existing, :value)

    assert {:ok, %{cleanup_interval: 0}} =
             Cache.init(table: :dashboard_ssd_cache, cleanup_interval: 0)
  end

  test "delete removes individual entries" do
    Cache.put(:documents, :delete_me, :value)
    assert {:ok, :value} = Cache.get(:documents, :delete_me)
    assert :ok = Cache.delete(:documents, :delete_me)
    assert :miss == Cache.get(:documents, :delete_me)
  end

  test "put with negative ttl expires immediately" do
    Cache.put(:documents, :negative_ttl, :value, -10)
    assert :miss == Cache.get(:documents, :negative_ttl)
  end

  test "fetch respects custom ttl option" do
    assert {:ok, :short_lived} =
             Cache.fetch(:documents, :short, fn -> :short_lived end, ttl: 5)

    Process.sleep(10)
    assert :miss == Cache.get(:documents, :short)
  end

  test "fetch caches values returned in {:ok, value} tuples" do
    assert {:ok, :tuple} = Cache.fetch(:documents, :tuple, fn -> {:ok, :tuple} end)
    assert {:ok, :tuple} = Cache.get(:documents, :tuple)
  end

  test "start_link supports custom tables and cleanup interval" do
    pid =
      start_supervised!(
        {Cache, [name: :cache_test_proc, table: :cache_test_table, cleanup_interval: 1]}
      )

    on_exit(fn ->
      if :ets.whereis(:cache_test_table) != :undefined do
        :ets.delete(:cache_test_table)
      end
    end)

    assert :ets.whereis(:cache_test_table) != :undefined

    send(pid, :cleanup)
    Process.sleep(5)

    GenServer.cast(pid, :force_cleanup)
    Process.sleep(5)
  end
end
