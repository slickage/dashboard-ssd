defmodule DashboardSSD.KnowledgeBase.SearchTest do
  use ExUnit.Case, async: true

  alias DashboardSSD.KnowledgeBase.Search

  test "search returns not implemented tuple" do
    assert {:error, :not_implemented} = Search.search("contracts", limit: 5)
  end
end
