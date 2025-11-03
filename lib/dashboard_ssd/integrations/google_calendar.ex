defmodule DashboardSSD.Integrations.GoogleCalendar do
  @moduledoc """
  Boundary for interacting with Google Calendar for meeting listings and
  recurrence mapping. This module intentionally exposes a minimal surface for
  the Meetings feature and is designed to be stubbed in tests.
  """

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
  def list_upcoming(_start_at, _end_at, _opts \\ []) do
    # Implementation placeholder – integrate with Google Calendar API.
    {:ok, []}
  end

  @doc """
  Extracts or estimates a recurrence identifier for grouping occurrences.
  """
  @spec recurrence_id(map()) :: String.t() | nil
  def recurrence_id(event) when is_map(event) do
    Map.get(event, "recurringEventId") || Map.get(event, :recurring_series_id)
  end
end

