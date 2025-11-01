defmodule DashboardSSD.KnowledgeBase.CacheStoreTest do
  use ExUnit.Case, async: false

  alias DashboardSSD.KnowledgeBase.CacheStore

  setup do
    start_cache()
    CacheStore.reset()

    on_exit(fn -> CacheStore.reset() end)

    :ok
  end

  test "put/get/delete flow" do
    assert :ok = CacheStore.put(:foo, :bar, 1_000)
    assert {:ok, :bar} = CacheStore.get(:foo)
    assert :ok = CacheStore.delete(:foo)
    assert :miss = CacheStore.get(:foo)
  end

  test "fetch memoizes computed value" do
    compute = fn -> {:ok, 42} end

    assert {:ok, 42} = CacheStore.fetch(:answer, compute, ttl: 1_000)
    assert {:ok, 42} = CacheStore.get(:answer)
  end

  test "flush clears namespace" do
    assert :ok = CacheStore.put(:temp, :value, 1_000)
    assert {:ok, :value} = CacheStore.get(:temp)
    assert :ok = CacheStore.flush()
    assert :miss = CacheStore.get(:temp)
  end

  defp start_cache do
    unless Process.whereis(DashboardSSD.Cache) do
      start_supervised!(DashboardSSD.Cache)
    end
  end
end
