defmodule DashboardSSD.Repo.Migrations.CreateFirefliesArtifacts do
  use Ecto.Migration

  def change do
    create table(:fireflies_artifacts) do
      add :recurring_series_id, :string, null: false
      add :transcript_id, :string
      add :accomplished, :text
      add :bullet_gist, :text
      add :action_items, :map
      add :fetched_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create unique_index(:fireflies_artifacts, [:recurring_series_id])
    create index(:fireflies_artifacts, [:transcript_id])
  end
end

