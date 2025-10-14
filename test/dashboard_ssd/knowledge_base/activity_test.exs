defmodule DashboardSSD.KnowledgeBase.ActivityTest do
  use ExUnit.Case, async: true

  alias DashboardSSD.KnowledgeBase.Activity

  describe "record_view/2" do
    test "returns not implemented placeholder" do
      assert {:error, :not_implemented} =
               Activity.record_view(%{user_id: 1}, %{document_id: "doc-1"})
    end
  end

  describe "recent_documents/2" do
    test "returns not implemented placeholder" do
      assert {:error, :not_implemented} = Activity.recent_documents(1)
    end
  end
end
