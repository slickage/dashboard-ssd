defmodule DashboardSSD.KnowledgeBase.TypesTest do
  use ExUnit.Case, async: true

  alias DashboardSSD.KnowledgeBase.Types
  alias DashboardSSD.KnowledgeBase.Types.Collection
  alias DashboardSSD.KnowledgeBase.Types.DocumentDetail
  alias DashboardSSD.KnowledgeBase.Types.DocumentSummary
  alias DashboardSSD.KnowledgeBase.Types.RecentActivity
  alias DashboardSSD.KnowledgeBase.Types.SearchResult

  @collection_fields [
    :description,
    :document_count,
    :icon,
    :id,
    :last_document_updated_at,
    :last_synced_at,
    :name
  ]

  test "defines collection struct with expected keys" do
    assert %Collection{} = struct(Collection)

    keys =
      Collection.__struct__()
      |> Map.from_struct()
      |> Map.keys()

    assert Enum.all?(@collection_fields, &(&1 in keys))
  end

  test "defines document summary and detail structs" do
    assert %DocumentSummary{} = struct(DocumentSummary)
    assert %DocumentDetail{} = struct(DocumentDetail)
  end

  test "defines recent activity struct" do
    assert %RecentActivity{} = struct(RecentActivity)
  end

  test "defines search result struct" do
    assert %SearchResult{} = struct(SearchResult)
    assert Types.search_source_values() == [:cache, :notion]
  end
end
