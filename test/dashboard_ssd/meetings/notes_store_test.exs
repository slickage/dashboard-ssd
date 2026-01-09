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
