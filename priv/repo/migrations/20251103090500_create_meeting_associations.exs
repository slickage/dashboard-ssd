defmodule DashboardSSD.Repo.Migrations.CreateMeetingAssociations do
  use Ecto.Migration

  def change do
    create table(:meeting_associations) do
      add :calendar_event_id, :string, null: false
      add :recurring_series_id, :string
      add :origin, :string, null: false, default: "auto"
      add :persist_series, :boolean, null: false, default: false
      add :client_id, references(:clients, on_delete: :nilify_all)
      add :project_id, references(:projects, on_delete: :nilify_all)
      timestamps(type: :utc_datetime)
    end

    create index(:meeting_associations, [:calendar_event_id])
    create index(:meeting_associations, [:recurring_series_id])
    create constraint(:meeting_associations, :client_or_project_must_be_set,
             check: "(client_id IS NOT NULL) OR (project_id IS NOT NULL)"
           )
  end
end

