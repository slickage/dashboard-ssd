defmodule DashboardSSD.Projects.LinearSyncCache do
  @moduledoc """
  Lightweight wrapper around the shared ETS cache for storing results of Linear
  project syncs. Values are stored with a configurable TTL so we can reuse the
  most recent payload and avoid repeatedly hammering the Linear API.
  """

  alias DashboardSSD.Cache

  @namespace :projects_linear_sync
  @cache_key :sync
  @default_ttl_ms :timer.hours(2)

  @type cache_entry :: %{
          payload: map() | nil,
          synced_at: DateTime.t() | nil,
          synced_at_mono: integer() | nil,
          next_allowed_sync_mono: integer() | nil,
          rate_limit_message: String.t() | nil,
          summaries: map() | nil
        }

  @doc """
  Fetches the cached sync entry if present, otherwise returns `:miss`.
  """
  @spec get() :: {:ok, cache_entry()} | :miss
  def get do
    case Cache.get(@namespace, @cache_key) do
      {:ok, value} -> {:ok, value}
      :miss -> :miss
    end
  end

  @doc """
  Stores an entry in the cache for the provided TTL (defaults to two hours).
  """
  @spec put(cache_entry(), non_neg_integer()) :: :ok
  def put(entry, ttl_ms \\ @default_ttl_ms) when is_map(entry) do
    Cache.put(@namespace, @cache_key, entry, ttl_ms)
  end

  @doc """
  Removes the cached sync entry.
  """
  @spec delete() :: :ok
  def delete do
    Cache.delete(@namespace, @cache_key)
  end
end
