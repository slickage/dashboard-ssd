defmodule DashboardSSD.Repo.Migrations.AddDriveFolderMetadataToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :drive_folder_id, :string
      add :drive_folder_sharing_inherited, :boolean, default: true, null: false
      add :drive_folder_last_permission_sync_at, :utc_datetime
    end

    create index(:projects, [:drive_folder_id])
  end
end
