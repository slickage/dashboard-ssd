defmodule DashboardSSD.Repo.Migrations.AddLinearUserLinks do
  use Ecto.Migration

  def change do
    create table(:linear_user_links) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :linear_user_id, :string, null: false
      add :linear_email, :string
      add :linear_name, :string
      add :linear_display_name, :string
      add :linear_avatar_url, :string
      add :auto_linked, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:linear_user_links, [:user_id])
    create unique_index(:linear_user_links, [:linear_user_id])
  end
end
