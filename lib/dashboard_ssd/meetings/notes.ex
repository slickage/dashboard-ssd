defmodule DashboardSSD.Meetings.Notes do
  @moduledoc """
  Orchestrates meeting notes retrieval for a specific event occurrence using
  cache → DB → remote (Fireflies) strategy. Supports batched retrieval.
  """

  alias DashboardSSD.Integrations.Fireflies
  alias DashboardSSD.Meetings.{CacheStore, NotesStore}

  @type event_map :: map()
  @type note_map :: %{
          accomplished: String.t() | nil,
          action_items: [String.t()],
          bullet_gist: String.t() | nil,
          transcript_id: String.t() | nil,
          fetched_at: DateTime.t() | nil
        }

  @doc """
  Retrieves notes for a single event occurrence.

  Expects an event map including at least `:id` and `:occurrence_date`. If
  `:occurrence_date` is not present, attempts to derive it from `:starts_at`
  (UTC date) as a best effort.
  """
  @spec get_or_fetch(event_map, keyword()) :: {:ok, note_map} | :not_found | {:error, term}
  def get_or_fetch(event, opts \\ []) when is_map(event) do
    with {:ok, event_id, date} <- event_id_and_date(event) do
      key = {:meeting_notes, event_id, date}

      case CacheStore.get(key) do
        {:ok, note} ->
          {:ok, note}

        :miss ->
          case NotesStore.get(event_id, date) do
            {:ok, note} ->
              CacheStore.put(key, note)
              {:ok, note}

            :not_found ->
              if Keyword.get(opts, :skip_remote, false) do
                :not_found
              else
                case Fireflies.fetch_notes_for_event(event, opts) do
                  {:ok, note} = ok ->
                    persist_and_cache(event, date, note)
                    ok

                  :not_found ->
                    :not_found

                  {:error, _} = err ->
                    err
                end
              end
          end
      end
    end
  end

  @doc """
  Retrieves notes for multiple events in a batch. Returns a map of
  `event_id => note_map` for the matched subset.
  """
  @spec get_or_fetch_many([event_map], keyword()) :: {:ok, map()} | {:error, term}
  def get_or_fetch_many(events, opts \\ []) when is_list(events) do
    # Partition cache hits and misses
    {hits, misses} =
      events
      |> Enum.reduce({%{}, []}, fn ev, {acc, missing} ->
        case event_id_and_date(ev) do
          {:ok, id, date} ->
            key = {:meeting_notes, id, date}

            case CacheStore.get(key) do
              {:ok, note} -> {Map.put(acc, id, note), missing}
              :miss -> {acc, [{id, date, ev} | missing]}
            end

          _ ->
            {acc, missing}
        end
      end)

    # Try DB for misses
    {db_hits, still_missing} =
      Enum.reduce(misses, {%{}, []}, fn {id, date, ev}, {acc, miss2} ->
        case NotesStore.get(id, date) do
          {:ok, note} ->
            CacheStore.put({:meeting_notes, id, date}, note)
            {Map.put(acc, id, note), miss2}

          :not_found ->
            {acc, [{id, date, ev} | miss2]}
        end
      end)

    remaining_events = Enum.map(still_missing, fn {_id, _date, ev} -> ev end)

    with {:ok, fetched_map} <-
           fetch_batch_and_persist(still_missing, remaining_events, opts) do
      {:ok, Map.merge(hits, Map.merge(db_hits, fetched_map))}
    end
  end

  # -- internals --

  defp event_id_and_date(event) do
    id = event[:id] || event["id"]
    date = event[:occurrence_date] || event["occurrence_date"] || derive_date(event)

    cond do
      is_binary(id) and match?(%Date{}, date) -> {:ok, id, date}
      not is_binary(id) -> {:error, :invalid_event_id}
      true -> {:error, :invalid_occurrence_date}
    end
  end

  defp derive_date(%{starts_at: %DateTime{} = dt}), do: DateTime.to_date(dt)
  defp derive_date(%{"starts_at" => %DateTime{} = dt}), do: DateTime.to_date(dt)
  defp derive_date(_), do: nil

  defp persist_and_cache(event, date, note) do
    id = event[:id] || event["id"]

    attrs = %{
      recurring_series_id: event[:recurring_series_id] || event["recurring_series_id"],
      transcript_id: note[:transcript_id] || note["transcript_id"],
      accomplished: note[:accomplished] || note["accomplished"],
      bullet_gist: note[:bullet_gist] || note["bullet_gist"],
      action_items: note[:action_items] || note["action_items"],
      fetched_at: note[:fetched_at] || note["fetched_at"] || DateTime.utc_now()
    }

    :ok = NotesStore.upsert(id, date, attrs)

    CacheStore.put({:meeting_notes, id, date}, %{
      accomplished: attrs.accomplished,
      action_items: List.wrap(attrs.action_items),
      bullet_gist: attrs.bullet_gist,
      transcript_id: attrs.transcript_id,
      fetched_at: attrs.fetched_at
    })
  end

  defp fetch_batch_and_persist([], _events, _opts), do: {:ok, %{}}

  defp fetch_batch_and_persist(still_missing, events, opts) do
    result =
      if Keyword.get(opts, :skip_remote, false) do
        {:ok, %{}}
      else
        Fireflies.fetch_notes_for_events(events, opts)
      end

    case result do
      {:ok, mapped} when is_map(mapped) ->
        Enum.each(still_missing, fn {id, date, ev} ->
          case Map.get(mapped, id) do
            nil -> :noop
            note -> persist_and_cache(ev, date, note)
          end
        end)

        {:ok, mapped}

      {:error, _} = err ->
        err
    end
  end
end
