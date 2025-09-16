defmodule DashboardSSD.Repo.Migrations.CreateHealthCheckSettings do
  use Ecto.Migration

  def change do
    create table(:health_check_settings) do
      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :provider, :string
      add :endpoint_url, :string
      add :aws_region, :string
      add :aws_target_group_arn, :string
      add :enabled, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:health_check_settings, [:project_id])
  end
end
