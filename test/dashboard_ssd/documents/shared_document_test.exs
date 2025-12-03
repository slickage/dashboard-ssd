defmodule DashboardSSD.Documents.SharedDocumentTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Documents.SharedDocument

  describe "changeset/2" do
    test "validates required fields" do
      changeset = SharedDocument.changeset(%SharedDocument{}, %{})
      refute changeset.valid?
      assert %{client_id: ["can't be blank"], source: ["can't be blank"]} = errors_on(changeset)
    end

    test "accepts default attributes" do
      assert SharedDocument.changeset(%SharedDocument{}, valid_attrs()).valid?
    end

    test "rejects client edit when source is notion" do
      attrs = valid_attrs(%{source: :notion, client_edit_allowed: true})
      changeset = SharedDocument.changeset(%SharedDocument{}, attrs)
      refute changeset.valid?

      assert %{client_edit_allowed: ["can only be enabled for Drive documents"]} =
               errors_on(changeset)
    end

    test "accepts drive sources with client edit allowed" do
      attrs = valid_attrs(%{client_edit_allowed: true})
      assert SharedDocument.changeset(%SharedDocument{}, attrs).valid?
    end
  end

  defp valid_attrs(overrides \\ %{}) do
    %{
      client_id: 1,
      source: :drive,
      source_id: "drive-file",
      doc_type: "sow",
      title: "SOW",
      visibility: :internal
    }
    |> Map.merge(overrides)
  end
end
