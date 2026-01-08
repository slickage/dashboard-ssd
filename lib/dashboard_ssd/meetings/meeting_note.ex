defmodule DashboardSSD.Meetings.MeetingNote do
  @moduledoc """
  Ecto schema for per-occurrence meeting notes aligned to a specific
  calendar event and local occurrence date.

  This stores normalized notes fetched from Fireflies (or other sources),
  keyed by `calendar_event_id` and `occurrence_date`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          calendar_event_id: String.t() | nil,
          recurring_series_id: String.t() | nil,
          occurrence_date: Date.t() | nil,
          transcript_id: String.t() | nil,
          accomplished: String.t() | nil,
          bullet_gist: String.t() | nil,
          action_items: list() | map() | nil,
          fetched_at: DateTime.t() | nil
        }

  schema "meeting_notes" do
    field :calendar_event_id, :string
    field :recurring_series_id, :string
    field :occurrence_date, :date
    field :transcript_id, :string
    field :accomplished, :string
    field :bullet_gist, :string
    field :action_items, :map
    field :fetched_at, :utc_datetime
    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(note, attrs) do
    attrs = normalize_action_items_attr(attrs)

    note
    |> cast(attrs, [
      :calendar_event_id,
      :recurring_series_id,
      :occurrence_date,
      :transcript_id,
      :accomplished,
      :bullet_gist,
      :action_items,
      :fetched_at
    ])
    |> validate_required([:calendar_event_id, :occurrence_date])
    |> unique_constraint(:calendar_event_id,
      name: :meeting_notes_calendar_event_id_occurrence_date_index
    )
  end

  defp normalize_action_items_attr(attrs) when is_map(attrs) do
    cond do
      is_list(Map.get(attrs, :action_items)) ->
        Map.put(attrs, :action_items, %{"items" => Map.get(attrs, :action_items)})

      is_list(Map.get(attrs, "action_items")) ->
        Map.put(attrs, "action_items", %{"items" => Map.get(attrs, "action_items")})

      true ->
        attrs
    end
  end

  defp normalize_action_items_attr(attrs), do: attrs
end

