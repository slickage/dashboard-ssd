defmodule DashboardSSD.Integrations.Fireflies do
  @moduledoc """
  Boundary for interacting with Fireflies.ai to retrieve meeting summaries and
  action items used by the Meetings feature.
  """

  require Logger
  alias DashboardSSD.Meetings.CacheStore
  alias DashboardSSD.Integrations.FirefliesClient
  alias DashboardSSD.Meetings.FirefliesStore

  @type artifacts :: %{
          accomplished: String.t() | nil,
          action_items: [String.t()]
        }

  @doc """
  Fetches the latest completed meeting artifacts for a given recurring series.
  Results are cached via `Meetings.CacheStore`.

  Strategy:
  - If a cached transcript mapping exists for the series, fetch its summary.
  - Otherwise, search recent bites for a `created_from.id` matching the
    `series_id`; if found, map and fetch its transcript summary.
  - As a fallback, optionally use a provided `:title` hint to select the most
    similar recent transcript and fetch its summary.

  Returns `{:ok, %{accomplished: text | nil, action_items: [String.t()]}}`.
  """
  @spec fetch_latest_for_series(String.t(), keyword()) :: {:ok, artifacts()} | {:error, term()}
  def fetch_latest_for_series(series_id, opts \\ []) when is_binary(series_id) do
    key = {:series_artifacts, series_id}
    # Default to 24h unless explicitly overridden
    ttl = Keyword.get(opts, :ttl, :timer.hours(24))

    CacheStore.fetch(key, fn ->
      Logger.debug(fn ->
        %{msg: "fireflies.fetch_latest_for_series/2", series_id: series_id}
        |> Jason.encode!()
      end)
      # Retrieval order: DB → API (ETS handled by CacheStore)
      case FirefliesStore.get(series_id) do
        {:ok, art} -> {:ok, art}
        :not_found -> do_fetch_latest_for_series(series_id, opts)
      end
    end, ttl: ttl)
  end

  @doc """
  Refreshes (invalidates cache) and refetches latest artifacts for a series.
  """
  @spec refresh_series(String.t(), keyword()) :: {:ok, artifacts()} | {:error, term()}
  def refresh_series(series_id, opts \\ []) when is_binary(series_id) do
    CacheStore.delete({:series_artifacts, series_id})
    fetch_latest_for_series(series_id, opts)
  end

  # ================= Internals =================

  defp do_fetch_latest_for_series(series_id, opts) do
    # 1) Try mapping cache
    case CacheStore.get({:series_map, series_id}) do
      {:ok, transcript_id} when is_binary(transcript_id) ->
        case fetch_summary_for_transcript(series_id, transcript_id) do
          {:ok, art} -> {:ok, art}
          _ -> search_and_map(series_id, opts)
        end

      _ ->
        search_and_map(series_id, opts)
    end
  end

  defp search_and_map(series_id, opts) do
    limit = Keyword.get(opts, :limit, 25)

    # 2) Prefer exact match via bites.created_from.id == series_id
    with {:ok, bites} <- FirefliesClient.list_bites(mine: true, limit: limit),
         {:ok, transcript_id} <- pick_bite_transcript_by_series(bites, series_id) do
      # Cache mapping and fetch
      CacheStore.put({:series_map, series_id}, transcript_id, :timer.hours(24))
      fetch_summary_for_transcript(series_id, transcript_id)
    else
      _ ->
        # Fallback to team bites
        case FirefliesClient.list_bites(my_team: true, limit: limit) do
          {:ok, bites2} ->
            case pick_bite_transcript_by_series(bites2, series_id) do
              {:ok, transcript_id} ->
                CacheStore.put({:series_map, series_id}, transcript_id, :timer.hours(24))
                fetch_summary_for_transcript(series_id, transcript_id)

              _ ->
                # 3) Fallback: try title hint against recent transcripts
                title = Keyword.get(opts, :title)
                fallback_by_title(series_id, title, limit)
            end

          _ ->
            title = Keyword.get(opts, :title)
            fallback_by_title(series_id, title, limit)
        end
    end
  end

  defp pick_bite_transcript_by_series(bites, series_id) when is_list(bites) do
    series_id = to_string(series_id)

    bites
    |> Enum.filter(fn b ->
      case Map.get(b, "created_from") do
        %{"id" => id} -> to_string(id) == series_id
        %{id: id} -> to_string(id) == series_id
        _ -> false
      end
    end)
    |> Enum.sort_by(fn b -> Map.get(b, "created_at") || Map.get(b, :created_at) || "" end, :desc)
    |> List.first()
    |> case do
      nil -> {:error, :not_found}
      b ->
        tid = Map.get(b, "transcript_id") || Map.get(b, :transcript_id)
        if is_binary(tid) and tid != "", do: {:ok, tid}, else: {:error, :no_transcript}
    end
  end

  defp fallback_by_title(series_id, nil, _limit), do: {:ok, %{accomplished: nil, action_items: []}}
  defp fallback_by_title(series_id, title, limit) when is_binary(title) do
    case FirefliesClient.list_transcripts(limit: limit) do
      {:ok, transcripts} when is_list(transcripts) and transcripts != [] ->
        case pick_best_title_match(transcripts, title) do
          {:ok, %{"id" => tid}} ->
            CacheStore.put({:series_map, series_id}, tid, :timer.hours(24))
            fetch_summary_for_transcript(series_id, tid)

          _ -> {:ok, %{accomplished: nil, action_items: []}}
        end

      _ -> {:ok, %{accomplished: nil, action_items: []}}
    end
  end

  defp pick_best_title_match(list, title) do
    norm_title = normalize(title)

    list
    |> Enum.map(fn t ->
      t_title = Map.get(t, "title") || Map.get(t, :title) || ""
      score = similarity(norm_title, normalize(to_string(t_title)))
      {score, t}
    end)
    |> Enum.sort_by(fn {score, _} -> score end, :desc)
    |> List.first()
    |> case do
      {score, t} when is_number(score) and score > 0 -> {:ok, t}
      _ -> {:error, :no_match}
    end
  end

  defp similarity(a, b) do
    a_tokens = tokens(a)
    b_tokens = tokens(b)
    inter = MapSet.size(MapSet.intersection(a_tokens, b_tokens))
    inter
  end

  defp tokens(s) do
    s
    |> String.replace(~r/[^a-z0-9\s]/, " ")
    |> String.split(~r/\s+/, trim: true)
    |> Enum.reject(&(&1 == ""))
    |> Enum.into(MapSet.new())
  end

  defp normalize(nil), do: ""
  defp normalize(s), do: s |> String.downcase() |> String.trim()

  defp fetch_summary_for_transcript(series_id, transcript_id) do
    case FirefliesClient.get_transcript_summary(transcript_id) do
      {:ok, %{notes: notes, action_items: items, bullet_gist: bullet}} ->
        # Only persist non-empty results
        if (is_binary(notes) and String.trim(notes) != "") or (is_list(items) and items != []) or (is_binary(bullet) and String.trim(bullet) != "") do
          :ok = FirefliesStore.upsert(series_id, %{transcript_id: transcript_id, accomplished: notes, action_items: items, bullet_gist: bullet})
        end
        {:ok, %{accomplished: notes, action_items: items || []}}

      {:error, _} = err -> err
      _ -> {:ok, %{accomplished: nil, action_items: []}}
    end
  end
end
