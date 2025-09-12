defmodule DashboardSSD.Repo.Migrations.CreateCoreTables do
  use Ecto.Migration

  def change do
    create table(:roles) do
      add :name, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:roles, [:name])

    create table(:users) do
      add :email, :string, null: false
      add :name, :string
      add :role_id, references(:roles, on_delete: :nilify_all, type: :bigint)
      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create index(:users, [:role_id])

    create table(:clients) do
      add :name, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create table(:projects) do
      add :name, :string, null: false
      add :client_id, references(:clients, on_delete: :delete_all, type: :bigint), null: false
      timestamps(type: :utc_datetime)
    end

    create index(:projects, [:client_id])

    create table(:external_identities) do
      add :user_id, references(:users, on_delete: :delete_all, type: :bigint), null: false
      add :provider, :string, null: false
      add :provider_id, :string
      add :token, :text
      add :refresh_token, :text
      add :expires_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create index(:external_identities, [:user_id])
    create index(:external_identities, [:provider])

    create table(:sows) do
      add :project_id, references(:projects, on_delete: :delete_all, type: :bigint), null: false
      add :name, :string, null: false
      add :drive_id, :string
      timestamps(type: :utc_datetime)
    end

    create index(:sows, [:project_id])

    create table(:change_requests) do
      add :project_id, references(:projects, on_delete: :delete_all, type: :bigint), null: false
      add :name, :string, null: false
      add :drive_id, :string
      timestamps(type: :utc_datetime)
    end

    create index(:change_requests, [:project_id])

    create table(:deployments) do
      add :project_id, references(:projects, on_delete: :delete_all, type: :bigint), null: false
      add :status, :string, null: false
      add :commit_sha, :string
      timestamps(type: :utc_datetime)
    end

    create index(:deployments, [:project_id])

    create table(:health_checks) do
      add :project_id, references(:projects, on_delete: :delete_all, type: :bigint), null: false
      add :status, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:health_checks, [:project_id])

    create table(:alerts) do
      add :project_id, references(:projects, on_delete: :delete_all, type: :bigint), null: false
      add :message, :text, null: false
      add :status, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:alerts, [:project_id])

    create table(:notification_rules) do
      add :project_id, references(:projects, on_delete: :delete_all, type: :bigint), null: false
      add :event_type, :string, null: false
      add :channel, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:notification_rules, [:project_id])

    create table(:metric_snapshots) do
      add :project_id, references(:projects, on_delete: :delete_all, type: :bigint), null: false
      add :type, :string, null: false
      add :value, :float, null: false
      add :inserted_at, :utc_datetime, null: false
    end

    create index(:metric_snapshots, [:project_id])

    create table(:audits) do
      add :user_id, references(:users, on_delete: :nilify_all, type: :bigint)
      add :action, :string, null: false
      add :details, :map
      add :inserted_at, :utc_datetime, null: false
    end

    create index(:audits, [:user_id])
  end
end
