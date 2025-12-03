defmodule DashboardSSD.Documents.DocumentAccessLogTest do
  use DashboardSSD.DataCase, async: true

  import Ecto.Changeset, only: [get_field: 2]

  alias DashboardSSD.Documents.DocumentAccessLog

  describe "changeset/2" do
    test "requires shared_document_id and action" do
      changeset = DocumentAccessLog.changeset(%DocumentAccessLog{}, %{})
      refute changeset.valid?

      assert %{shared_document_id: ["can't be blank"], action: ["can't be blank"]} =
               errors_on(changeset)
    end

    test "normalizes context" do
      attrs = %{shared_document_id: Ecto.UUID.autogenerate(), action: :download, context: nil}
      changeset = DocumentAccessLog.changeset(%DocumentAccessLog{}, attrs)
      assert changeset.valid?
      assert get_field(changeset, :context) == %{}
    end

    test "keeps provided map context" do
      attrs = %{
        shared_document_id: Ecto.UUID.autogenerate(),
        action: :download,
        context: %{role: "viewer"}
      }

      changeset = DocumentAccessLog.changeset(%DocumentAccessLog{}, attrs)
      assert changeset.valid?
      assert get_field(changeset, :context) == %{role: "viewer"}
    end

    test "defaults context when missing" do
      attrs = %{shared_document_id: Ecto.UUID.autogenerate(), action: :download}
      changeset = DocumentAccessLog.changeset(%DocumentAccessLog{}, attrs)
      assert changeset.valid?
      assert get_field(changeset, :context) == %{}
    end

    test "rejects invalid context" do
      attrs = %{shared_document_id: Ecto.UUID.autogenerate(), action: :download, context: 123}
      changeset = DocumentAccessLog.changeset(%DocumentAccessLog{}, attrs)
      refute changeset.valid?
      assert %{context: [_]} = errors_on(changeset)
    end
  end
end
