defmodule DashboardSSD.CacheTest do
  use ExUnit.Case, async: false

  alias DashboardSSD.Cache

  @ns :cache_test_namespace

  # The cache server is started by the application supervisor in tests.

  test "put/get with ttl and expiry" do
    assert :ok == Cache.put(@ns, :k1, 123, 50)
    assert {:ok, 123} == Cache.get(@ns, :k1)

    # Wait for expiry
    Process.sleep(60)
    assert :miss == Cache.get(@ns, :k1)
  end

  test "delete and flush work" do
    assert :ok == Cache.put(@ns, :a, 1, 5_000)
    assert :ok == Cache.put(@ns, :b, 2, 5_000)

    assert :ok == Cache.delete(@ns, :a)
    assert :miss == Cache.get(@ns, :a)

    assert :ok == Cache.flush(@ns)
    assert :miss == Cache.get(@ns, :b)
  end

  test "child_spec and force_cleanup do not crash" do
    spec = Cache.child_spec([])
    assert is_map(spec)
    assert spec.id == DashboardSSD.Cache
    assert match?({DashboardSSD.KnowledgeBase.Cache, :start_link, _}, spec.start)

    # Just ensure it can be called without crashing
    assert :ok == Cache.force_cleanup()
  end
end
