defmodule DashboardSSD.Integrations.Fireflies do
  @moduledoc """
  Boundary for interacting with Fireflies.ai to retrieve meeting summaries and
  action items used by the Meetings feature.
  """

  require Logger
  alias DashboardSSD.Meetings.CacheStore

  @type artifacts :: %{
          accomplished: String.t() | nil,
          action_items: [String.t()]
        }

  @doc """
  Fetches the latest completed meeting artifacts for a given recurring series.
  Results are cached via `Meetings.CacheStore`.

  Note: We no longer parse freeform summary text locally. This function will
  eventually call the Fireflies API to retrieve structured notes and
  action_items directly. For now, it returns an empty placeholder until the
  client implementation lands.
  """
  @spec fetch_latest_for_series(String.t(), keyword()) :: {:ok, artifacts()} | {:error, term()}
  def fetch_latest_for_series(series_id, opts \\ []) when is_binary(series_id) do
    key = {:series_artifacts, series_id}
    ttl = Keyword.get(opts, :ttl)

    CacheStore.fetch(key, fn ->
      Logger.debug(fn ->
        %{msg: "fireflies.fetch_latest_for_series/2", series_id: series_id}
        |> Jason.encode!()
      end)

      # TODO: Replace with Fireflies API call using FIREFLIES_API_TOKEN
      # Placeholder: return empty accomplished and no action items
      {:ok, %{accomplished: nil, action_items: []}}
    end, ttl: ttl)
  end

  @doc """
  Refreshes (invalidates cache) and refetches latest artifacts for a series.
  """
  @spec refresh_series(String.t(), keyword()) :: {:ok, artifacts()} | {:error, term()}
  def refresh_series(series_id, opts \\ []) when is_binary(series_id) do
    CacheStore.delete({:series_artifacts, series_id})
    fetch_latest_for_series(series_id, opts)
  end
end
