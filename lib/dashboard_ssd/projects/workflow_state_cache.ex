defmodule DashboardSSD.Projects.WorkflowStateCache do
  @moduledoc """
  Caches Linear workflow state metadata per team so repeated lookups avoid hitting
  the database on every summary build.

    - Wraps the shared cache with a dedicated namespace for workflow-state entries.
  - Provides helpers to get/put/delete team-specific state payloads with TTLs.
  - Offers flush/reset functions used by sync jobs and tests.
  """

  alias DashboardSSD.Cache

  @namespace :projects_workflow_states
  @default_ttl :timer.hours(1)

  @doc """
  Fetches cached workflow state metadata for the provided Linear team id.

  Returns `{:ok, value}` when present or `:miss` when the entry is absent.
  """
  @spec get(String.t()) :: {:ok, map()} | :miss
  def get(team_id) when is_binary(team_id) and team_id != "" do
    Cache.get(@namespace, team_id)
  end

  def get(_), do: :miss

  @doc """
  Stores workflow state metadata for a team identifier with the given TTL.

  Invalid inputs (blank ids, non-maps, negative TTL) are ignored gracefully.
  """
  @spec put(String.t(), map(), non_neg_integer()) :: :ok
  def put(team_id, value, ttl \\ @default_ttl)

  def put(team_id, value, ttl)
      when is_binary(team_id) and team_id != "" and is_map(value) and is_integer(ttl) and ttl >= 0 do
    Cache.put(@namespace, team_id, value, ttl)
  end

  def put(_, _, _), do: :ok

  @doc """
  Removes the cached entry for the given team id, if present.
  """
  @spec delete(String.t()) :: :ok
  def delete(team_id) when is_binary(team_id) do
    Cache.delete(@namespace, team_id)
  end

  def delete(_), do: :ok

  @doc """
  Clears every cached workflow state entry while keeping the cache namespace intact.
  """
  @spec flush() :: :ok
  def flush do
    Cache.flush(@namespace)
  end

  @doc false
  @spec reset() :: :ok
  def reset do
    Cache.reset()
  end
end
