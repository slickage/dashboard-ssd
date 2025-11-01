defmodule DashboardSSD.Repo.Migrations.AddLinearMetadataToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :linear_project_id, :string
      add :linear_team_id, :string
      add :linear_team_name, :string
    end

    create unique_index(:projects, :linear_project_id, where: "linear_project_id IS NOT NULL")

    create table(:linear_workflow_states, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :linear_team_id, :string, null: false
      add :linear_state_id, :string, null: false
      add :name, :string, null: false
      add :type, :string
      add :color, :string
      timestamps()
    end

    create unique_index(:linear_workflow_states, :linear_state_id)
    create index(:linear_workflow_states, :linear_team_id)
  end
end
