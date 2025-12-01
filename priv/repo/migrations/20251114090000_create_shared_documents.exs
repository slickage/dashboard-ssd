defmodule DashboardSSD.Repo.Migrations.CreateSharedDocuments do
  use Ecto.Migration

  def change do
    create table(:shared_documents, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :client_id, references(:clients, on_delete: :delete_all, type: :bigint), null: false
      add :project_id, references(:projects, on_delete: :nilify_all, type: :bigint)

      add :source, :string, null: false
      add :source_id, :string, null: false
      add :doc_type, :string, null: false

      add :title, :string, null: false
      add :description, :text
      add :visibility, :string, null: false, default: "internal"
      add :client_edit_allowed, :boolean, null: false, default: false

      add :mime_type, :string
      add :metadata, :map, null: false, default: fragment("'{}'::jsonb")
      add :etag, :string
      add :checksum, :string
      add :last_synced_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:shared_documents, [:source, :source_id])
    create index(:shared_documents, [:client_id])
    create index(:shared_documents, [:project_id])
    create index(:shared_documents, [:visibility])
    create index(:shared_documents, [:doc_type])
  end
end
