defmodule DashboardSSD.Meetings.NotesCoverageTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Meetings.{CacheStore, Notes, NotesStore}

  setup do
    on_exit(fn -> CacheStore.reset() end)
    CacheStore.reset()
    :ok
  end

  test "invalid event id returns {:error, :invalid_event_id} (hits line 60)" do
    event = %{id: 123, occurrence_date: ~D[2024-01-01]}
    assert {:error, :invalid_event_id} = Notes.get_or_fetch(event)
  end

  test "future event skips remote and returns :not_found (hits line 200)" do
    future_dt = DateTime.add(DateTime.utc_now(), 3600, :second)

    event = %{
      id: "evt-future",
      starts_at: future_dt,
      occurrence_date: DateTime.to_date(future_dt)
    }

    assert :not_found = Notes.get_or_fetch(event)
  end

  test "NotesStore normalizes action_items nil to [] (hits line 87)" do
    id = "evt-nil-items"
    date = ~D[2024-01-02]

    :ok =
      NotesStore.upsert(id, date, %{
        accomplished: nil,
        action_items: nil,
        bullet_gist: nil,
        transcript_id: nil,
        fetched_at: DateTime.utc_now()
      })

    assert {:ok, note} = NotesStore.get(id, date)
    assert note.action_items == []
  end

  test "NotesStore normalizes action_items map with items list (hits line 89)" do
    id = "evt-map-items"
    date = ~D[2024-01-03]

    :ok =
      NotesStore.upsert(id, date, %{
        accomplished: nil,
        action_items: %{"items" => ["a", "b"]},
        bullet_gist: nil,
        transcript_id: nil,
        fetched_at: DateTime.utc_now()
      })

    assert {:ok, note} = NotesStore.get(id, date)
    assert note.action_items == ["a", "b"]
  end
end
