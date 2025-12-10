defmodule DashboardSSD.Meetings.FirefliesStoreTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Meetings.FirefliesArtifact
  alias DashboardSSD.Meetings.FirefliesStore
  alias DashboardSSD.Repo

  test "get returns normalized items: nil, list, map{items}" do
    series_nil = "series-nil"
    series_list = "series-list"
    series_map = "series-map"

    %FirefliesArtifact{}
    |> FirefliesArtifact.changeset(%{
      recurring_series_id: series_nil,
      accomplished: nil,
      action_items: nil,
      fetched_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.insert!()

    %FirefliesArtifact{}
    |> FirefliesArtifact.changeset(%{
      recurring_series_id: series_list,
      accomplished: "Notes",
      action_items: ["A", "B"],
      fetched_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.insert!()

    %FirefliesArtifact{}
    |> FirefliesArtifact.changeset(%{
      recurring_series_id: series_map,
      accomplished: nil,
      action_items: %{"items" => ["X"]},
      fetched_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.insert!()

    assert {:ok, %{action_items: []}} = FirefliesStore.get(series_nil)

    assert {:ok, %{action_items: ["A", "B"], accomplished: "Notes"}} =
             FirefliesStore.get(series_list)

    assert {:ok, %{action_items: ["X"]}} = FirefliesStore.get(series_map)
  end

  test "upsert inserts then updates existing record and sets timestamps" do
    series = "series-up"

    :ok =
      FirefliesStore.upsert(series, %{
        transcript_id: "t1",
        accomplished: "N",
        action_items: ["A"],
        fetched_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    rec1 = Repo.get_by!(FirefliesArtifact, recurring_series_id: series)
    assert rec1.transcript_id == "t1"
    assert rec1.accomplished == "N"
    assert is_struct(rec1.fetched_at, DateTime)

    :ok =
      FirefliesStore.upsert(series, %{
        transcript_id: "t2",
        accomplished: "M",
        action_items: ["B"],
        fetched_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    rec2 = Repo.get_by!(FirefliesArtifact, recurring_series_id: series)
    assert rec2.transcript_id == "t2"
    assert rec2.accomplished == "M"
  end

  test "get normalizes map without items to empty list" do
    series = "series-empty-items"

    %FirefliesArtifact{}
    |> FirefliesArtifact.changeset(%{
      recurring_series_id: series,
      action_items: %{},
      fetched_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.insert!()

    assert {:ok, %{action_items: []}} = FirefliesStore.get(series)
  end
end
