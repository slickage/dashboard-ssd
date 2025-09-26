defmodule DashboardSSD.Repo.Migrations.AllowNullClientOnProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      modify :client_id, :bigint, null: true
    end
  end
end
