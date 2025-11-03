defmodule DashboardSSD.Integrations.FirefliesTest do
  @moduledoc """
  Async: false — this test exercises the shared ETS-backed cache via
  DashboardSSD.Meetings.CacheStore (which wraps a singleton cache process and
  named ETS table). Running concurrently can cause cross-test interference
  (e.g., cache resets/flushes), so we serialize these tests.
  """
  use ExUnit.Case, async: false

  alias DashboardSSD.Meetings.CacheStore
  alias DashboardSSD.Integrations.Fireflies

  setup do
    start_cache()
    CacheStore.reset()
    on_exit(fn -> CacheStore.reset() end)
    :ok
  end

  test "parse_summary splits accomplished vs action items" do
    txt = "Done work\n\nAction Items:\n- A\n- B"
    parsed = Fireflies.parse_summary(txt)
    assert parsed.accomplished =~ "Done work"
    assert parsed.action_items == ["- A", "- B"]
  end

  test "fetch_latest_for_series caches result" do
    series = "series-xyz"
    assert {:ok, %{action_items: [], accomplished: nil}} =
             Fireflies.fetch_latest_for_series(series, ttl: 1_000)

    # Should now be retrievable from cache directly
    assert {:ok, _} = CacheStore.get({:series_artifacts, series})
  end

  defp start_cache do
    unless Process.whereis(DashboardSSD.KnowledgeBase.Cache) do
      start_supervised!({DashboardSSD.Cache, []})
    end
  end
end
