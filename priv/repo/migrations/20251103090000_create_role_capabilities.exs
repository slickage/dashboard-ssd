defmodule DashboardSSD.Repo.Migrations.CreateRoleCapabilities do
  use Ecto.Migration

  def change do
    create table(:role_capabilities) do
      add :role_id, references(:roles, on_delete: :delete_all), null: false
      add :capability, :string, null: false
      add :granted_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:role_capabilities, [:role_id, :capability])
    create index(:role_capabilities, [:capability])
  end
end
