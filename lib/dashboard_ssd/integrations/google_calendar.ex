defmodule DashboardSSD.Integrations.GoogleCalendar do
  @moduledoc """
  Boundary for interacting with Google Calendar for meeting listings and
  recurrence mapping. This module intentionally exposes a minimal surface for
  the Meetings feature and is designed to be stubbed in tests.
  """

  require Logger

  @type meeting_event :: %{
          id: String.t(),
          title: String.t(),
          start_at: DateTime.t(),
          end_at: DateTime.t(),
          recurring_series_id: String.t() | nil
        }

  @doc """
  Lists upcoming meetings for the given window. The user context (e.g., tokens)
  is derived internally from the current session or DB.
  """
  @spec list_upcoming(DateTime.t(), DateTime.t(), keyword()) :: {:ok, [meeting_event()]} | {:error, term()}
  def list_upcoming(start_at, end_at, opts \\ []) do
    Logger.debug(fn ->
      %{msg: "google_calendar.list_upcoming/3", start_at: start_at, end_at: end_at, opts: scrub(opts)}
      |> Jason.encode!()
    end)

    case Keyword.get(opts, :mock) do
      :sample ->
        # Return a couple of sample meetings for preview purposes
        now = start_at
        {:ok,
         [
           %{
             id: "evt-1",
             title: "Weekly Sync – Project Alpha",
             start_at: now,
             end_at: DateTime.add(now, 60 * 60, :second),
             recurring_series_id: "series-alpha"
           },
           %{
             id: "evt-2",
             title: "Client Review – Contoso",
             start_at: DateTime.add(now, 2 * 60 * 60, :second),
             end_at: DateTime.add(now, 3 * 60 * 60, :second),
             recurring_series_id: "series-contoso"
           }
         ]}

      _ ->
        # TODO: Implement Google Calendar API integration. For now, return empty list.
        {:ok, []}
    end
  end

  @doc """
  Extracts or estimates a recurrence identifier for grouping occurrences.
  """
  @spec recurrence_id(map()) :: String.t() | nil
  def recurrence_id(event) when is_map(event) do
    Map.get(event, "recurringEventId") || Map.get(event, :recurring_series_id)
  end

  defp scrub(opts) do
    # Avoid logging tokens/headers
    Keyword.drop(opts, [:token, :headers])
  end
end
