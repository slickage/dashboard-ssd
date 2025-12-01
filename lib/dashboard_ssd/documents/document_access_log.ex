defmodule DashboardSSD.Documents.DocumentAccessLog do
  @moduledoc """
  Audit log for document-related actions (downloads, permission updates, toggles).

  Each entry records which shared document it applies to, the actor (if any),
  the action enum, and arbitrary context metadata for downstream analytics/audits.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias DashboardSSD.Accounts.User
  alias DashboardSSD.Documents.SharedDocument

  @actions [
    :download,
    :open_in_source,
    :permissions_granted,
    :permissions_revoked,
    :visibility_changed
  ]

  @type action ::
          :download
          | :open_in_source
          | :permissions_granted
          | :permissions_revoked
          | :visibility_changed

  @typedoc "Immutable log entry tracking document interactions"
  @type t :: %__MODULE__{
          id: integer() | nil,
          shared_document_id: Ecto.UUID.t() | nil,
          shared_document: SharedDocument.t() | nil,
          actor_id: integer() | nil,
          actor: User.t() | nil,
          action: action() | nil,
          context: map(),
          inserted_at: DateTime.t() | nil
        }

  schema "document_access_logs" do
    belongs_to :shared_document, SharedDocument, type: :binary_id
    belongs_to :actor, User, foreign_key: :actor_id, type: :id

    field :action, Ecto.Enum, values: @actions
    field :context, :map, default: %{}

    timestamps(updated_at: false, type: :utc_datetime)
  end

  @required_fields [:shared_document_id, :action]
  @optional_fields [:actor_id, :context]

  @doc """
  Validates and persists audit entries for document interactions.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(access_log, attrs) do
    access_log
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> normalize_context()
    |> validate_change(:context, &ensure_map/2)
    |> foreign_key_constraint(:shared_document_id)
    |> foreign_key_constraint(:actor_id)
  end

  defp normalize_context(changeset) do
    current = get_field(changeset, :context)

    cond do
      Map.has_key?(changeset.changes, :context) and is_map(changeset.changes.context) ->
        changeset

      Map.has_key?(changeset.changes, :context) and is_nil(changeset.changes.context) ->
        put_change(changeset, :context, %{})

      is_nil(current) ->
        put_change(changeset, :context, %{})

      true ->
        changeset
    end
  end

  defp ensure_map(:context, value) when is_map(value), do: []
  defp ensure_map(:context, value), do: [context: "must be a map, got: #{inspect(value)}"]
end
