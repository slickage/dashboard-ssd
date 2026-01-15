defmodule DashboardSSD.Integrations.FirefliesCoverageTest do
  use DashboardSSD.DataCase, async: false

  import Tesla.Mock
  require Logger

  alias DashboardSSD.Integrations.Fireflies
  alias DashboardSSD.Meetings.{CacheStore, FirefliesStore}

  setup_all do
    # Ensure a fake token is available for the client in tests
    Application.put_env(:dashboard_ssd, :integrations, fireflies_api_token: "test-token")
    :ok
  end

  setup do
    CacheStore.reset()
    on_exit(fn -> CacheStore.reset() end)
    :ok
  end

  test "fetch_latest_for_series logs debug and returns rate_limited via team fallback" do
    # Force Logger debug to execute the deferred debug fun inside fetch
    orig = Logger.level()
    Logger.configure(level: :debug)
    on_exit(fn -> Logger.configure(level: orig) end)

    series_id = "S-RL"

    mock_global(fn %Tesla.Env{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
      {q, v} =
        cond do
          is_binary(body) ->
            case Jason.decode(body) do
              {:ok, %{"query" => q, "variables" => v}} -> {q, v}
              {:ok, %{"query" => q}} -> {q, %{}}
              _ -> {"", %{}}
            end

          is_map(body) ->
            {Map.get(body, "query") || "", Map.get(body, "variables") || %{}}

          true ->
            {"", %{}}
        end

      cond do
        String.contains?(q, "query Bites(") and Map.get(v, "my_team") == true ->
          json(%{
            "errors" => [
              %{"extensions" => %{"code" => "too_many_requests"}, "message" => "Slow down"}
            ]
          })

        String.contains?(q, "query Bites(") and Map.get(v, "mine") == true ->
          json(%{"data" => %{"bites" => []}})

        true ->
          json(%{"data" => %{}})
      end
    end)

    assert {:error, {:rate_limited, "Slow down"}} = Fireflies.fetch_latest_for_series(series_id)
  end

  test "fetch_latest_for_series with cached mapping hits transcript summary and persists (items branch)" do
    series_id = "S-OK"
    tid = "T-OK"
    CacheStore.put({:series_map, series_id}, tid, :timer.hours(24))

    mock_global(fn %Tesla.Env{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
      q =
        case body do
          b when is_binary(b) ->
            case Jason.decode(b) do
              {:ok, m} -> Map.get(m, "query") || ""
              _ -> ""
            end

          m when is_map(m) ->
            Map.get(m, "query") || ""

          _ ->
            ""
        end

      if String.contains?(q, "query Transcript(") do
        json(%{
          "data" => %{
            "transcript" => %{
              "summary" => %{
                "action_items" => ["One", "Two"],
                "overview" => "Accomplished text",
                "bullet_gist" => "Bullet"
              }
            }
          }
        })
      else
        json(%{"data" => %{}})
      end
    end)

    assert {:ok, %{accomplished: "Accomplished text", action_items: ["One", "Two"]}} =
             Fireflies.fetch_latest_for_series(series_id)

    # Verify persisted via store (normalize list path exercised)
    assert {:ok, %{action_items: ["One", "Two"]}} = FirefliesStore.get(series_id)
  end

  test "search_and_map uses atom :created_from.id and transcript id present (filter and transcript_id match)" do
    series_id = "S-ATOM"

    mock_global(fn %Tesla.Env{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
      q =
        case body do
          b when is_binary(b) ->
            case Jason.decode(b) do
              {:ok, m} -> Map.get(m, "query") || ""
              _ -> ""
            end

          m when is_map(m) ->
            Map.get(m, "query") || ""

          _ ->
            ""
        end

      cond do
        String.contains?(q, "query Bites(") ->
          json(%{
            "data" => %{
              "bites" => [
                %{
                  "transcript_id" => nil,
                  "created_at" => "2024-01-01T00:00:00Z",
                  "created_from" => %{id: "NOPE"}
                },
                %{
                  transcript_id: "T-ATOM",
                  created_at: "2024-01-02T00:00:00Z",
                  created_from: %{id: series_id}
                }
              ]
            }
          })

        String.contains?(q, "query Transcript(") ->
          json(%{
            "data" => %{
              "transcript" => %{
                "summary" => %{"overview" => "Sum", "action_items" => [], "bullet_gist" => nil}
              }
            }
          })

        true ->
          json(%{"data" => %{}})
      end
    end)

    assert {:ok, %{accomplished: "Sum", action_items: []}} =
             Fireflies.fetch_latest_for_series(series_id)

    # Mapping cached
    assert {:ok, "T-ATOM"} = CacheStore.get({:series_map, series_id})
  end

  test "fetch_notes_for_event returns {:error, {:rate_limited, _}} when transcripts query is rate limited" do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    ev = %{id: "E-RL", title: "Weekly", starts_at: now, ends_at: DateTime.add(now, 1800, :second)}

    mock_global(fn %Tesla.Env{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
      q =
        case body do
          b when is_binary(b) ->
            case Jason.decode(b) do
              {:ok, m} -> Map.get(m, "query") || ""
              _ -> ""
            end

          m when is_map(m) ->
            Map.get(m, "query") || ""

          _ ->
            ""
        end

      if String.contains?(q, "query Transcripts(") do
        json(%{
          "errors" => [
            %{"extensions" => %{"code" => "too_many_requests"}, "message" => "Slow down"}
          ]
        })
      else
        json(%{"data" => %{}})
      end
    end)

    assert {:error, {:rate_limited, _}} = Fireflies.fetch_notes_for_event(ev)
  end

  test "fetch_notes_for_events maps one event to notes (meeting_link match, map put branch)" do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    ev = %{
      id: "E-MAP",
      title: "Sync",
      meeting_link: "https://meet.local/abc",
      starts_at: now,
      ends_at: DateTime.add(now, 3600, :second)
    }

    transcripts = [
      %{
        "id" => "T1",
        "title" => "Something",
        "date" => DateTime.to_iso8601(now),
        "meeting_link" => "https://meet.local/abc",
        "summary" => %{"action_items" => ["x"], "overview" => "Notes", "bullet_gist" => nil}
      },
      %{
        "id" => "T2",
        "title" => "Other",
        "date" => DateTime.to_iso8601(DateTime.add(now, 7200, :second)),
        "meeting_link" => "https://meet.local/other",
        "summary" => %{"action_items" => [], "overview" => nil, "bullet_gist" => nil}
      }
    ]

    mock_global(fn %Tesla.Env{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
      q =
        case body do
          b when is_binary(b) ->
            case Jason.decode(b) do
              {:ok, m} -> Map.get(m, "query") || ""
              _ -> ""
            end

          m when is_map(m) ->
            Map.get(m, "query") || ""

          _ ->
            ""
        end

      if String.contains?(q, "query Transcripts(") do
        json(%{"data" => %{"transcripts" => transcripts}})
      else
        json(%{"data" => %{}})
      end
    end)

    assert {:ok, %{"E-MAP" => %{accomplished: "Notes", action_items: ["x"]}}} =
             Fireflies.fetch_notes_for_events([ev])
  end

  test "fetch_notes_for_events returns {:error, :invalid_time} when events have no times" do
    assert {:error, :invalid_time} = Fireflies.fetch_notes_for_events([%{id: "E-NO-TIME"}], [])
  end

  test "closest_by_time selected when multiple transcripts with same link (covers float/ms/seconds date parsing too)" do
    # Build event and transcripts with same link but different date encodings
    ref = DateTime.utc_now() |> DateTime.truncate(:second)
    link = "https://meet.local/xyz"

    # Tms is closer than Tsec
    t_ms = DateTime.add(ref, 60, :second) |> DateTime.to_unix(:millisecond)
    t_sec = DateTime.add(ref, 3600, :second) |> DateTime.to_unix()
    # Make float slightly further than ms so ms wins
    t_float = (t_ms + 2000) * 1.0

    ev = %{
      id: "E-CL",
      title: "Sync",
      meeting_link: link,
      starts_at: ref,
      ends_at: DateTime.add(ref, 3600, :second)
    }

    transcripts = [
      %{
        "id" => "TF",
        "title" => "A",
        "date" => t_float,
        "meeting_link" => link,
        "summary" => %{"action_items" => [], "overview" => "F"}
      },
      %{
        "id" => "TM",
        "title" => "B",
        "date" => t_ms,
        "meeting_link" => link,
        "summary" => %{"action_items" => [], "overview" => "M"}
      },
      %{
        "id" => "TS",
        "title" => "C",
        "date" => t_sec,
        "meeting_link" => link,
        "summary" => %{"action_items" => [], "overview" => "S"}
      }
    ]

    mock_global(fn %Tesla.Env{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
      q =
        case body do
          b when is_binary(b) ->
            case Jason.decode(b) do
              {:ok, m} -> Map.get(m, "query") || ""
              _ -> ""
            end

          m when is_map(m) ->
            Map.get(m, "query") || ""

          _ ->
            ""
        end

      if String.contains?(q, "query Transcripts(") do
        json(%{"data" => %{"transcripts" => transcripts}})
      else
        json(%{"data" => %{}})
      end
    end)

    assert {:ok, %{"E-CL" => %{accomplished: "M"}}} = Fireflies.fetch_notes_for_events([ev])
  end

  test "no meeting_link falls back to time/title and returns :not_found" do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    ev = %{
      id: "E-NOLINK",
      title: "Sync",
      starts_at: now,
      ends_at: DateTime.add(now, 3600, :second)
    }

    mock_global(fn %Tesla.Env{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
      q =
        case body do
          b when is_binary(b) ->
            case Jason.decode(b) do
              {:ok, m} -> Map.get(m, "query") || ""
              _ -> ""
            end

          m when is_map(m) ->
            Map.get(m, "query") || ""

          _ ->
            ""
        end

      if String.contains?(q, "query Transcripts(") do
        json(%{"data" => %{"transcripts" => []}})
      else
        json(%{"data" => %{}})
      end
    end)

    assert :not_found = Fireflies.fetch_notes_for_event(ev)
  end

  test "meeting_link mismatch leads to :not_found (no candidates within 6h)" do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    ev = %{
      id: "E-NOMATCH",
      title: "Sync",
      meeting_link: "https://link/a",
      starts_at: now,
      ends_at: DateTime.add(now, 3600, :second)
    }

    far = DateTime.add(now, 10 * 24 * 3600, :second) |> DateTime.to_iso8601()

    transcripts = [
      %{
        "id" => "TX",
        "title" => "Other",
        "date" => far,
        "meeting_link" => "https://link/b",
        "summary" => %{"action_items" => [], "overview" => nil}
      }
    ]

    mock_global(fn %Tesla.Env{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
      q =
        case body do
          b when is_binary(b) ->
            case Jason.decode(b) do
              {:ok, m} -> Map.get(m, "query") || ""
              _ -> ""
            end

          m when is_map(m) ->
            Map.get(m, "query") || ""

          _ ->
            ""
        end

      if String.contains?(q, "query Transcripts(") do
        json(%{"data" => %{"transcripts" => transcripts}})
      else
        json(%{"data" => %{}})
      end
    end)

    assert :not_found = Fireflies.fetch_notes_for_event(ev)
  end
end
