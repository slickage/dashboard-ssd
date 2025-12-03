defmodule DashboardSSD.Integrations.FirefliesTest do
  @moduledoc """
  Async: false — ensure deterministic behavior with shared ETS cache.
  """
  use DashboardSSD.DataCase, async: false

  alias DashboardSSD.Integrations.Fireflies
  alias DashboardSSD.Meetings.CacheStore
  alias DashboardSSD.Meetings.FirefliesArtifact
  alias DashboardSSD.Repo

  setup do
    CacheStore.reset()
    on_exit(fn -> CacheStore.reset() end)
    :ok
  end

  test "fetch_latest_for_series uses DB when present and populates cache" do
    series = "series-xyz"

    # Seed DB with an artifact so no HTTP is needed
    {:ok, _} =
      %FirefliesArtifact{}
      |> FirefliesArtifact.changeset(%{
        recurring_series_id: series,
        transcript_id: "t-cache",
        accomplished: "Cached notes",
        action_items: ["X"],
        bullet_gist: "• X",
        fetched_at: DateTime.utc_now()
      })
      |> Repo.insert()

    CacheStore.flush()

    assert {:ok, %{action_items: ["X"], accomplished: "Cached notes"}} =
             Fireflies.fetch_latest_for_series(series, ttl: 1_000)

    # Should now be retrievable from cache directly
    assert {:ok, %{accomplished: "Cached notes"}} = CacheStore.get({:series_artifacts, series})
  end
end
