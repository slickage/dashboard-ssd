defmodule DashboardSSD.Meetings.CacheStoreTest do
  @moduledoc """
  Async: false — the cache store wraps a global ETS-backed cache and a single
  cache process. Tests here perform puts/gets/flushes that would be racy when
  executed concurrently across async cases, so we disable async to ensure
  isolation.
  """
  use ExUnit.Case, async: false

  alias DashboardSSD.Meetings.CacheStore

  setup do
    start_cache()
    CacheStore.reset()
    on_exit(fn -> CacheStore.reset() end)
    :ok
  end

  test "put/get/delete flow" do
    assert :ok = CacheStore.put({:k, 1}, :v, 1_000)
    assert {:ok, :v} = CacheStore.get({:k, 1})
    assert :ok = CacheStore.delete({:k, 1})
    assert :miss = CacheStore.get({:k, 1})
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
      start_supervised!({DashboardSSD.Cache, []})
    end
  end
end
