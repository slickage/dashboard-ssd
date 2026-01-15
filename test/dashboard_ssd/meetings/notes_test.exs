defmodule DashboardSSD.Meetings.NotesTest do
  use DashboardSSD.DataCase, async: false

  alias DashboardSSD.Meetings.{CacheStore, MeetingNote, Notes, NotesStore}
  alias DashboardSSD.Repo

  setup do
    prev = Application.get_env(:dashboard_ssd, :integrations)

    Application.put_env(
      :dashboard_ssd,
      :integrations,
      Keyword.merge(prev || [], fireflies_api_token: "tok")
    )

    CacheStore.reset()

    on_exit(fn ->
      if prev,
        do: Application.put_env(:dashboard_ssd, :integrations, prev),
        else: Application.delete_env(:dashboard_ssd, :integrations)

      CacheStore.reset()
    end)

    :ok
  end

  test "cache hit returns without calling HTTP" do
    date = ~D[2025-12-11]
    event = %{id: "evt-cache", occurrence_date: date}
    note = %{accomplished: "cached", action_items: ["X"], bullet_gist: nil, transcript_id: "t"}
    CacheStore.put({:meeting_notes, "evt-cache", date}, note)

    Tesla.Mock.mock(fn _ -> flunk("HTTP should not be invoked on cache hit") end)

    assert {:ok, ^note} = Notes.get_or_fetch(event)
  end

  test "DB hit fills cache and returns note" do
    date = ~D[2025-12-12]
    event = %{id: "evt-db", occurrence_date: date}

    :ok =
      NotesStore.upsert("evt-db", date, %{
        action_items: ["A"],
        accomplished: "from db",
        transcript_id: "t-db"
      })

    Tesla.Mock.mock(fn _ -> flunk("HTTP should not be invoked when DB has data") end)

    assert {:ok, %{accomplished: "from db", action_items: ["A"], transcript_id: "t-db"}} =
             Notes.get_or_fetch(event)

    assert {:ok, %{accomplished: "from db"}} =
             CacheStore.get({:meeting_notes, "evt-db", date})
  end

  test "remote fetch persists and caches for single event" do
    base = ~U[2025-12-13 10:00:00Z]

    event = %{
      id: "evt-remote",
      starts_at: base,
      ends_at: DateTime.add(base, 3600, :second),
      title: "Weekly"
    }

    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
        payload = if is_binary(body), do: Jason.decode!(body), else: body
        query = Map.get(payload, "query") || Map.get(payload, :query)

        if is_binary(query) and String.contains?(query, "query Transcripts(") do
          %Tesla.Env{
            status: 200,
            body: %{
              "data" => %{
                "transcripts" => [
                  %{
                    "id" => "t-r",
                    "title" => "Weekly",
                    "date" => DateTime.to_iso8601(base),
                    "summary" => %{"overview" => "remote-notes", "action_items" => ["R1", "R2"]}
                  }
                ]
              }
            }
          }
        else
          flunk("unexpected request: #{inspect(payload)}")
        end
    end)

    assert {:ok,
            %{accomplished: "remote-notes", action_items: ["R1", "R2"], transcript_id: "t-r"}} =
             Notes.get_or_fetch(event)

    # DB persisted
    rec =
      Repo.get_by!(MeetingNote,
        calendar_event_id: "evt-remote",
        occurrence_date: DateTime.to_date(base)
      )

    assert rec.transcript_id == "t-r"
    assert rec.action_items == %{"items" => ["R1", "R2"]}

    # Cache stored
    assert {:ok, %{accomplished: "remote-notes"}} =
             CacheStore.get({:meeting_notes, "evt-remote", DateTime.to_date(base)})
  end

  test "batched fetch persists and caches multiple events" do
    base = ~U[2025-12-14 12:00:00Z]
    ev1 = %{id: "evt-a", starts_at: base, ends_at: DateTime.add(base, 3600, :second), title: "A"}

    ev2 = %{
      id: "evt-b",
      starts_at: DateTime.add(base, 7200, :second),
      ends_at: DateTime.add(base, 10_800, :second),
      title: "B"
    }

    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
        payload = if is_binary(body), do: Jason.decode!(body), else: body
        query = Map.get(payload, "query") || Map.get(payload, :query)

        if is_binary(query) and String.contains?(query, "query Transcripts(") do
          %Tesla.Env{
            status: 200,
            body: %{
              "data" => %{
                "transcripts" => [
                  %{
                    "id" => "t-a",
                    "title" => "A",
                    "date" => DateTime.to_iso8601(base),
                    "summary" => %{"overview" => "A-notes", "action_items" => ["x"]}
                  },
                  %{
                    "id" => "t-b",
                    "title" => "B",
                    "date" => DateTime.to_iso8601(DateTime.add(base, 7200, :second)),
                    "summary" => %{"overview" => "B-notes", "action_items" => ["y"]}
                  }
                ]
              }
            }
          }
        else
          flunk("unexpected request: #{inspect(payload)}")
        end
    end)

    assert {:ok, map} = Notes.get_or_fetch_many([ev1, ev2])
    assert map["evt-a"].accomplished == "A-notes"
    assert map["evt-b"].accomplished == "B-notes"

    # DB checks
    assert Repo.get_by!(MeetingNote,
             calendar_event_id: "evt-a",
             occurrence_date: DateTime.to_date(base)
           )

    assert Repo.get_by!(MeetingNote,
             calendar_event_id: "evt-b",
             occurrence_date: DateTime.to_date(DateTime.add(base, 7200, :second))
           )
  end

  test "propagates rate limit error from remote and does not persist" do
    event = %{
      id: "evt-err",
      starts_at: ~U[2025-12-15 09:00:00Z],
      ends_at: ~U[2025-12-15 10:00:00Z],
      title: "X"
    }

    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql"} ->
        %Tesla.Env{status: 429, body: %{"errors" => [%{"message" => "rl"}]}}
    end)

    assert {:error, {:rate_limited, "rl"}} = Notes.get_or_fetch(event)
    refute Repo.get_by(MeetingNote, calendar_event_id: "evt-err")
  end

  test "subsequent get_or_fetch uses cache/DB and skips HTTP" do
    base = ~U[2025-12-16 15:00:00Z]

    event = %{
      id: "evt-cache-http",
      starts_at: base,
      ends_at: DateTime.add(base, 3600, :second),
      title: "Weekly"
    }

    # First call: seed via remote fetch
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
        payload = if is_binary(body), do: Jason.decode!(body), else: body
        query = Map.get(payload, "query") || Map.get(payload, :query)

        if is_binary(query) and String.contains?(query, "query Transcripts(") do
          %Tesla.Env{
            status: 200,
            body: %{
              "data" => %{
                "transcripts" => [
                  %{
                    "id" => "t-first",
                    "title" => "Weekly",
                    "date" => DateTime.to_iso8601(base),
                    "summary" => %{"overview" => "one", "action_items" => ["I1", "I2"]}
                  }
                ]
              }
            }
          }
        else
          flunk("unexpected request: #{inspect(payload)}")
        end
    end)

    assert {:ok, %{accomplished: "one", action_items: ["I1", "I2"]}} = Notes.get_or_fetch(event)

    # Second call: should hit cache/DB and not call HTTP
    Tesla.Mock.mock(fn _ -> flunk("HTTP should not be called after persistence") end)
    assert {:ok, %{accomplished: "one", action_items: ["I1", "I2"]}} = Notes.get_or_fetch(event)
  end

  test "get_or_fetch returns error for invalid event id" do
    event = %{id: 123, occurrence_date: ~D[2025-12-11]}
    assert {:error, :invalid_event_id} = Notes.get_or_fetch(event)
  end

  test "derive_date accepts string keys for starts_at" do
    base = ~U[2025-12-11 12:00:00Z]

    event = %{
      "id" => "evt-str",
      "starts_at" => base,
      "ends_at" => DateTime.add(base, 3600, :second)
    }

    Tesla.Mock.mock(fn _ -> flunk("HTTP should be skipped with skip_remote") end)
    assert :not_found == Notes.get_or_fetch(event, skip_remote: true)
  end

  test "get_or_fetch_many ignores events with invalid id/date and does not call HTTP" do
    bad = %{title: "Missing id and starts_at"}
    Tesla.Mock.mock(fn _ -> flunk("HTTP should not be called for invalid events") end)
    assert {:ok, %{}} = Notes.get_or_fetch_many([bad])
  end

  test "batch path propagates rate-limited error" do
    now = DateTime.utc_now()
    past = DateTime.add(now, -3600, :second)
    ev = %{id: "evt-rl-batch", starts_at: past, ends_at: now, title: "A"}

    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql"} ->
        %Tesla.Env{status: 429, body: %{"errors" => [%{"message" => "batch rl"}]}}
    end)

    assert {:error, {:rate_limited, "batch rl"}} = Notes.get_or_fetch_many([ev])
  end

  test "skips remote fetch for future event" do
    now = DateTime.utc_now()

    event = %{
      id: "evt-future",
      starts_at: DateTime.add(now, 3600, :second),
      ends_at: DateTime.add(now, 7200, :second),
      title: "Future Meeting"
    }

    Tesla.Mock.mock(fn _ -> flunk("HTTP should not be called for future events") end)
    assert :not_found == Notes.get_or_fetch(event)

    refute Repo.get_by(MeetingNote, calendar_event_id: "evt-future")
  end

  test "batch skips future events and returns only past mappings" do
    now = DateTime.utc_now()
    past = DateTime.add(now, -86_400, :second)

    ev_past = %{
      id: "evt-past",
      starts_at: past,
      ends_at: DateTime.add(past, 3600, :second),
      title: "Past"
    }

    ev_future = %{
      id: "evt-fut2",
      starts_at: DateTime.add(now, 7200, :second),
      ends_at: DateTime.add(now, 10_800, :second),
      title: "Future 2"
    }

    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
        payload = if is_binary(body), do: Jason.decode!(body), else: body
        query = Map.get(payload, "query") || Map.get(payload, :query)

        if is_binary(query) and String.contains?(query, "query Transcripts(") do
          %Tesla.Env{
            status: 200,
            body: %{
              "data" => %{
                "transcripts" => [
                  %{
                    "id" => "t-past",
                    "title" => "Past",
                    "date" => DateTime.to_iso8601(past),
                    "summary" => %{"overview" => "P", "action_items" => []}
                  }
                ]
              }
            }
          }
        else
          flunk("unexpected request: #{inspect(payload)}")
        end
    end)

    assert {:ok, map} = Notes.get_or_fetch_many([ev_past, ev_future])
    assert map["evt-past"].accomplished == "P"
    refute Map.has_key?(map, "evt-fut2")
  end

  test "get_or_fetch_many triggers invalid id branch in event_id_and_date (line 60)" do
    # One invalid event (non-binary id) and one valid event; skip remote to avoid HTTP
    now = DateTime.utc_now()
    past = DateTime.add(now, -3600, :second)
    bad = %{id: 123, occurrence_date: ~D[2025-12-22]}
    good = %{id: "evt-good", starts_at: past, ends_at: now, title: "Good"}

    # No HTTP should be called regardless
    Tesla.Mock.mock(fn _ -> flunk("HTTP should not be called in this test") end)

    # The invalid event hits event_id_and_date/1 cond branch (line 60) indirectly
    assert {:ok, map} = Notes.get_or_fetch_many([bad, good], skip_remote: true)
    # No notes returned since skip_remote and nothing in cache/DB
    assert map == %{}
  end
end
