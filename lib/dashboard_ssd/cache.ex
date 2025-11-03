defmodule DashboardSSD.Cache do
  @moduledoc """
  Compatibility wrapper over the existing Knowledge Base ETS cache.

  Provides a shared cache interface for multiple domains until the
  consolidated cache module lands everywhere.
  """

  alias DashboardSSD.KnowledgeBase.Cache, as: KBCache

  @type namespace :: term()
  @type key :: term()
  @type ttl_ms :: non_neg_integer()

  @doc "Starts the underlying cache process."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: KBCache.start_link(opts)

  @doc false
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {KBCache, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  @doc "Stores a value under the given namespace/key tuple."
  @spec put(namespace(), key(), term(), ttl_ms()) :: :ok
  def put(namespace, key, value, ttl_ms \\ :timer.minutes(10)) do
    KBCache.put(namespace, key, value, ttl_ms)
  end

  @doc "Retrieves a cached entry, returning :miss when not present or expired."
  @spec get(namespace(), key()) :: {:ok, term()} | :miss
  def get(namespace, key), do: KBCache.get(namespace, key)

  @doc "Fetches an entry, computing it with `fun` when missing."
  @spec fetch(namespace(), key(), (-> term() | {:ok, term()} | {:error, term()}), keyword()) ::
          {:ok, term()} | {:error, term()}
  def fetch(namespace, key, fun, opts \\ []), do: KBCache.fetch(namespace, key, fun, opts)

  @doc "Deletes a cached entry."
  @spec delete(namespace(), key()) :: :ok
  def delete(namespace, key), do: KBCache.delete(namespace, key)

  @doc "Flushes all entries for the provided namespace."
  @spec flush(namespace()) :: :ok
  def flush(namespace), do: KBCache.flush(namespace)

  @doc "Clears all cache entries (all namespaces). Intended for tests."
  @spec reset() :: :ok
  def reset, do: KBCache.reset()

  @doc false
  @spec force_cleanup() :: :ok
  def force_cleanup, do: KBCache.force_cleanup()
end
