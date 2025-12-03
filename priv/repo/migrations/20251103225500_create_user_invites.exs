defmodule DashboardSSD.Repo.Migrations.CreateUserInvites do
  use Ecto.Migration

  def change do
    create table(:user_invites) do
      add :email, :string, null: false
      add :token, :string, null: false
      add :role_name, :string, null: false
      add :client_id, references(:clients, on_delete: :nilify_all)
      add :invited_by_id, references(:users, on_delete: :nilify_all)
      add :used_at, :utc_datetime
      add :accepted_user_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_invites, [:token])
    create index(:user_invites, [:email])
  end
end
