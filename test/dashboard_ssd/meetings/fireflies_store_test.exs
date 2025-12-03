defmodule DashboardSSD.Meetings.FirefliesStoreTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Meetings.FirefliesArtifact
  alias DashboardSSD.Meetings.FirefliesStore
  alias DashboardSSD.Repo

  test "upsert inserts and get returns normalized items" do
    series = "series-store-1"

    assert :not_found == FirefliesStore.get(series)

    :ok =
      FirefliesStore.upsert(series, %{
        transcript_id: "t-1",
        accomplished: "Notes",
        action_items: ["A", "B"],
        bullet_gist: "• A\n• B"
      })

    assert {:ok, %{accomplished: "Notes", action_items: ["A", "B"]}} = FirefliesStore.get(series)
  end

  test "upsert updates existing artifact" do
    series = "series-store-2"

    :ok = FirefliesStore.upsert(series, %{accomplished: "Old", action_items: ["X"]})
    :ok = FirefliesStore.upsert(series, %{accomplished: "New", action_items: ["Y"]})

    rec = Repo.get_by(FirefliesArtifact, recurring_series_id: series)
    assert rec.accomplished == "New"
    # Stored as map in DB
    assert rec.action_items == %{"items" => ["Y"]}
  end
end
