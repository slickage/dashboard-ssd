defmodule DashboardSSD.Integrations.Fireflies do
  @moduledoc """
  Boundary for interacting with Fireflies.ai to retrieve meeting summaries and
  action items used by the Meetings feature.
  """

  require Logger
  alias DashboardSSD.Integrations.FirefliesClient
  alias DashboardSSD.Meetings.CacheStore
  alias DashboardSSD.Meetings.FirefliesStore

  @type artifacts :: %{
          accomplished: String.t() | nil,
          action_items: [String.t()] | String.t()
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

    CacheStore.fetch(
      key,
      fn ->
        Logger.debug(fn ->
          %{msg: "fireflies.fetch_latest_for_series/2", series_id: series_id}
          |> Jason.encode!()
        end)

        # Retrieval order: DB → API (ETS handled by CacheStore)
        result =
          case FirefliesStore.get(series_id) do
            {:ok, art} -> {:ok, art}
            :not_found -> do_fetch_latest_for_series(series_id, opts)
          end

        case result do
          {:error, _} = err -> err
          {:rate_limited, _} = rl -> {:error, rl}
          other -> other
        end
      end,
      ttl: ttl
    )
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
      {:error, {:rate_limited, _} = rl} ->
        rl

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

          {:error, {:rate_limited, _} = rl} ->
            rl

          _ ->
            title = Keyword.get(opts, :title)
            fallback_by_title(series_id, title, limit)
        end
    end
  end

  defp pick_bite_transcript_by_series(bites, series_id) when is_list(bites) do
    series = to_string(series_id)

    bites
    |> filter_bites_by_series(series)
    |> latest_bite()
    |> transcript_id_of_bite()
  end

  defp filter_bites_by_series(bites, series) do
    Enum.filter(bites, fn b ->
      id =
        case Map.get(b, "created_from") || Map.get(b, :created_from) do
          %{"id" => v} -> v
          %{id: v} -> v
          _ -> nil
        end

      to_string(id) == series
    end)
  end

  defp latest_bite([]), do: nil

  defp latest_bite(bites) do
    Enum.sort_by(
      bites,
      fn b -> Map.get(b, "created_at") || Map.get(b, :created_at) || "" end,
      :desc
    )
    |> List.first()
  end

  defp transcript_id_of_bite(nil), do: {:error, :not_found}

  defp transcript_id_of_bite(b) do
    tid = Map.get(b, "transcript_id") || Map.get(b, :transcript_id)

    case tid do
      t when is_binary(t) and t != "" -> {:ok, t}
      _ -> {:error, :no_transcript}
    end
  end

  defp fallback_by_title(_series_id, nil, _limit),
    do: {:ok, %{accomplished: nil, action_items: []}}

  defp fallback_by_title(series_id, title, limit) when is_binary(title) do
    case FirefliesClient.list_transcripts(keyword: title, limit: limit) do
      {:ok, transcripts} when is_list(transcripts) and transcripts != [] ->
        case pick_best_title_match(transcripts, title) do
          {:ok, %{"id" => tid}} ->
            CacheStore.put({:series_map, series_id}, tid, :timer.hours(24))
            fetch_summary_for_transcript(series_id, tid)

          _ ->
            {:ok, %{accomplished: nil, action_items: []}}
        end

      {:error, {:rate_limited, _} = rl} ->
        rl

      _ ->
        {:ok, %{accomplished: nil, action_items: []}}
    end
  end

  @doc """
  Search transcripts by meeting title using Fireflies' keyword search.

  Options:
    * `:scope` - one of "TITLE" | "SENTENCES" | "ALL" (defaults to "TITLE")
    * `:from_date`, `:to_date` - ISO8601 datetimes to narrow time window
    * `:participants`, `:organizers` - lists of emails to filter attendees
    * `:limit` - max results (server max 50)
    * `:skip` - pagination offset
  """
  @spec search_transcripts_by_title(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def search_transcripts_by_title(title, opts \\ []) when is_binary(title) do
    FirefliesClient.list_transcripts(Keyword.merge(opts, keyword: title))
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

  defp normalize(s), do: s |> String.downcase() |> String.trim()

  defp fetch_summary_for_transcript(series_id, transcript_id) do
    case FirefliesClient.get_transcript_summary(transcript_id) do
      {:ok, %{notes: notes, action_items: items, bullet_gist: bullet}} ->
        norm_items = normalize_items_to_list(items)
        persist_artifacts_if_present(series_id, transcript_id, notes, norm_items, bullet)
        {:ok, %{accomplished: notes, action_items: norm_items}}

      {:error, {:rate_limited, _} = rl} ->
        rl

      {:error, _} = err ->
        err
    end
  end

  @dialyzer {:nowarn_function, normalize_items_to_list: 1}
  defp normalize_items_to_list(items) when is_list(items), do: items

  defp normalize_items_to_list(items) when is_binary(items) do
    items
    |> String.split(["\r\n", "\n"], trim: true)
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_items_to_list(_), do: []

  defp persist_artifacts_if_present(series_id, transcript_id, notes, items, bullet) do
    case {notes, items, bullet} do
      {_, l, _} when is_list(l) and l != [] ->
        :ok =
          FirefliesStore.upsert(series_id, %{
            transcript_id: transcript_id,
            accomplished: notes,
            action_items: items,
            bullet_gist: bullet
          })

      {n, _, _} when is_binary(n) and n != "" ->
        :ok =
          FirefliesStore.upsert(series_id, %{
            transcript_id: transcript_id,
            accomplished: notes,
            action_items: items,
            bullet_gist: bullet
          })

      {_, _, b} when is_binary(b) and b != "" ->
        :ok =
          FirefliesStore.upsert(series_id, %{
            transcript_id: transcript_id,
            accomplished: notes,
            action_items: items,
            bullet_gist: bullet
          })

      _ ->
        :ok
    end
  end

  # ================= Per-event and batched notes =================

  @doc """
  Fetch notes for a specific meeting occurrence (by event map).

  The `event` map should include keys:
    * `:id` - calendar event id (string)
    * `:starts_at`, `:ends_at` - DateTime.t()
    * `:title` - meeting title (string, optional but recommended)
    * `:participants` - [email] (optional)
    * `:meeting_link` - URL (optional; used for exact match when present)

  Returns `{:ok, %{accomplished, action_items, bullet_gist, transcript_id}}`,
  `:not_found`, or `{:error, term}`.
  """
  @spec fetch_notes_for_event(map(), keyword()) ::
          {:ok,
           %{
             accomplished: String.t() | nil,
             action_items: [String.t()],
             bullet_gist: String.t() | nil,
             transcript_id: String.t() | nil
           }}
          | :not_found
          | {:error, term()}
  def fetch_notes_for_event(event, opts \\ []) when is_map(event) do
    with {:ok, from_iso, to_iso} <- time_window_iso(event, opts),
         {:ok, transcripts} <-
           FirefliesClient.list_transcripts(
             Keyword.merge(
               [
                 from_date: from_iso,
                 to_date: to_iso,
                 limit: Keyword.get(opts, :limit, 50)
               ],
               participants_filter(event)
             )
           ) do
      case select_transcript_for_event(event, transcripts) do
        {:ok, t} -> {:ok, normalize_transcript_summary(t)}
        :not_found -> :not_found
      end
    else
      {:error, {:rate_limited, _} = rl} -> {:error, rl}
      {:error, _} = err -> err
    end
  end

  @doc """
  Batch version for a list of events. Performs a single transcripts query for the
  window spanning all events, then maps results locally.

  Returns `{:ok, %{event_id => note_map}}` for the matched subset.
  """
  @spec fetch_notes_for_events([map()], keyword()) :: {:ok, map()} | {:error, term()}
  def fetch_notes_for_events(events, opts \\ []) when is_list(events) do
    with {:ok, from_iso, to_iso} <- time_window_for_events(events, opts),
         {:ok, transcripts} <-
           FirefliesClient.list_transcripts(
             from_date: from_iso,
             to_date: to_iso,
             limit: Keyword.get(opts, :limit, 200)
           ) do
      {:ok, map_events_to_notes(events, transcripts)}
    end
  end

  defp map_events_to_notes(events, transcripts) do
    Enum.reduce(events, %{}, fn ev, acc ->
      case select_transcript_for_event(ev, transcripts) do
        {:ok, t} -> Map.put(acc, ev[:id] || ev["id"], normalize_transcript_summary(t))
        :not_found -> acc
      end
    end)
  end

  # -- selection helpers --

  defp participants_filter(%{participants: ps}) when is_list(ps) and ps != [] do
    [participants: Enum.filter(ps, &is_binary/1)]
  end

  defp participants_filter(_), do: []

  defp time_window_iso(%{starts_at: s, ends_at: e}, opts) do
    pad_secs = Keyword.get(opts, :pad_seconds, 300)

    with {:ok, s2} <- shift_seconds(s, -pad_secs),
         {:ok, e2} <- shift_seconds(e, pad_secs) do
      {:ok, DateTime.to_iso8601(s2), DateTime.to_iso8601(e2)}
    else
      _ -> {:error, :invalid_time}
    end
  end

  defp time_window_iso(_, _), do: {:error, :invalid_time}

  defp time_window_for_events(events, opts) do
    pad_secs = Keyword.get(opts, :pad_seconds, 300)

    times =
      events
      |> Enum.flat_map(fn ev ->
        [ev[:starts_at] || ev["starts_at"], ev[:ends_at] || ev["ends_at"]]
      end)
      |> Enum.filter(&match?(%DateTime{}, &1))

    case times do
      [] ->
        {:error, :invalid_time}

      _ ->
        min_t = Enum.min(times, DateTime)
        max_t = Enum.max(times, DateTime)

        with {:ok, s2} <- shift_seconds(min_t, -pad_secs),
             {:ok, e2} <- shift_seconds(max_t, pad_secs) do
          {:ok, DateTime.to_iso8601(s2), DateTime.to_iso8601(e2)}
        else
          _ -> {:error, :invalid_time}
        end
    end
  end

  defp shift_seconds(%DateTime{} = dt, sec) when is_integer(sec) do
    {:ok, DateTime.add(dt, sec, :second)}
  end

  defp select_transcript_for_event(event, transcripts) when is_list(transcripts) do
    link = event[:meeting_link] || event["meeting_link"]

    case pick_by_meeting_link(event, link, transcripts) do
      {:ok, by_link} -> {:ok, by_link}
      _ -> pick_by_time_and_title(event, transcripts)
    end
  end

  defp pick_by_meeting_link(_event, nil, _), do: {:error, :no_link}
  defp pick_by_meeting_link(_event, "", _), do: {:error, :no_link}

  defp pick_by_meeting_link(event, link, transcripts) do
    matches =
      transcripts
      |> Enum.filter(fn t ->
        (Map.get(t, "meeting_link") || Map.get(t, :meeting_link)) == link
      end)

    case matches do
      [] -> {:error, :not_found}
      [_one] -> {:ok, List.first(matches)}
      many -> {:ok, closest_by_time(many, event_start(event))}
    end
  end

  defp pick_by_time_and_title(event, transcripts) do
    start = event_start(event)
    title = event[:title] || event["title"] || ""

    candidates =
      transcripts
      |> Enum.map(fn t ->
        {t, transcript_time(t), title_similarity(title, t)}
      end)
      |> Enum.reject(fn {_t, tdt, _score} -> is_nil(tdt) end)

    case candidates do
      [] ->
        :not_found

      list ->
        {best, best_dt, _score} =
          list
          |> Enum.min_by(fn {_t, tdt, _} -> abs_diff_sec(start, tdt) end)

        # Basic sanity threshold: 6 hours by default
        if abs_diff_sec(start, best_dt) <= 6 * 3600 do
          {:ok, best}
        else
          :not_found
        end
    end
  end

  defp event_start(ev), do: ev[:starts_at] || ev["starts_at"]

  defp transcript_time(%{"date" => d}), do: parse_transcript_date(d)
  defp transcript_time(%{date: d}), do: parse_transcript_date(d)
  defp transcript_time(_), do: nil

  defp parse_transcript_date(iso) when is_binary(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp parse_transcript_date(ts) when is_integer(ts) do
    if ts > 9_999_999_999 do
      case DateTime.from_unix(ts, :millisecond) do
        {:ok, dt} -> dt
        _ -> nil
      end
    else
      case DateTime.from_unix(ts) do
        {:ok, dt} -> dt
        _ -> nil
      end
    end
  end

  defp parse_transcript_date(ts) when is_float(ts), do: parse_transcript_date(round(ts))
  defp parse_transcript_date(_), do: nil

  defp title_similarity(title, t) do
    t_title = Map.get(t, "title") || Map.get(t, :title) || ""
    similarity(normalize(title), normalize(to_string(t_title)))
  end

  defp abs_diff_sec(%DateTime{} = a, %DateTime{} = b) do
    abs(DateTime.diff(a, b, :second))
  end

  defp closest_by_time(list, %DateTime{} = ref) do
    list
    |> Enum.min_by(fn t ->
      case transcript_time(t) do
        %DateTime{} = dt -> abs(DateTime.diff(dt, ref, :second))
        _ -> 1_000_000_000
      end
    end)
  end

  defp normalize_transcript_summary(t) when is_map(t) do
    sum = Map.get(t, "summary") || Map.get(t, :summary) || %{}
    items = Map.get(sum, "action_items") || Map.get(sum, :action_items) || []
    notes = Map.get(sum, "overview") || Map.get(sum, :overview) || Map.get(sum, "short_summary")
    bullet = Map.get(sum, "bullet_gist") || Map.get(sum, :bullet_gist)

    %{
      accomplished: notes,
      action_items: normalize_items_to_list(items),
      bullet_gist: bullet,
      transcript_id: Map.get(t, "id") || Map.get(t, :id)
    }
  end
end
