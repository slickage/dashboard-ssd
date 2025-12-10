defmodule DashboardSSD.Integrations.FirefliesBoundaryTest do
  use DashboardSSD.DataCase, async: false

  import Ecto.Query
  alias DashboardSSD.Integrations.Fireflies
  alias DashboardSSD.Meetings.{CacheStore, FirefliesArtifact}
  alias DashboardSSD.Repo

  setup do
    # Ensure token configured
    prev = Application.get_env(:dashboard_ssd, :integrations)

    Application.put_env(
      :dashboard_ssd,
      :integrations,
      Keyword.merge(prev || [], fireflies_api_token: "tok")
    )

    # Reset cache for deterministic tests
    CacheStore.reset()

    on_exit(fn ->
      if prev,
        do: Application.put_env(:dashboard_ssd, :integrations, prev),
        else: Application.delete_env(:dashboard_ssd, :integrations)

      CacheStore.reset()
    end)

    :ok
  end

  test "API fetch persists to DB and caches result" do
    series_id = "series-1"

    # Mock Fireflies GraphQL for bites and transcript summary
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
        payload = if is_binary(body), do: Jason.decode!(body), else: body
        query = Map.get(payload, :query) || Map.get(payload, "query")
        vars = Map.get(payload, :variables) || Map.get(payload, "variables") || %{}

        cond do
          is_binary(query) and String.contains?(query, "query Bites") ->
            %Tesla.Env{
              status: 200,
              body: %{
                "data" => %{
                  "bites" => [
                    %{
                      "id" => "b1",
                      "transcript_id" => "t1",
                      "created_at" => "2024-01-01T00:00:00Z",
                      "created_from" => %{"id" => series_id, "name" => "Weekly"}
                    }
                  ]
                }
              }
            }

          is_binary(query) and String.contains?(query, "query Transcript(") and
              (Map.get(vars, "transcriptId") == "t1" or Map.get(vars, :transcriptId) == "t1") ->
            %Tesla.Env{
              status: 200,
              body: %{
                "data" => %{
                  "transcript" => %{
                    "summary" => %{
                      "overview" => "Last meeting notes",
                      "action_items" => ["Do X"],
                      "bullet_gist" => "• Do X"
                    }
                  }
                }
              }
            }

          true ->
            flunk("unexpected request: #{inspect(body)}")
        end
    end)

    # First call should hit API, persist to DB, and cache result
    assert {:ok, %{accomplished: notes, action_items: items}} =
             Fireflies.fetch_latest_for_series(series_id, title: "Weekly")

    assert is_binary(notes) and String.contains?(notes, "Last meeting")
    assert items == ["Do X"]

    # Verify DB persisted
    rec =
      Repo.one(from a in FirefliesArtifact, where: a.recurring_series_id == ^series_id, limit: 1)

    assert rec && rec.transcript_id == "t1"
    assert rec.accomplished == notes
    assert rec.action_items == %{"items" => ["Do X"]}

    # Replace HTTP mock to ensure no further calls occur (cache hit expected)
    Tesla.Mock.mock(fn _ -> flunk("HTTP should not be called on cache hit") end)

    # Second call should return from cache (no HTTP)
    assert {:ok, %{accomplished: notes2, action_items: ["Do X"]}} =
             Fireflies.fetch_latest_for_series(series_id, title: "Weekly")

    assert notes2 == notes
  end

  test "DB fallback returns when cache empty without calling API" do
    series_id = "series-db"

    # Seed DB with an artifact
    {:ok, _rec} =
      %FirefliesArtifact{}
      |> FirefliesArtifact.changeset(%{
        recurring_series_id: series_id,
        transcript_id: "t-db",
        accomplished: "Persisted notes",
        action_items: ["A", "B"],
        bullet_gist: "• A\n• B",
        fetched_at: DateTime.utc_now()
      })
      |> Repo.insert()

    # Clear ETS cache to force DB read path
    CacheStore.flush()

    # Any HTTP call would be a failure here
    Tesla.Mock.mock(fn _ -> flunk("HTTP should not be called when DB has data") end)

    assert {:ok, %{accomplished: "Persisted notes", action_items: ["A", "B"]}} =
             Fireflies.fetch_latest_for_series(series_id, title: "Whatever")
  end

  test "rate limit propagates and does not persist" do
    series_id = "series-rl"

    Tesla.Mock.mock(fn %{method: :post, url: "https://api.fireflies.ai/graphql"} ->
      %Tesla.Env{
        status: 200,
        body: %{
          "data" => nil,
          "errors" => [
            %{
              "code" => "too_many_requests",
              "message" => "Too many requests. Please retry after 01:23:45 AM (UTC)",
              "extensions" => %{"code" => "too_many_requests", "status" => 429}
            }
          ]
        }
      }
    end)

    assert {:error, {:rate_limited, msg}} =
             Fireflies.fetch_latest_for_series(series_id, title: "Anything")

    assert String.contains?(msg, "Too many requests")
    # DB should not have an artifact inserted
    refute Repo.one(from a in FirefliesArtifact, where: a.recurring_series_id == ^series_id)
  end

  test "falls back to team bites when mine has no match and caches mapping" do
    series_id = "series-fb-team"

    Tesla.Mock.mock(fn %{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
      payload = if is_binary(body), do: Jason.decode!(body), else: body
      query = Map.get(payload, "query") || Map.get(payload, :query)
      vars = Map.get(payload, "variables") || %{}

      cond do
        # Important: my_team comes first because FirefliesClient defaults mine=true
        is_binary(query) and String.contains?(query, "query Bites") and vars["my_team"] == true ->
          %Tesla.Env{
            status: 200,
            body: %{
              "data" => %{
                "bites" => [
                  %{
                    "id" => "b-team",
                    "transcript_id" => "t-team",
                    "created_at" => "2024-02-01T00:00:00Z",
                    "created_from" => %{"id" => series_id}
                  }
                ]
              }
            }
          }

        is_binary(query) and String.contains?(query, "query Bites") and vars["mine"] == true ->
          # Mine path returns bites that don't match series
          %Tesla.Env{
            status: 200,
            body: %{
              "data" => %{
                "bites" => [
                  %{
                    "id" => "b-other",
                    "transcript_id" => "t-other",
                    "created_at" => "2024-01-01T00:00:00Z",
                    "created_from" => %{"id" => "series-other"}
                  }
                ]
              }
            }
          }

        is_binary(query) and String.contains?(query, "query Transcript(") ->
          %Tesla.Env{
            status: 200,
            body: %{
              "data" => %{
                "transcript" => %{
                  "summary" => %{
                    "overview" => "Team notes",
                    "action_items" => [],
                    "bullet_gist" => nil
                  }
                }
              }
            }
          }

        # Some code paths may still invoke transcripts search; return empty list
        is_binary(query) and String.contains?(query, "query Transcripts(") ->
          %Tesla.Env{status: 200, body: %{"data" => %{"transcripts" => []}}}

        true ->
          flunk("unexpected request: #{inspect(payload)}")
      end
    end)

    # Should succeed and cache mapping via team bites
    assert {:ok, _} = Fireflies.fetch_latest_for_series(series_id, title: "Weekly")

    # Mapping should be cached for future lookups
    assert {:ok, "t-team"} = CacheStore.get({:series_map, series_id})
  end

  test "fallback by title selects best transcript and caches mapping" do
    series_id = "series-fb-title"

    Tesla.Mock.mock(fn %{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
      payload = if is_binary(body), do: Jason.decode!(body), else: body
      query = Map.get(payload, "query") || Map.get(payload, :query)

      cond do
        is_binary(query) and String.contains?(query, "query Bites") ->
          # No bites for mine/team paths
          %Tesla.Env{status: 200, body: %{"data" => %{"bites" => []}}}

        is_binary(query) and String.contains?(query, "query Transcripts(") ->
          # Provide one with matching tokens
          %Tesla.Env{
            status: 200,
            body: %{
              "data" => %{
                "transcripts" => [
                  %{"id" => "tid1", "title" => "Some Other"},
                  %{"id" => "tid2", "title" => "Weekly Sync — Project"}
                ]
              }
            }
          }

        is_binary(query) and String.contains?(query, "query Transcript(") ->
          %Tesla.Env{
            status: 200,
            body: %{
              "data" => %{
                "transcript" => %{
                  "summary" => %{
                    "overview" => "Title notes",
                    "action_items" => ["Z"],
                    "bullet_gist" => nil
                  }
                }
              }
            }
          }

        true ->
          flunk("unexpected request: #{inspect(payload)}")
      end
    end)

    assert {:ok, %{accomplished: "Title notes", action_items: ["Z"]}} =
             Fireflies.fetch_latest_for_series(series_id, title: "Weekly Sync")

    assert {:ok, "tid2"} = CacheStore.get({:series_map, series_id})
  end

  test "fallback by title with nil returns empty artifacts" do
    series_id = "series-fb-empty"

    Tesla.Mock.mock(fn %{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
      payload = if is_binary(body), do: Jason.decode!(body), else: body
      query = Map.get(payload, "query") || Map.get(payload, :query)

      if is_binary(query) and String.contains?(query, "query Bites") do
        %Tesla.Env{status: 200, body: %{"data" => %{"bites" => []}}}
      else
        flunk("unexpected request: #{inspect(payload)}")
      end
    end)

    assert {:ok, %{accomplished: nil, action_items: []}} =
             Fireflies.fetch_latest_for_series(series_id, title: nil)
  end

  test "persists when only notes or only bullet gist present" do
    series_notes = "series-notes"
    series_bullet = "series-bullet"

    # Notes only
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
        payload = if is_binary(body), do: Jason.decode!(body), else: body
        query = Map.get(payload, "query") || Map.get(payload, :query)

        cond do
          is_binary(query) and String.contains?(query, "query Bites") ->
            %Tesla.Env{
              status: 200,
              body: %{
                "data" => %{
                  "bites" => [
                    %{
                      "id" => "b-n",
                      "transcript_id" => "t-n",
                      "created_at" => "2024-01-01T00:00:00Z",
                      "created_from" => %{"id" => series_notes}
                    }
                  ]
                }
              }
            }

          is_binary(query) and String.contains?(query, "query Transcript(") ->
            %Tesla.Env{
              status: 200,
              body: %{
                "data" => %{
                  "transcript" => %{
                    "summary" => %{
                      "overview" => "Only notes",
                      "action_items" => [],
                      "bullet_gist" => nil
                    }
                  }
                }
              }
            }

          true ->
            flunk("unexpected request: #{inspect(payload)}")
        end
    end)

    assert {:ok, %{accomplished: "Only notes", action_items: []}} =
             Fireflies.fetch_latest_for_series(series_notes, title: "X")

    # Bullet only
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
        payload = if is_binary(body), do: Jason.decode!(body), else: body
        query = Map.get(payload, "query") || Map.get(payload, :query)

        cond do
          is_binary(query) and String.contains?(query, "query Bites") ->
            %Tesla.Env{
              status: 200,
              body: %{
                "data" => %{
                  "bites" => [
                    %{
                      "id" => "b-b",
                      "transcript_id" => "t-b",
                      "created_at" => "2024-01-01T00:00:00Z",
                      "created_from" => %{"id" => series_bullet}
                    }
                  ]
                }
              }
            }

          is_binary(query) and String.contains?(query, "query Transcript(") ->
            %Tesla.Env{
              status: 200,
              body: %{
                "data" => %{
                  "transcript" => %{
                    "summary" => %{
                      "overview" => nil,
                      "action_items" => [],
                      "bullet_gist" => "• Only bullet"
                    }
                  }
                }
              }
            }

          true ->
            flunk("unexpected request: #{inspect(payload)}")
        end
    end)

    assert {:ok, %{accomplished: nil, action_items: []}} =
             Fireflies.fetch_latest_for_series(series_bullet, title: "Y")
  end

  test "refresh_series deletes cache and refetches" do
    series_id = "series-refresh"
    # Seed cache with stale value
    CacheStore.put(
      {:series_artifacts, series_id},
      %{accomplished: "stale", action_items: []},
      60_000
    )

    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
        payload = if is_binary(body), do: Jason.decode!(body), else: body
        query = Map.get(payload, "query") || Map.get(payload, :query)

        cond do
          is_binary(query) and String.contains?(query, "query Bites") ->
            %Tesla.Env{
              status: 200,
              body: %{
                "data" => %{
                  "bites" => [
                    %{
                      "id" => "b-r",
                      "transcript_id" => "t-r",
                      "created_at" => "2024-01-01T00:00:00Z",
                      "created_from" => %{"id" => series_id}
                    }
                  ]
                }
              }
            }

          is_binary(query) and String.contains?(query, "query Transcript(") ->
            %Tesla.Env{
              status: 200,
              body: %{
                "data" => %{
                  "transcript" => %{
                    "summary" => %{
                      "overview" => "fresh",
                      "action_items" => [],
                      "bullet_gist" => nil
                    }
                  }
                }
              }
            }

          true ->
            flunk("unexpected request: #{inspect(payload)}")
        end
    end)

    assert {:ok, %{accomplished: "fresh"}} = Fireflies.refresh_series(series_id, title: "Z")
  end

  test "mapping exists but transcript fetch fails; falls back to search and returns empty" do
    series_id = "series-map-fail"
    # Pretend we have a cached mapping first
    CacheStore.put({:series_map, series_id}, "tid-fail", :timer.minutes(5))

    Tesla.Mock.mock(fn %{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
      payload = if is_binary(body), do: Jason.decode!(body), else: body
      query = Map.get(payload, "query") || Map.get(payload, :query)

      cond do
        is_binary(query) and String.contains?(query, "query Transcript(") ->
          # Fail transcript summary -> triggers search_and_map path
          %Tesla.Env{status: 500, body: %{"error" => "boom"}}

        is_binary(query) and String.contains?(query, "query Bites") ->
          # Return no bites for mine and for team to force fallback_by_title
          %Tesla.Env{status: 200, body: %{"data" => %{"bites" => []}}}

        is_binary(query) and String.contains?(query, "query Transcripts(") ->
          # Title fallback but no results
          %Tesla.Env{status: 200, body: %{"data" => %{"transcripts" => []}}}

        true ->
          flunk("unexpected request: #{inspect(payload)}")
      end
    end)

    assert {:ok, %{accomplished: nil, action_items: []}} =
             Fireflies.fetch_latest_for_series(series_id, title: "Weekly")
  end

  test "transcript summary returns rate-limited error and bubbles up" do
    series_id = "series-rl"

    Tesla.Mock.mock(fn %{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
      payload = if is_binary(body), do: Jason.decode!(body), else: body
      query = Map.get(payload, "query") || Map.get(payload, :query)

      cond do
        is_binary(query) and String.contains?(query, "query Bites(") ->
          %Tesla.Env{
            status: 200,
            body: %{
              "data" => %{
                "bites" => [
                  %{
                    "id" => "b1",
                    "transcript_id" => "t1",
                    "created_at" => "2024-01-01T00:00:00Z",
                    "created_from" => %{"id" => series_id}
                  }
                ]
              }
            }
          }

        is_binary(query) and String.contains?(query, "query Transcript(") ->
          %Tesla.Env{
            status: 200,
            body: %{"errors" => [%{"code" => "too_many_requests", "message" => "slow down"}]}
          }

        true ->
          flunk("unexpected request: #{inspect(payload)}")
      end
    end)

    assert {:error, {:rate_limited, "slow down"}} =
             Fireflies.fetch_latest_for_series(series_id, title: "Weekly")
  end

  test "search_transcripts_by_title delegates to client" do
    Tesla.Mock.mock(fn %{method: :post, url: "https://api.fireflies.ai/graphql", body: _body} ->
      %Tesla.Env{status: 200, body: %{"data" => %{"transcripts" => []}}}
    end)

    assert {:ok, []} = Fireflies.search_transcripts_by_title("Weekly", limit: 1)
  end

  test "fallback_by_title picks best match, caches mapping, and returns persisted notes" do
    series_id = "series-best"

    Tesla.Mock.mock(fn %{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
      payload = if is_binary(body), do: Jason.decode!(body), else: body
      query = Map.get(payload, "query") || Map.get(payload, :query)

      cond do
        is_binary(query) and String.contains?(query, "query Bites") ->
          # No exact bites match; proceed to title search
          %Tesla.Env{status: 200, body: %{"data" => %{"bites" => []}}}

        is_binary(query) and String.contains?(query, "query Transcripts(") ->
          %Tesla.Env{
            status: 200,
            body: %{
              "data" => %{
                "transcripts" => [
                  %{"id" => "tid-z", "title" => "Weekly Sync – Zeta"},
                  %{"id" => "tid-y", "title" => "Other"}
                ]
              }
            }
          }

        is_binary(query) and String.contains?(query, "query Transcript(") ->
          %Tesla.Env{
            status: 200,
            body: %{
              "data" => %{
                "transcript" => %{
                  "summary" => %{
                    "overview" => "Picked",
                    "action_items" => [],
                    "bullet_gist" => nil
                  }
                }
              }
            }
          }

        true ->
          flunk("unexpected request: #{inspect(payload)}")
      end
    end)

    assert {:ok, %{accomplished: "Picked", action_items: []}} =
             Fireflies.fetch_latest_for_series(series_id, title: "Weekly Sync")

    assert {:ok, "tid-z"} = CacheStore.get({:series_map, series_id})
  end

  test "prefers latest mine bite by created_at and atom keys and fetches transcript" do
    series_id = "series-latest"

    Tesla.Mock.mock(fn %{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
      payload = if is_binary(body), do: Jason.decode!(body), else: body
      query = Map.get(payload, "query") || Map.get(payload, :query)

      cond do
        is_binary(query) and String.contains?(query, "query Bites(") and
            payload["variables"]["mine"] == true ->
          %Tesla.Env{
            status: 200,
            body: %{
              "data" => %{
                "bites" => [
                  %{
                    id: "b-old",
                    transcript_id: "t-old",
                    created_at: "2024-01-01T00:00:00Z",
                    created_from: %{id: series_id}
                  },
                  %{
                    id: "b-new",
                    transcript_id: "t-new",
                    created_at: "2025-01-01T00:00:00Z",
                    created_from: %{id: series_id}
                  }
                ]
              }
            }
          }

        is_binary(query) and String.contains?(query, "query Transcript(") ->
          %Tesla.Env{
            status: 200,
            body: %{
              "data" => %{
                "transcript" => %{"summary" => %{"overview" => "Latest", "action_items" => []}}
              }
            }
          }

        true ->
          flunk("unexpected request: #{inspect(payload)}")
      end
    end)

    assert {:ok, %{accomplished: "Latest"}} =
             Fireflies.fetch_latest_for_series(series_id, title: "X")
  end

  test "fallback_by_title with no best match returns empty artifacts" do
    series_id = "series-nomatch"

    Tesla.Mock.mock(fn %{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
      payload = if is_binary(body), do: Jason.decode!(body), else: body
      query = Map.get(payload, "query") || Map.get(payload, :query)

      cond do
        is_binary(query) and String.contains?(query, "query Bites") ->
          %Tesla.Env{status: 200, body: %{"data" => %{"bites" => []}}}

        is_binary(query) and String.contains?(query, "query Transcripts(") ->
          %Tesla.Env{
            status: 200,
            body: %{"data" => %{"transcripts" => [%{"id" => "t1", "title" => "Other"}]}}
          }

        true ->
          flunk("unexpected request: #{inspect(payload)}")
      end
    end)

    assert {:ok, %{accomplished: nil, action_items: []}} =
             Fireflies.fetch_latest_for_series(series_id, title: "No Similar Title")
  end
end
