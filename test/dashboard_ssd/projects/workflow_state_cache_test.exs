defmodule DashboardSSD.Projects.WorkflowStateCacheTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Projects
  alias DashboardSSD.Projects.{LinearWorkflowState, Project, WorkflowStateCache}
  alias DashboardSSD.Repo

  setup do
    WorkflowStateCache.flush()
    :ok
  end

  test "workflow_state_metadata_multi caches results per team" do
    insert_state("team-1", "state-1", "Todo")
    insert_state("team-1", "state-2", "In Progress")

    result = Projects.workflow_state_metadata_multi(["team-1"])

    assert %{
             "state-1" => %{name: "Todo", type: _type, color: _color},
             "state-2" => %{name: "In Progress", type: _type2, color: _color2}
           } = result["team-1"]

    Repo.delete_all(LinearWorkflowState)

    cached = Projects.workflow_state_metadata_multi(["team-1"])

    assert cached == result
  end

  test "unique_linear_team_ids returns distinct identifiers" do
    insert_project(%{name: "One", linear_team_id: "team-1"})
    insert_project(%{name: "Two", linear_team_id: "team-1"})
    insert_project(%{name: "Three", linear_team_id: "team-2"})
    insert_project(%{name: "No Team"})

    ids = Projects.unique_linear_team_ids() |> Enum.sort()

    assert ids == ["team-1", "team-2"]
  end

  test "workflow state cache stores and removes entries" do
    WorkflowStateCache.put("team-cache", %{"state" => %{}})
    assert {:ok, %{"state" => %{}}} = WorkflowStateCache.get("team-cache")
    WorkflowStateCache.delete("team-cache")
    assert :miss = WorkflowStateCache.get("team-cache")
  end

  test "workflow state cache ignores invalid inputs and can flush" do
    WorkflowStateCache.put(nil, %{})
    WorkflowStateCache.put("team-ignored", "invalid")
    assert :ok = WorkflowStateCache.delete(nil)
    assert :miss = WorkflowStateCache.get(nil)
    assert :miss = WorkflowStateCache.get("team-ignored")

    WorkflowStateCache.put("team-flush", %{"ok" => true})
    assert {:ok, %{"ok" => true}} = WorkflowStateCache.get("team-flush")
    WorkflowStateCache.flush()
    assert :miss = WorkflowStateCache.get("team-flush")
  end

  test "workflow state cache reset clears all entries" do
    WorkflowStateCache.put("team-reset", %{"ok" => true})
    assert {:ok, _} = WorkflowStateCache.get("team-reset")
    WorkflowStateCache.reset()
    assert :miss = WorkflowStateCache.get("team-reset")
  end

  defp insert_state(team_id, state_id, name) do
    Repo.insert!(%LinearWorkflowState{
      linear_team_id: team_id,
      linear_state_id: state_id,
      name: name,
      type: "unstarted",
      color: "#ffffff"
    })
  end

  defp insert_project(attrs) do
    %Project{}
    |> Project.changeset(attrs)
    |> Repo.insert!()
  end
end
