defmodule DashboardSSD.Meetings.FirefliesArtifactTest do
  use ExUnit.Case, async: true

  alias DashboardSSD.Meetings.FirefliesArtifact

  test "changeset normalizes action_items when list with atom key" do
    cs =
      FirefliesArtifact.changeset(%FirefliesArtifact{}, %{
        recurring_series_id: "s1",
        action_items: ["A", "B"]
      })

    assert cs.valid?
    assert cs.changes[:action_items] == %{"items" => ["A", "B"]}
  end

  test "changeset normalizes action_items when list with string key" do
    cs =
      FirefliesArtifact.changeset(%FirefliesArtifact{}, %{
        "recurring_series_id" => "s2",
        "action_items" => ["C"]
      })

    assert cs.valid?
    assert cs.changes[:action_items] == %{"items" => ["C"]}
  end

  test "changeset requires recurring_series_id" do
    cs = FirefliesArtifact.changeset(%FirefliesArtifact{}, %{action_items: ["A"]})
    refute cs.valid?
  end
end
