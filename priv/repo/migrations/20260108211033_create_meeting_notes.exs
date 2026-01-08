defmodule DashboardSSD.Repo.Migrations.CreateMeetingNotes do
  use Ecto.Migration

  def change do
    create table(:meeting_notes) do
      add :calendar_event_id, :string, null: false
      add :recurring_series_id, :string
      add :occurrence_date, :date, null: false
      add :transcript_id, :string
      add :accomplished, :text
      add :bullet_gist, :text
      add :action_items, :map
      add :fetched_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create unique_index(:meeting_notes, [:calendar_event_id, :occurrence_date])
    create index(:meeting_notes, [:recurring_series_id, :occurrence_date])
  end
end
