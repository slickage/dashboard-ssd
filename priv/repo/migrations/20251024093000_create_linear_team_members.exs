defmodule DashboardSSD.Repo.Migrations.CreateLinearTeamMembers do
  use Ecto.Migration

  def change do
    create table(:linear_team_members, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :linear_team_id, :string, null: false
      add :linear_user_id, :string, null: false
      add :name, :string
      add :display_name, :string
      add :email, :string
      add :avatar_url, :string
      timestamps(type: :utc_datetime)
    end

    create unique_index(:linear_team_members, [:linear_user_id])
    create index(:linear_team_members, [:linear_team_id])
  end
end
