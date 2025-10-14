defmodule DashboardSSD.KnowledgeBase.SearchTest do
  use ExUnit.Case, async: true

  alias DashboardSSD.KnowledgeBase.Search

  test "search/2 returns not_implemented error" do
    assert {:error, :not_implemented} = Search.search("query")
  end

  test "supports option list without raising" do
    opts = [limit: 10, source_priority: [:cache], include_empty_collections?: true, user_id: 123]
    assert {:error, :not_implemented} = Search.search("query", opts)
  end
end
