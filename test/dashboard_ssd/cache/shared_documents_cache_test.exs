defmodule DashboardSSD.Cache.SharedDocumentsCacheTest do
  use ExUnit.Case, async: false

  alias DashboardSSD.Cache
  alias DashboardSSD.Cache.SharedDocumentsCache

  setup do
    Cache.reset()
    :ok
  end

  test "stores and fetches listing by scope" do
    scope = {1, 2}
    assert :miss = SharedDocumentsCache.get_listing(scope)
    SharedDocumentsCache.put_listing(scope, %{docs: [1]})
    assert {:ok, %{docs: [1]}} = SharedDocumentsCache.get_listing(scope)
  end

  test "invalidates listings" do
    scope = {5, nil}
    SharedDocumentsCache.put_listing(scope, %{docs: []})
    SharedDocumentsCache.invalidate_listing(scope)
    assert :miss = SharedDocumentsCache.get_listing(scope)
  end

  test "handles download descriptors" do
    id = Ecto.UUID.autogenerate()
    SharedDocumentsCache.put_download_descriptor(id, %{mime: "application/pdf"})
    assert {:ok, %{mime: "application/pdf"}} = SharedDocumentsCache.get_download_descriptor(id)
    SharedDocumentsCache.invalidate_download(id)
    assert :miss = SharedDocumentsCache.get_download_descriptor(id)
  end
end
