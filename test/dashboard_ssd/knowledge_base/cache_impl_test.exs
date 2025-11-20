defmodule DashboardSSD.KnowledgeBase.CacheImplTest do
  use ExUnit.Case, async: false

  alias DashboardSSD.KnowledgeBase.Cache

  @ns :kb_cache_impl

  test "fetch returns error and does not cache" do
    Cache.reset()

    assert {:error, :boom} == Cache.fetch(@ns, :err, fn -> {:error, :boom} end, ttl: 10)
    assert :miss == Cache.get(@ns, :err)
  end

  test "force_cleanup removes expired entries" do
    Cache.reset()

    assert :ok == Cache.put(@ns, :exp, 1, 10)
    Process.sleep(15)
    assert :ok == Cache.force_cleanup()
    assert :miss == Cache.get(@ns, :exp)
  end
end
