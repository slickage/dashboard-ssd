defmodule DashboardSSD.Integrations.Fireflies do
  @moduledoc """
  Boundary for interacting with Fireflies.ai to retrieve meeting summaries and
  action items used by the Meetings feature.
  """

  require Logger
  alias DashboardSSD.Meetings.CacheStore
  alias DashboardSSD.Meetings.Parsers.FirefliesParser

  @type artifacts :: %{
          accomplished: String.t() | nil,
          action_items: [String.t()]
        }

  @doc """
  Fetches the latest completed meeting artifacts for a given recurring series.
  Results are cached via `Meetings.CacheStore`.
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
      summary_text = nil
      {:ok, parse_summary(summary_text)}
    end, ttl: ttl)
  end

  @doc "Parses a raw summary text into accomplished text and action items."
  @spec parse_summary(String.t() | nil) :: artifacts()
  def parse_summary(summary_text) do
    {:ok, parsed} = FirefliesParser.split_summary(summary_text)
    parsed
  end
end
