defmodule DashboardSSD.CacheTest do
  use ExUnit.Case, async: true

  alias DashboardSSD.Cache

  setup do
    # Cache is supervised by the application; ensure clean state
    _ = Cache.reset()
    on_exit(fn -> Cache.reset() end)
    :ok
  end

  test "put/get/delete/flush/reset" do
    ns = :cov
    key1 = :a
    key2 = :b

    assert :miss == Cache.get(ns, key1)
    :ok = Cache.put(ns, key1, 123, 10_000)
    assert {:ok, 123} == Cache.get(ns, key1)

    :ok = Cache.put(ns, key2, :x, 10_000)
    :ok = Cache.delete(ns, key2)
    assert :miss == Cache.get(ns, key2)

    :ok = Cache.flush(ns)
    assert :miss == Cache.get(ns, key1)

    :ok = Cache.put(ns, key1, :y, 10_000)
    assert {:ok, :y} == Cache.get(ns, key1)
    :ok = Cache.reset()
    assert :miss == Cache.get(ns, key1)
  end
end
