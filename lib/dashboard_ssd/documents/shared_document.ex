defmodule DashboardSSD.Documents.SharedDocument do
  @moduledoc """
  Schema + changeset helpers for documents surfaced in the Contracts & Docs flows.

  Stores canonical metadata for Drive/Notion artifacts so caches, download proxies,
  and LiveViews can rely on a single source of truth.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias DashboardSSD.Clients.Client
  alias DashboardSSD.Projects.Project
  alias DashboardSSD.Documents.DocumentAccessLog

  @primary_key {:id, :binary_id, autogenerate: true}

  @typedoc "Shared document metadata backed by the shared_documents table"
  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          client_id: integer() | nil,
          project_id: integer() | nil,
          source: :drive | :notion | nil,
          source_id: String.t() | nil,
          doc_type: String.t() | nil,
          title: String.t() | nil,
          description: String.t() | nil,
          visibility: :internal | :client | nil,
          client_edit_allowed: boolean(),
          mime_type: String.t() | nil,
          metadata: map(),
          etag: String.t() | nil,
          checksum: String.t() | nil,
          last_synced_at: DateTime.t() | nil
        }

  schema "shared_documents" do
    belongs_to :client, Client, foreign_key: :client_id, type: :id
    belongs_to :project, Project, foreign_key: :project_id, type: :id

    field :source, Ecto.Enum, values: [:drive, :notion]
    field :source_id, :string
    field :doc_type, :string
    field :title, :string
    field :description, :string
    field :visibility, Ecto.Enum, values: [:internal, :client], default: :internal
    field :client_edit_allowed, :boolean, default: false
    field :mime_type, :string
    field :metadata, :map, default: %{}
    field :etag, :string
    field :checksum, :string
    field :last_synced_at, :utc_datetime

    has_many :document_access_logs, DocumentAccessLog

    timestamps(type: :utc_datetime)
  end

  @required_fields [:client_id, :source, :source_id, :doc_type, :title, :visibility]
  @optional_fields [
    :project_id,
    :description,
    :client_edit_allowed,
    :mime_type,
    :metadata,
    :etag,
    :checksum,
    :last_synced_at
  ]

  @doc """
  Casts and validates shared document metadata.

  - Enforces presence of the required metadata (client/source/title/etc).
  - Restricts client-editable docs to Drive sources (Notion stays read-only).
  - Applies DB constraints for foreign keys + `{source, source_id}` uniqueness.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(shared_document, attrs) do
    shared_document
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_client_edit_flag()
    |> foreign_key_constraint(:client_id)
    |> foreign_key_constraint(:project_id)
    |> unique_constraint(:source_id, name: :shared_documents_source_source_id_index)
  end

  defp validate_client_edit_flag(changeset) do
    case {get_field(changeset, :client_edit_allowed), get_field(changeset, :source)} do
      {true, :drive} ->
        changeset

      {true, nil} ->
        # When source isn't set yet we let the required validation handle it.
        changeset

      {true, _source} ->
        add_error(changeset, :client_edit_allowed, "can only be enabled for Drive documents")

      _ ->
        changeset
    end
  end
end
