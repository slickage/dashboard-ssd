defmodule DashboardSSD.Cache.SharedDocumentsCache do
  @moduledoc """
  Namespaced cache helpers for Shared Documents listings + download descriptors.

  Wraps `DashboardSSD.Cache` with sensible TTL defaults so callers can fetch and
  invalidate listings per user/project scope or download metadata per document ID.
  """
  alias DashboardSSD.Cache

  @listing_namespace :shared_documents_listings
  @download_namespace :shared_documents_downloads
  @listing_ttl_ms :timer.minutes(5)
  @download_ttl_ms :timer.minutes(2)

  @type listing_scope :: {integer(), integer() | nil}

  @doc "Fetches a cached listing for the given user/project scope."
  @spec get_listing(listing_scope()) :: {:ok, term()} | :miss
  def get_listing({user_id, project_id}) do
    Cache.get(@listing_namespace, normalize_scope(user_id, project_id))
  end

  @doc "Caches a listing payload for the provided user/project scope."
  @spec put_listing(listing_scope(), term()) :: :ok
  def put_listing({user_id, project_id}, payload) do
    Cache.put(@listing_namespace, normalize_scope(user_id, project_id), payload, @listing_ttl_ms)
  end

  @doc "Fetches or populates a listing using the supplied compute function."
  @spec fetch_listing(listing_scope(), (-> term())) :: {:ok, term()} | {:error, term()}
  def fetch_listing({user_id, project_id}, fun) when is_function(fun, 0) do
    Cache.fetch(@listing_namespace, normalize_scope(user_id, project_id), fun,
      ttl: @listing_ttl_ms
    )
  end

  @doc "Invalidates one or all listing cache entries."
  @spec invalidate_listing(:all | listing_scope()) :: :ok
  def invalidate_listing(:all) do
    Cache.flush(@listing_namespace)
  end

  def invalidate_listing({user_id, project_id}) do
    Cache.delete(@listing_namespace, normalize_scope(user_id, project_id))
  end

  @doc "Stores download metadata for a shared document."
  @spec put_download_descriptor(Ecto.UUID.t(), term()) :: :ok
  def put_download_descriptor(document_id, data) do
    Cache.put(@download_namespace, document_id, data, @download_ttl_ms)
  end

  @doc "Retrieves download metadata if the TTL has not expired."
  @spec get_download_descriptor(Ecto.UUID.t()) :: {:ok, term()} | :miss
  def get_download_descriptor(document_id) do
    Cache.get(@download_namespace, document_id)
  end

  @doc "Fetches or computes download metadata for a shared document."
  @spec fetch_download_descriptor(Ecto.UUID.t(), (-> term())) :: {:ok, term()} | {:error, term()}
  def fetch_download_descriptor(document_id, fun) when is_function(fun, 0) do
    Cache.fetch(@download_namespace, document_id, fun, ttl: @download_ttl_ms)
  end

  @doc "Invalidates cached download metadata for one or all documents."
  @spec invalidate_download(:all | Ecto.UUID.t()) :: :ok
  def invalidate_download(:all) do
    Cache.flush(@download_namespace)
  end

  def invalidate_download(document_id) do
    Cache.delete(@download_namespace, document_id)
  end

  defp normalize_scope(user_id, project_id) do
    {user_id, project_id}
  end
end
