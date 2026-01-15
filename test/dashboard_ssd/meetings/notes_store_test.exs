defmodule DashboardSSD.Meetings.NotesStoreTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Meetings.{MeetingNote, NotesStore}
  alias DashboardSSD.Repo

  describe "get/2" do
    test "returns :not_found when no record exists" do
      assert :not_found == NotesStore.get("evt-none", ~D[2025-12-11])
    end

    test "returns normalized map when present" do
      {:ok, _} =
        %MeetingNote{}
        |> MeetingNote.changeset(%{
          calendar_event_id: "evt-1",
          occurrence_date: ~D[2025-12-11],
          action_items: ["A", "B"]
        })
        |> Repo.insert()

      assert {:ok, note} = NotesStore.get("evt-1", ~D[2025-12-11])
      assert note.action_items == ["A", "B"]
      assert note.accomplished == nil
    end

    test "normalizes nil action_items to empty list" do
      {:ok, _} =
        %MeetingNote{}
        |> MeetingNote.changeset(%{
          calendar_event_id: "evt-nil",
          occurrence_date: ~D[2025-12-20],
          action_items: nil
        })
        |> Repo.insert()

      assert {:ok, note} = NotesStore.get("evt-nil", ~D[2025-12-20])
      assert note.action_items == []
    end

    test "normalizes map with items key to list" do
      {:ok, _} =
        %MeetingNote{}
        |> MeetingNote.changeset(%{
          calendar_event_id: "evt-map",
          occurrence_date: ~D[2025-12-21],
          action_items: %{"items" => ["i1", "i2"]}
        })
        |> Repo.insert()

      assert {:ok, note} = NotesStore.get("evt-map", ~D[2025-12-21])
      assert note.action_items == ["i1", "i2"]
    end

    test "insert_all with nil action_items normalizes to []" do
      # Bypass changeset to write raw values
      Repo.insert_all("meeting_notes", [
        %{
          calendar_event_id: "evt-insert-nil",
          occurrence_date: ~D[2025-12-22],
          action_items: nil,
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }
      ])

      assert {:ok, note} = NotesStore.get("evt-insert-nil", ~D[2025-12-22])
      assert note.action_items == []
    end

    test "insert_all with items map normalizes to list" do
      Repo.insert_all("meeting_notes", [
        %{
          calendar_event_id: "evt-insert-map",
          occurrence_date: ~D[2025-12-23],
          action_items: %{"items" => ["m1", "m2"]},
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }
      ])

      assert {:ok, note} = NotesStore.get("evt-insert-map", ~D[2025-12-23])
      assert note.action_items == ["m1", "m2"]
    end
  end

  describe "upsert/3" do
    test "inserts when missing and normalizes action_items list" do
      assert :ok =
               NotesStore.upsert("evt-2", ~D[2025-12-12], %{
                 action_items: ["x", "y"],
                 bullet_gist: "gist"
               })

      assert {:ok, note} = NotesStore.get("evt-2", ~D[2025-12-12])
      assert note.action_items == ["x", "y"]
      assert note.bullet_gist == "gist"
    end

    test "updates existing occurrence notes" do
      # seed initial
      :ok =
        NotesStore.upsert("evt-3", ~D[2025-12-13], %{
          action_items: ["old"],
          accomplished: "old acc"
        })

      # update
      :ok =
        NotesStore.upsert("evt-3", ~D[2025-12-13], %{
          action_items: ["new-1", "new-2"],
          bullet_gist: "new gist"
        })

      assert {:ok, note} = NotesStore.get("evt-3", ~D[2025-12-13])
      assert note.action_items == ["new-1", "new-2"]
      assert note.bullet_gist == "new gist"
      # accomplished remains from previous record unless overwritten
      assert note.accomplished == "old acc"
    end

    test "persists recurring_series_id and transcript_id when provided" do
      :ok =
        NotesStore.upsert("evt-4", ~D[2025-12-14], %{
          recurring_series_id: "series-4",
          transcript_id: "tr-444"
        })

      rec =
        Repo.get_by!(MeetingNote,
          calendar_event_id: "evt-4",
          occurrence_date: ~D[2025-12-14]
        )

      assert rec.recurring_series_id == "series-4"
      assert rec.transcript_id == "tr-444"
    end
  end
end
