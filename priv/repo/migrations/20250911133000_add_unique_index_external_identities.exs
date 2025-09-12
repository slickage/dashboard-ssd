defmodule DashboardSSD.Repo.Migrations.AddUniqueIndexExternalIdentities do
  use Ecto.Migration

  def change do
    create unique_index(:external_identities, [:user_id, :provider])
  end
end
