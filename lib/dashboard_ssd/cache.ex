defmodule DashboardSSD.Cache do
  @moduledoc """
  Lightweight ETS-backed cache shared across the application. Entries are stored
  per logical namespace with TTL-based expiration and a periodic cleanup pass to
  reclaim stale data.

    - Provides convenience `put/get/fetch` helpers around a single ETS table.
  - Ensures the cache process is booted lazily for test helpers and scripts.
  - Periodically sweeps expired keys so short-lived data never overgrows memory.
  """
  use GenServer

  @table :dashboard_ssd_cache
  @default_ttl_ms :timer.minutes(10)
  @default_cleanup_ms :timer.minutes(1)

  @type namespace :: term()
  @type key :: term()
  @type ttl_ms :: non_neg_integer()
  @type fetch_opt :: {:ttl, ttl_ms()}
  @type fetch_opts :: [fetch_opt()]

  ## Public API -----------------------------------------------------------------

  @doc "Starts the cache supervisor child."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc "Stores a value under the given namespace/key tuple."
  @spec put(namespace(), key(), term(), ttl_ms()) :: :ok
  def put(namespace, key, value, ttl_ms \\ @default_ttl_ms) do
    ensure_started!()
    expires_at = now() + max(ttl_ms, 0)
    :ets.insert(@table, {{namespace, key}, value, expires_at})
    :ok
  end

  @doc "Retrieves a cached entry, returning :miss when not present or expired."
  @spec get(namespace(), key()) :: {:ok, term()} | :miss
  def get(namespace, key) do
    ensure_started!()

    case :ets.lookup(@table, {namespace, key}) do
      [{{^namespace, ^key}, value, expires_at}] ->
        if expires_at > now() do
          {:ok, value}
        else
          :ets.delete(@table, {namespace, key})
          :miss
        end

      _ ->
        :miss
    end
  end

  @doc """
  Fetches an entry, computing it with `fun` when missing.

  The function may return either a bare value, `{:ok, value}`, or `{:error, reason}`.
  When a value is returned it is cached using the configured TTL (defaults to 10 minutes).
  """
  @spec fetch(namespace(), key(), (-> term() | {:ok, term()} | {:error, term()}), fetch_opts()) ::
          {:ok, term()} | {:error, term()}
  def fetch(namespace, key, fun, opts \\ []) when is_function(fun, 0) do
    case get(namespace, key) do
      {:ok, value} ->
        {:ok, value}

      :miss ->
        ttl = Keyword.get(opts, :ttl, @default_ttl_ms)

        case fun.() do
          {:ok, value} ->
            put(namespace, key, value, ttl)
            {:ok, value}

          {:error, reason} ->
            {:error, reason}

          value ->
            put(namespace, key, value, ttl)
            {:ok, value}
        end
    end
  end

  @doc "Deletes a cached entry."
  @spec delete(namespace(), key()) :: :ok
  def delete(namespace, key) do
    ensure_started!()
    :ets.delete(@table, {namespace, key})
    :ok
  end

  @doc "Flushes all entries for the provided namespace."
  @spec flush(namespace()) :: :ok
  def flush(namespace) do
    ensure_started!()

    spec = [
      {{{namespace, :_}, :_, :_}, [], [true]}
    ]

    :ets.select_delete(@table, spec)
    :ok
  end

  @doc false
  @spec reset() :: :ok
  def reset do
    ensure_started!()
    :ets.delete_all_objects(@table)
    :ok
  end

  @doc false
  @spec force_cleanup() :: :ok
  def force_cleanup do
    GenServer.cast(__MODULE__, :force_cleanup)
  end

  ## GenServer callbacks -------------------------------------------------------

  @impl true
  def init(opts) do
    ensure_table(Keyword.get(opts, :table, @table))
    cleanup_interval = Keyword.get(opts, :cleanup_interval, @default_cleanup_ms)

    state = %{cleanup_interval: cleanup_interval}
    schedule_cleanup(cleanup_interval)
    {:ok, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired()
    schedule_cleanup(state.cleanup_interval)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:force_cleanup, state) do
    cleanup_expired()
    {:noreply, state}
  end

  ## Helpers -------------------------------------------------------------------

  defp ensure_table(table_name) do
    case :ets.whereis(table_name) do
      :undefined ->
        :ets.new(table_name, [
          :named_table,
          :set,
          :public,
          read_concurrency: true,
          write_concurrency: true
        ])

      _tid ->
        table_name
    end
  end

  defp ensure_started! do
    if :ets.whereis(@table) == :undefined do
      raise "DashboardSSD.Cache has not been started"
    end

    :ok
  end

  defp schedule_cleanup(interval) when is_integer(interval) and interval > 0 do
    Process.send_after(self(), :cleanup, interval)
  end

  defp schedule_cleanup(_), do: :ok

  defp cleanup_expired do
    ensure_started!()
    now = now()

    spec = [
      {{{:"$1", :"$2"}, :"$3", :"$4"}, [{:"=<", :"$4", now}], [true]}
    ]

    :ets.select_delete(@table, spec)
    :ok
  end

  defp now, do: System.monotonic_time(:millisecond)
end
