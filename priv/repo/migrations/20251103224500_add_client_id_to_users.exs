defmodule DashboardSSD.Repo.Migrations.AddClientIdToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :client_id, references(:clients, on_delete: :nilify_all)
    end

    create index(:users, [:client_id])
  end
end
