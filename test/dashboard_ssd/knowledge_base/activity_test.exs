defmodule DashboardSSD.KnowledgeBase.ActivityTest do
  use DashboardSSD.DataCase, async: true

  import Ecto.Query

  alias DashboardSSD.Accounts
  alias DashboardSSD.KnowledgeBase.Activity
  alias DashboardSSD.KnowledgeBase.Types
  alias DashboardSSD.Repo

  describe "record_view" do
    test "persists audit rows with normalized details" do
      {:ok, user} =
        Accounts.create_user(%{
          email: "audit@example.com",
          name: "Audit User",
          role_id: Accounts.ensure_role!("employee").id
        })

      assert :ok =
               Activity.record_view(user, %{
                 document_id: "doc-1",
                 document_title: "Handbook",
                 document_share_url: "https://notion.so/doc-1"
               })

      audit =
        Repo.one(
          from a in "audits",
            select: %{action: a.action, details: a.details, user_id: a.user_id}
        )

      assert audit.action == "kb.viewed"
      assert audit.user_id == user.id

      assert audit.details == %{
               "document_id" => "doc-1",
               "document_share_url" => "https://notion.so/doc-1",
               "document_title" => "Handbook"
             }
    end

    test "validates required attributes" do
      assert {:error, :invalid_user} = Activity.record_view(%{}, %{document_id: "doc"})
      assert {:error, :invalid_document} = Activity.record_view(%{user_id: 1}, %{})
    end

    test "merges metadata and handles string identifiers" do
      {:ok, user} =
        Accounts.create_user(%{
          email: "meta@example.com",
          name: "Meta",
          role_id: Accounts.ensure_role!("employee").id
        })

      assert :ok =
               Activity.record_view(%{"id" => user.id}, %{"document_id" => 42},
                 metadata: %{note: "test"}
               )

      audit =
        Repo.one(
          from a in "audits",
            where: a.user_id == ^user.id and a.action == "kb.viewed",
            order_by: [desc: a.inserted_at],
            limit: 1,
            select: a.details
        )

      assert audit == %{"document_id" => "42", "note" => "test"}
    end

    test "respects explicit timestamp option" do
      {:ok, user} =
        Accounts.create_user(%{
          email: "timestamp@example.com",
          name: "Timestamp",
          role_id: Accounts.ensure_role!("employee").id
        })

      naive = ~N[2024-06-01 08:15:00]

      assert :ok =
               Activity.record_view(%{user_id: user.id}, %{document_id: "doc-ts"},
                 timestamp: naive
               )

      inserted_at =
        Repo.one(
          from a in "audits",
            where: a.user_id == ^user.id and a.action == "kb.viewed",
            order_by: [desc: a.inserted_at],
            limit: 1,
            select: a.inserted_at
        )

      assert inserted_at == naive
    end

    test "accepts keyword document attributes" do
      {:ok, user} =
        Accounts.create_user(%{
          email: "keyword@example.com",
          name: "Keyword",
          role_id: Accounts.ensure_role!("employee").id
        })

      assert :ok =
               Activity.record_view(user, [document_id: "doc-list", document_title: "List"],
                 metadata: %{"extra" => "yes"}
               )

      audit =
        Repo.one(
          from a in "audits",
            where: a.user_id == ^user.id,
            order_by: [desc: a.inserted_at],
            limit: 1,
            select: a.details
        )

      assert audit == %{"document_id" => "doc-list", "document_title" => "List", "extra" => "yes"}
    end

    test "drops reserved metadata keys and stringifies everything else" do
      {:ok, user} =
        Accounts.create_user(%{
          email: "reserved@example.com",
          name: "Reserved",
          role_id: Accounts.ensure_role!("employee").id
        })

      timestamp = DateTime.utc_now()

      assert :ok =
               Activity.record_view(%{user_id: user.id}, %{document_id: "doc-meta"},
                 metadata: %{
                   document_id: "override",
                   document_title: "duplicate",
                   document_share_url: "override",
                   extra: :value
                 },
                 occurred_at: timestamp
               )

      record =
        Repo.one(
          from a in "audits",
            where: a.user_id == ^user.id,
            order_by: [desc: a.inserted_at],
            limit: 1,
            select: %{details: a.details, inserted_at: a.inserted_at}
        )

      assert record.details == %{"document_id" => "doc-meta", "extra" => "value"}
      assert record.inserted_at == DateTime.to_naive(DateTime.truncate(timestamp, :second))
    end

    test "accepts DateTime timestamps" do
      {:ok, user} =
        Accounts.create_user(%{
          email: "datetime@example.com",
          name: "DateTime",
          role_id: Accounts.ensure_role!("employee").id
        })

      dt = DateTime.utc_now() |> DateTime.add(-120, :second) |> DateTime.truncate(:second)

      assert :ok =
               Activity.record_view(user, %{document_id: "doc-dt"}, occurred_at: dt)

      inserted_at =
        Repo.one(
          from a in "audits",
            where: a.user_id == ^user.id,
            order_by: [desc: a.inserted_at],
            limit: 1,
            select: a.inserted_at
        )

      assert inserted_at == DateTime.to_naive(dt)
    end

    test "ignores metadata when non-map provided" do
      {:ok, user} =
        Accounts.create_user(%{
          email: "ignored-meta@example.com",
          name: "Ignore Meta",
          role_id: Accounts.ensure_role!("employee").id
        })

      assert :ok =
               Activity.record_view(%{"user_id" => user.id}, %{document_id: "doc-ignore"},
                 metadata: ["invalid"]
               )

      details =
        Repo.one(
          from a in "audits",
            where: a.user_id == ^user.id,
            order_by: [desc: a.inserted_at],
            limit: 1,
            select: a.details
        )

      assert details == %{"document_id" => "doc-ignore"}
    end

    test "accepts bare user ids and integer document identifiers" do
      {:ok, user} =
        Accounts.create_user(%{
          email: "bare@example.com",
          name: "Bare",
          role_id: Accounts.ensure_role!("employee").id
        })

      assert :ok =
               Activity.record_view(user.id, %{document_id: 101})

      details =
        Repo.one(
          from a in "audits",
            where: a.user_id == ^user.id,
            order_by: [desc: a.inserted_at],
            limit: 1,
            select: a.details
        )

      assert details == %{"document_id" => "101"}
    end

    test "returns database errors when inserts fail" do
      assert {:error, %Postgrex.Error{postgres: %{code: :foreign_key_violation}}} =
               Activity.record_view(-1, %{document_id: "missing-user"})
    end

    test "removes metadata entries with blank values" do
      {:ok, user} =
        Accounts.create_user(%{
          email: "blank@example.com",
          name: "Blank",
          role_id: Accounts.ensure_role!("employee").id
        })

      metadata = %{note: ""} |> Map.put("tag", "present")

      assert :ok =
               Activity.record_view(user, %{document_id: "doc-blank"}, metadata: metadata)

      details =
        Repo.one(
          from a in "audits",
            where: a.user_id == ^user.id,
            order_by: [desc: a.inserted_at],
            limit: 1,
            select: a.details
        )

      assert details == %{"document_id" => "doc-blank", "tag" => "present"}
    end

    test "removes document fields with blank values" do
      {:ok, user} =
        Accounts.create_user(%{
          email: "blank-doc@example.com",
          name: "Blank Doc",
          role_id: Accounts.ensure_role!("employee").id
        })

      assert :ok =
               Activity.record_view(user, %{
                 document_id: "doc-blank-fields",
                 document_title: "",
                 document_icon: nil,
                 document_share_url: "https://example.com"
               })

      details =
        Repo.one(
          from a in "audits",
            where: a.user_id == ^user.id,
            order_by: [desc: a.inserted_at],
            limit: 1,
            select: a.details
        )

      assert details == %{
               "document_id" => "doc-blank-fields",
               "document_share_url" => "https://example.com"
             }
    end

    test "handles invalid timestamp gracefully" do
      {:ok, user} =
        Accounts.create_user(%{
          email: "invalid-ts@example.com",
          name: "Invalid TS",
          role_id: Accounts.ensure_role!("employee").id
        })

      assert :ok =
               Activity.record_view(user, %{document_id: "doc-invalid-ts"}, occurred_at: 123)

      # Should use current time, so inserted_at should be recent
      inserted_at =
        Repo.one(
          from a in "audits",
            where: a.user_id == ^user.id and a.action == "kb.viewed",
            order_by: [desc: a.inserted_at],
            limit: 1,
            select: a.inserted_at
        )

      assert %NaiveDateTime{} = inserted_at
      # Should be within last minute
      assert NaiveDateTime.diff(NaiveDateTime.utc_now(), inserted_at) < 60
    end

    test "handles string timestamps gracefully" do
      {:ok, user} =
        Accounts.create_user(%{
          email: "string-ts@example.com",
          name: "String TS",
          role_id: Accounts.ensure_role!("employee").id
        })

      string_ts = "2024-05-01T12:00:00"

      assert :ok =
               Activity.record_view(user, %{document_id: "doc-string-ts"}, occurred_at: string_ts)

      inserted_at =
        Repo.one(
          from a in "audits",
            where: a.user_id == ^user.id and a.action == "kb.viewed",
            order_by: [desc: a.inserted_at],
            limit: 1,
            select: a.inserted_at
        )

      assert inserted_at == ~N[2024-05-01 12:00:00]
    end

    test "handles invalid string timestamps gracefully" do
      {:ok, user} =
        Accounts.create_user(%{
          email: "invalid-string-ts@example.com",
          name: "Invalid String TS",
          role_id: Accounts.ensure_role!("employee").id
        })

      assert :ok =
               Activity.record_view(user, %{document_id: "doc-invalid-string-ts"},
                 occurred_at: "not-a-date"
               )

      inserted_at =
        Repo.one(
          from a in "audits",
            where: a.user_id == ^user.id and a.action == "kb.viewed",
            order_by: [desc: a.inserted_at],
            limit: 1,
            select: a.inserted_at
        )

      assert %NaiveDateTime{} = inserted_at
      # Should be within last minute
      assert NaiveDateTime.diff(NaiveDateTime.utc_now(), inserted_at) < 60
    end

    test "ignores non-map metadata" do
      {:ok, user} =
        Accounts.create_user(%{
          email: "non-map-meta@example.com",
          name: "Non Map Meta",
          role_id: Accounts.ensure_role!("employee").id
        })

      assert :ok = Activity.record_view(user, %{document_id: "doc-non-map"}, metadata: "invalid")

      details =
        Repo.one(
          from a in "audits",
            where: a.user_id == ^user.id,
            order_by: [desc: a.inserted_at],
            limit: 1,
            select: a.details
        )

      assert details == %{"document_id" => "doc-non-map"}
    end

    test "accepts list attributes" do
      {:ok, user} =
        Accounts.create_user(%{
          email: "list-attrs@example.com",
          name: "List Attrs",
          role_id: Accounts.ensure_role!("employee").id
        })

      assert :ok = Activity.record_view(user, document_id: "doc-list", document_title: "List")

      details =
        Repo.one(
          from a in "audits",
            where: a.user_id == ^user.id,
            order_by: [desc: a.inserted_at],
            limit: 1,
            select: a.details
        )

      assert details == %{"document_id" => "doc-list", "document_title" => "List"}
    end
  end

  describe "recent_documents/2" do
    setup do
      {:ok, user} =
        Accounts.create_user(%{
          email: "recent@example.com",
          name: "Recent User",
          role_id: Accounts.ensure_role!("employee").id
        })

      {:ok, other} =
        Accounts.create_user(%{
          email: "other@example.com",
          name: "Other User",
          role_id: Accounts.ensure_role!("employee").id
        })

      %{user: user, other: other}
    end

    test "returns latest five audits in reverse chronological order", %{user: user, other: other} do
      # Seed more than five entries to ensure limit
      for {doc, ts} <- Enum.with_index(~w(doc-a doc-b doc-c doc-d doc-e doc-f)) do
        timestamp = DateTime.utc_now() |> DateTime.add(ts * -60, :second)

        :ok =
          Activity.record_view(user, %{document_id: doc, document_title: String.upcase(doc)},
            occurred_at: timestamp
          )
      end

      # Insert audit for another user to ensure scoping
      :ok = Activity.record_view(other, %{document_id: "other"})

      assert {:ok, activities} = Activity.recent_documents(user.id)
      assert length(activities) == 5

      ids = Enum.map(activities, & &1.document_id)
      assert ids == ~w(doc-a doc-b doc-c doc-d doc-e)

      assert Enum.all?(activities, fn %Types.RecentActivity{occurred_at: occurred_at} ->
               match?(%DateTime{}, occurred_at)
             end)
    end

    test "accepts limit option and returns empty list when no data", %{user: user} do
      assert {:ok, []} = Activity.recent_documents(user)

      timestamp = ~U[2024-05-01 12:00:00Z]
      :ok = Activity.record_view(user, %{document_id: "doc-x"}, occurred_at: timestamp)

      :ok =
        Activity.record_view(user, %{document_id: "doc-y"},
          occurred_at: DateTime.add(timestamp, 60, :second)
        )

      assert {:ok, [%Types.RecentActivity{document_id: "doc-y"}]} =
               Activity.recent_documents(%{"id" => user.id}, limit: 1)
    end

    test "recent_documents preserves metadata and normalizes timestamps", %{user: user} do
      naive = ~N[2024-05-02 09:00:00]

      :ok =
        Activity.record_view(
          user,
          %{
            document_id: "doc-meta",
            document_title: "Metadata",
            document_share_url: "https://example.com/doc-meta"
          },
          metadata: %{project: "kb"},
          occurred_at: naive
        )

      assert {:ok, [activity]} = Activity.recent_documents(user, limit: 1)
      assert activity.metadata == %{"project" => "kb"}
      assert %DateTime{} = activity.occurred_at
      assert DateTime.to_naive(activity.occurred_at) == naive
    end

    test "uses default limit when invalid limit provided", %{user: user} do
      for doc <- Enum.map(1..7, &"doc-limit-#{&1}") do
        :ok = Activity.record_view(user, %{document_id: doc})
      end

      assert {:ok, activities} = Activity.recent_documents(user, limit: 0)
      assert length(activities) == 5
    end

    test "dedupes recent documents by document_id", %{user: user} do
      # Record multiple views of the same document
      :ok = Activity.record_view(user, %{document_id: "doc-dup", document_title: "Duplicate"})

      :ok =
        Activity.record_view(user, %{document_id: "doc-dup", document_title: "Duplicate Again"})

      :ok = Activity.record_view(user, %{document_id: "doc-other", document_title: "Other"})

      assert {:ok, activities} = Activity.recent_documents(user, limit: 10)
      assert length(activities) == 2
      ids = Enum.map(activities, & &1.document_id)
      assert "doc-dup" in ids
      assert "doc-other" in ids
    end

    test "handles metadata with string keys", %{user: user} do
      :ok =
        Activity.record_view(user, %{document_id: "doc-string-meta"},
          metadata: %{"string_key" => "value", atom_key: "atom_value"}
        )

      details =
        Repo.one(
          from a in "audits",
            where: a.user_id == ^user.id,
            order_by: [desc: a.inserted_at],
            limit: 1,
            select: a.details
        )

      assert details == %{
               "document_id" => "doc-string-meta",
               "string_key" => "value",
               "atom_key" => "atom_value"
             }
    end

    test "handles string limit gracefully", %{user: user} do
      :ok = Activity.record_view(user, %{document_id: "doc-string-limit"})

      assert {:ok, activities} = Activity.recent_documents(user, limit: "2")
      assert length(activities) == 1
    end

    test "accepts maps containing user_id attribute", %{user: user} do
      :ok = Activity.record_view(user, %{document_id: "doc-user-id"})

      assert {:ok, [%Types.RecentActivity{document_id: "doc-user-id"}]} =
               Activity.recent_documents(%{user_id: user.id}, limit: 1)
    end

    test "handles audit rows without details data", %{user: user} do
      Repo.insert_all("audits", [
        %{
          user_id: user.id,
          action: "kb.viewed",
          details: nil,
          inserted_at: ~N[2024-05-01 12:00:00]
        }
      ])

      assert {:ok, [activity]} = Activity.recent_documents(user, limit: 1)
      assert activity.document_id == nil
      assert activity.metadata == %{}
    end

    test "returns error for invalid user" do
      assert {:error, :invalid_user} = Activity.recent_documents(%{})
    end
  end
end
