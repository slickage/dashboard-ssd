defmodule DashboardSSD.Repo.Migrations.UpdateLinearTeamMembersIndex do
  use Ecto.Migration

  def change do
    drop_if_exists index(:linear_team_members, [:linear_user_id],
                     name: :linear_team_members_linear_user_id_index
                   )

    create unique_index(:linear_team_members, [:linear_team_id, :linear_user_id])
  end
end
