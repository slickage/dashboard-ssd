defmodule DashboardSSD.Meetings.MeetingNoteTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Repo
  alias DashboardSSD.Meetings.MeetingNote

  describe "changeset/2 validations" do
    test "requires calendar_event_id and occurrence_date" do
      cs = MeetingNote.changeset(%MeetingNote{}, %{})
      refute cs.valid?

      assert %{calendar_event_id: ["can't be blank"], occurrence_date: ["can't be blank"]} =
               errors_on(cs)
    end
  end

  describe "insert + normalization" do
    test "normalizes action_items list to map with items key" do
      attrs = %{
        calendar_event_id: "evt-1",
        occurrence_date: ~D[2025-12-11],
        action_items: ["do X", "do Y"],
        accomplished: "done",
        bullet_gist: "gist"
      }

      assert {:ok, rec} =
               %MeetingNote{}
               |> MeetingNote.changeset(attrs)
               |> Repo.insert()

      # Stored as map
      assert %{"items" => ["do X", "do Y"]} = rec.action_items

      # Read back from DB
      found =
        Repo.get_by(MeetingNote,
          calendar_event_id: "evt-1",
          occurrence_date: ~D[2025-12-11]
        )

      assert %MeetingNote{action_items: %{"items" => ["do X", "do Y"]}} = found
      assert found.accomplished == "done"
      assert found.bullet_gist == "gist"
    end

    test "accepts pre-wrapped action_items map and optional fields" do
      attrs = %{
        calendar_event_id: "evt-2",
        recurring_series_id: "series-1",
        occurrence_date: ~D[2025-12-12],
        transcript_id: "tr-123",
        action_items: %{"items" => ["a"]}
      }

      assert {:ok, %MeetingNote{} = rec} =
               %MeetingNote{}
               |> MeetingNote.changeset(attrs)
               |> Repo.insert()

      assert rec.recurring_series_id == "series-1"
      assert rec.transcript_id == "tr-123"
      assert rec.action_items == %{"items" => ["a"]}
    end
  end

  describe "unique index on (calendar_event_id, occurrence_date)" do
    test "prevents duplicates for the same event/date" do
      common = %{calendar_event_id: "evt-3", occurrence_date: ~D[2025-12-13]}

      assert {:ok, _} =
               %MeetingNote{} |> MeetingNote.changeset(common) |> Repo.insert()

      assert {:error, changeset} =
               %MeetingNote{} |> MeetingNote.changeset(common) |> Repo.insert()

      assert %{calendar_event_id: ["has already been taken"]} = errors_on(changeset)
    end
  end
end
