defmodule DashboardSSD.KnowledgeBase.CatalogTest do
  use ExUnit.Case, async: true

  alias DashboardSSD.KnowledgeBase.Catalog

  describe "list_collections/1" do
    test "returns not implemented placeholder" do
      assert {:error, :not_implemented} = Catalog.list_collections()
    end
  end

  describe "list_documents/2" do
    test "returns not implemented placeholder" do
      assert {:error, :not_implemented} = Catalog.list_documents("collection-id")
    end
  end

  describe "get_document/2" do
    test "returns not implemented placeholder" do
      assert {:error, :not_implemented} = Catalog.get_document("doc-id")
    end
  end
end
