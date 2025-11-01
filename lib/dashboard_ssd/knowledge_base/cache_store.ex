defmodule DashboardSSD.KnowledgeBase.CacheStore do
  @moduledoc """
  Knowledge Base specific wrapper around the shared `DashboardSSD.Cache`.

  Keeps the namespace and TTL defaults in one place so call sites remain
  focused on domain logic.
  """

  alias DashboardSSD.Cache

  @namespace :collections
  @default_ttl :timer.minutes(10)

  @type key :: term()
  @type value :: term()

  @doc "Fetches a cached value, computing it via `fun` when missing."
  @spec fetch(key(), (-> value | {:ok, value} | {:error, term()}), keyword()) ::
          {:ok, value} | {:error, term()}
  def fetch(key, fun, opts \\ []) when is_function(fun, 0) do
    Cache.fetch(@namespace, key, fun, opts)
  end

  @doc "Reads a cached value."
  @spec get(key()) :: {:ok, value()} | :miss
  def get(key) do
    Cache.get(@namespace, key)
  end

  @doc "Stores a value with an optional TTL."
  @spec put(key(), value(), non_neg_integer()) :: :ok
  def put(key, value, ttl \\ @default_ttl) do
    Cache.put(@namespace, key, value, ttl)
  end

  @doc "Deletes a single cached entry."
  @spec delete(key()) :: :ok
  def delete(key) do
    Cache.delete(@namespace, key)
  end

  @doc "Flushes the entire Knowledge Base namespace."
  @spec flush() :: :ok
  def flush do
    Cache.flush(@namespace)
  end

  @doc "Clears all cache entries (all namespaces). Intended for tests."
  @spec reset() :: :ok
  def reset do
    Cache.reset()
  end
end
