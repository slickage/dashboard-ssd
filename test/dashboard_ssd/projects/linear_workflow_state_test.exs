defmodule DashboardSSD.Projects.LinearWorkflowStateTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Projects.LinearWorkflowState

  test "changeset requires mandatory fields" do
    changeset = LinearWorkflowState.changeset(%LinearWorkflowState{}, %{})
    refute changeset.valid?

    assert %{
             linear_team_id: ["can't be blank"],
             linear_state_id: ["can't be blank"],
             name: ["can't be blank"]
           } = errors_on(changeset)
  end

  test "changeset accepts valid attributes" do
    attrs = %{linear_team_id: "team-1", linear_state_id: "state-1", name: "Todo"}
    changeset = LinearWorkflowState.changeset(%LinearWorkflowState{}, attrs)
    assert changeset.valid?
  end
end
