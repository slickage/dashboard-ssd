defmodule DashboardSSD.KnowledgeBase.SearchTest do
  use ExUnit.Case, async: true

  alias DashboardSSD.KnowledgeBase.Search

  describe "search/2" do
    test "returns not_implemented error with term only" do
      assert {:error, :not_implemented} = Search.search("query")
    end

    test "returns not_implemented error with empty term" do
      assert {:error, :not_implemented} = Search.search("")
    end

    test "returns not_implemented error with nil term" do
      assert {:error, :not_implemented} = Search.search(nil)
    end

    test "supports limit option" do
      opts = [limit: 10]
      assert {:error, :not_implemented} = Search.search("query", opts)
    end

    test "supports source_priority option" do
      opts = [source_priority: [:cache, :notion]]
      assert {:error, :not_implemented} = Search.search("query", opts)
    end

    test "supports include_empty_collections? option" do
      opts = [include_empty_collections?: true]
      assert {:error, :not_implemented} = Search.search("query", opts)
    end

    test "supports user_id option" do
      opts = [user_id: 123]
      assert {:error, :not_implemented} = Search.search("query", opts)
    end

    test "supports all options combined" do
      opts = [
        limit: 10,
        source_priority: [:cache],
        include_empty_collections?: true,
        user_id: 123
      ]

      assert {:error, :not_implemented} = Search.search("query", opts)
    end

    test "supports empty options list" do
      assert {:error, :not_implemented} = Search.search("query", [])
    end
  end
end
