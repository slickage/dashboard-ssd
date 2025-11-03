defmodule DashboardSSD.Repo.Migrations.CreateAgendaItems do
  use Ecto.Migration

  def change do
    create table(:agenda_items) do
      add :calendar_event_id, :string, null: false
      add :position, :integer, null: false, default: 0
      add :text, :text, null: false
      add :requires_preparation, :boolean, null: false, default: false
      add :source, :string, null: false, default: "manual"
      timestamps(type: :utc_datetime)
    end

    create index(:agenda_items, [:calendar_event_id])
  end
end

