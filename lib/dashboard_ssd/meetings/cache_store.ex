defmodule DashboardSSD.Meetings.CacheStore do
  @moduledoc """
  Meetings-specific wrapper around the shared ETS cache.

  Encapsulates the namespace and TTL defaults for meeting artifacts fetched from
  external systems (e.g., Fireflies summaries/action items) so that call sites
  can remain focused on domain logic.
  """

  alias DashboardSSD.Cache

  @namespace :meetings
  @default_ttl_ms :timer.minutes(10)

  @type key :: term()
  @type value :: term()

  @doc "Fetches a cached value, computing it via `fun` when missing."
  @spec fetch(key(), (-> value | {:ok, value} | {:error, term()}), keyword()) ::
          {:ok, value} | {:error, term()}
  def fetch(key, fun, opts \\ []) when is_function(fun, 0) do
    ttl = Keyword.get(opts, :ttl, @default_ttl_ms) || @default_ttl_ms
    Cache.fetch(@namespace, key, fun, ttl: ttl)
  end

  @doc "Reads a cached value."
  @spec get(key()) :: {:ok, value()} | :miss
  def get(key) do
    Cache.get(@namespace, key)
  end

  @doc "Stores a value with an optional TTL (defaults to 10 minutes)."
  @spec put(key(), value(), non_neg_integer()) :: :ok
  def put(key, value, ttl_ms \\ @default_ttl_ms) do
    Cache.put(@namespace, key, value, ttl_ms)
  end

  @doc "Deletes a single cached entry."
  @spec delete(key()) :: :ok
  def delete(key) do
    Cache.delete(@namespace, key)
  end

  @doc "Flushes the entire Meetings namespace."
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
