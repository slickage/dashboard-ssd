defmodule DashboardSSD.Meetings.FirefliesStoreTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Meetings.FirefliesStore

  test "get returns :not_found when missing" do
    assert :not_found == FirefliesStore.get("series-x")
  end

  test "upsert inserts then updates and normalizes items" do
    s = "series-1"

    :ok =
      FirefliesStore.upsert(s, %{
        transcript_id: "t1",
        accomplished: "Done",
        action_items: ["A", "B"],
        bullet_gist: nil
      })

    assert {:ok, art1} = FirefliesStore.get(s)
    assert art1.accomplished == "Done"
    assert art1.action_items == ["A", "B"]

    # Update with map form for items to hit normalize_items/1 map branch
    :ok =
      FirefliesStore.upsert(s, %{
        accomplished: "Updated",
        action_items: %{"items" => ["C"]},
        bullet_gist: "gist"
      })

    assert {:ok, art2} = FirefliesStore.get(s)
    assert art2.accomplished == "Updated"
    assert art2.action_items == ["C"]
    assert art2.bullet_gist == "gist"

    # Update with unrelated map for items -> normalizes to []
    :ok = FirefliesStore.upsert(s, %{action_items: %{}})
    assert {:ok, art3} = FirefliesStore.get(s)
    assert art3.action_items == []
  end
end
