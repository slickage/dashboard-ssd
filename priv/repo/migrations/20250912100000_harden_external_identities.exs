defmodule DashboardSSD.Repo.Migrations.HardenExternalIdentities do
  use Ecto.Migration

  def change do
    # Null out existing plaintext secrets to allow safe type change.
    execute("UPDATE external_identities SET token = NULL")
    execute("UPDATE external_identities SET refresh_token = NULL")

    # Change columns from text to bytea with explicit USING casts (PostgreSQL).
    execute("ALTER TABLE external_identities ALTER COLUMN token TYPE bytea USING token::bytea")

    execute(
      "ALTER TABLE external_identities ALTER COLUMN refresh_token TYPE bytea USING refresh_token::bytea"
    )

    create unique_index(:external_identities, [:provider, :provider_id])
  end
end
