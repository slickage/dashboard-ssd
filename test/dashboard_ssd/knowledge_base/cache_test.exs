defmodule DashboardSSD.KnowledgeBase.CacheTest do
  use ExUnit.Case, async: false

  alias DashboardSSD.KnowledgeBase.Cache

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
end
