defmodule DashboardSSD.KnowledgeBase.SearchTest do
  use ExUnit.Case, async: true

  alias DashboardSSD.KnowledgeBase.Search

  describe "search/2" do
    test "returns not implemented placeholder" do
      assert {:error, :not_implemented} = Search.search("example")
    end
  end
end
