defmodule DashboardSSD.Repo.Migrations.CreateDocumentAccessLogs do
  use Ecto.Migration

  def change do
    create table(:document_access_logs) do
      add :shared_document_id,
          references(:shared_documents, on_delete: :delete_all, type: :binary_id),
          null: false

      add :actor_id, references(:users, on_delete: :nilify_all, type: :bigint)
      add :action, :string, null: false
      add :context, :map, null: false, default: fragment("'{}'::jsonb")

      timestamps(updated_at: false, type: :utc_datetime)
    end

    create index(:document_access_logs, [:shared_document_id])
    create index(:document_access_logs, [:actor_id])
    create index(:document_access_logs, [:action])
  end
end
