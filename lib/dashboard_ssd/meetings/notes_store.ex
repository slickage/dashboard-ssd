defmodule DashboardSSD.Meetings.NotesStore do
  @moduledoc """
  Persistence helpers for per-occurrence meeting notes.

  Keyed by `calendar_event_id` and `occurrence_date`. Use with
  `DashboardSSD.Meetings.MeetingNote`.
  """

  import Ecto.Query
  alias DashboardSSD.Meetings.MeetingNote
  alias DashboardSSD.Repo

  @type note_map :: %{
          accomplished: String.t() | nil,
          action_items: [String.t()],
          bullet_gist: String.t() | nil,
          transcript_id: String.t() | nil,
          fetched_at: DateTime.t() | nil
        }

  @doc """
  Retrieves meeting notes for an event occurrence by event id and date.

  Returns `{:ok, note_map}` when present or `:not_found` otherwise.
  """
  @spec get(String.t(), Date.t()) :: {:ok, note_map()} | :not_found
  def get(event_id, %Date{} = date) when is_binary(event_id) do
    case Repo.one(
           from n in MeetingNote,
             where:
               n.calendar_event_id == ^event_id and
                 n.occurrence_date == ^date,
             limit: 1
         ) do
      %MeetingNote{} = rec -> {:ok, to_public(rec)}
      _ -> :not_found
    end
  end

  @doc """
  Inserts or updates meeting notes for an event occurrence.

  Automatically stamps `fetched_at` when not provided.
  Always returns `:ok` after attempting the write.
  """
  @spec upsert(String.t(), Date.t(), map()) :: :ok
  def upsert(event_id, %Date{} = date, attrs)
      when is_binary(event_id) and is_map(attrs) do
    attrs =
      attrs
      |> Map.put(:calendar_event_id, event_id)
      |> Map.put(:occurrence_date, date)
      |> Map.put(:fetched_at, Map.get(attrs, :fetched_at) || DateTime.utc_now())

    case Repo.get_by(MeetingNote,
           calendar_event_id: event_id,
           occurrence_date: date
         ) do
      nil ->
        %MeetingNote{}
        |> MeetingNote.changeset(attrs)
        |> Repo.insert()
        :ok

      %MeetingNote{} = rec ->
        rec
        |> MeetingNote.changeset(attrs)
        |> Repo.update()
        :ok
    end
  end

  # -- helpers --

  defp to_public(%MeetingNote{} = rec) do
    %{
      accomplished: rec.accomplished,
      action_items: normalize_items(rec.action_items),
      bullet_gist: rec.bullet_gist,
      transcript_id: rec.transcript_id,
      fetched_at: rec.fetched_at
    }
  end

  defp normalize_items(nil), do: []
  defp normalize_items(items) when is_list(items), do: items
  defp normalize_items(%{"items" => l}) when is_list(l), do: l
  defp normalize_items(_), do: []
end

