defmodule DashboardSSD.KnowledgeBase.ActivityTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Accounts
  alias DashboardSSD.KnowledgeBase.Activity

  test "record_view inserts audit and recent_documents returns deduped, latest first" do
    # Create a real user to satisfy FK
    {:ok, user} =
      Accounts.create_user(%{
        email: "kb-activity@example.com",
        name: "U",
        role_id: Accounts.ensure_role!("employee").id
      })

    doc = %{
      document_id: "doc-1",
      document_title: "Title",
      document_icon: "📄",
      document_share_url: "https://x"
    }

    # First view with an older timestamp and extra metadata including reserved keys (should be dropped)
    old = NaiveDateTime.add(NaiveDateTime.utc_now(), -3600, :second)

    assert :ok =
             Activity.record_view(%{id: user.id}, doc,
               metadata: %{foo: "bar", document_id: "ignored"},
               timestamp: old
             )

    # Second view with newer ISO timestamp string and different metadata
    newer_iso = NaiveDateTime.to_iso8601(NaiveDateTime.utc_now())

    assert :ok =
             Activity.record_view(
               %{"id" => user.id},
               [document_id: "doc-1", document_title: "Title"],
               metadata: %{baz: 123},
               occurred_at: newer_iso
             )

    {:ok, recents} = Activity.recent_documents(user.id)
    # Deduped by document_id -> single entry
    assert length(recents) == 1
    [r] = recents
    assert r.user_id == user.id
    assert r.document_id == "doc-1"
    assert r.document_title == "Title"
    # Metadata excludes reserved keys and keeps custom ones from the latest view
    assert r.metadata["baz"] == 123
    refute Map.has_key?(r.metadata, "document_id")
    # Occurred_at should be >= old (from newer record)
    assert DateTime.compare(r.occurred_at, DateTime.from_naive!(old, "Etc/UTC")) in [:eq, :gt]
  end

  test "record_view returns error for invalid inputs" do
    assert {:error, :invalid_user} = Activity.record_view(%{}, %{document_id: "doc"})
    assert {:error, :invalid_document} = Activity.record_view(%{id: 1}, %{})
  end

  test "recent_documents validates user and limit normalization" do
    assert {:error, :invalid_user} = Activity.recent_documents(%{})

    # Create user and insert more than default limit; request invalid limit -> fallback to default (5)
    {:ok, user} =
      Accounts.create_user(%{
        email: "kb-activity2@example.com",
        name: "U2",
        role_id: Accounts.ensure_role!("employee").id
      })

    Enum.each(1..7, fn i ->
      :ok = Activity.record_view(user.id, %{document_id: Integer.to_string(i)})
    end)

    {:ok, list} = Activity.recent_documents(user.id, limit: :invalid)
    assert length(list) == 5
  end
end
