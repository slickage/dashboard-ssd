defmodule DashboardSSD.Meetings.AgendaItem do
  @moduledoc "Ecto schema for per-meeting agenda items (derived or manual)."
  use Ecto.Schema
  import Ecto.Changeset
  alias Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          calendar_event_id: String.t() | nil,
          position: non_neg_integer() | nil,
          text: String.t() | nil,
          requires_preparation: boolean() | nil,
          source: String.t() | nil
        }

  schema "agenda_items" do
    field :calendar_event_id, :string
    field :position, :integer, default: 0
    field :text, :string
    field :requires_preparation, :boolean, default: false
    field :source, :string
    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec changeset(t() | Changeset.t(), map()) :: Changeset.t()
  def changeset(item, attrs) do
    item
    |> cast(attrs, [:calendar_event_id, :position, :text, :requires_preparation, :source])
    |> validate_required([:calendar_event_id, :text])
    |> validate_inclusion(:source, ["manual", "derived"])
  end
end
