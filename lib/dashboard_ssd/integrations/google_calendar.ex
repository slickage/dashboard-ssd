defmodule DashboardSSD.Integrations.GoogleCalendar do
  @moduledoc """
  Boundary for interacting with Google Calendar for meeting listings and
  recurrence mapping. This module intentionally exposes a minimal surface for
  the Meetings feature and is designed to be stubbed in tests.
  """

  use Tesla
  require Logger

  @base "https://www.googleapis.com/calendar/v3"

  plug Tesla.Middleware.BaseUrl, @base
  plug Tesla.Middleware.Query
  plug Tesla.Middleware.Headers, [{"content-type", "application/json"}]
  plug Tesla.Middleware.JSON

  @type meeting_event :: %{
          id: String.t(),
          title: String.t(),
          start_at: DateTime.t(),
          end_at: DateTime.t(),
          recurring_series_id: String.t() | nil
        }

  @doc """
  Lists upcoming meetings for the given window.

  Options:
    * `:mock` - set to `:sample` to return sample events
    * `:token` - OAuth access token for Google Calendar API
  """
  @spec list_upcoming(DateTime.t(), DateTime.t(), keyword()) :: {:ok, [meeting_event()]} | {:error, term()}
  def list_upcoming(start_at, end_at, opts \\ []) do
    Logger.debug(fn ->
      %{
        msg: "google_calendar.list_upcoming/3",
        start_at: start_at,
        end_at: end_at,
        opts: Map.new(scrub(opts))
      }
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
        token = Keyword.get(opts, :token)

        # If token is missing, return empty list (wrapper enforces token presence)
        if is_nil(token) or token == "" do
          {:ok, []}
        else
          headers = [{"authorization", "Bearer #{token}"}]
          params = [
            timeMin: DateTime.to_iso8601(start_at),
            timeMax: DateTime.to_iso8601(end_at),
            singleEvents: true,
            orderBy: "startTime"
          ]

          case get("/calendars/primary/events", query: params, headers: headers) do
            {:ok, %Tesla.Env{status: 200, body: body}} ->
              items = Map.get(body, "items") || []
              {:ok, Enum.map(items, &map_event/1)}

            {:ok, %Tesla.Env{status: status, body: body}} ->
              {:error, {:http_error, status, body}}

            {:error, reason} ->
              {:error, reason}
          end
        end
    end
  end

  @doc """
  Extracts or estimates a recurrence identifier for grouping occurrences.
  """
  @spec recurrence_id(map()) :: String.t() | nil
  def recurrence_id(event) when is_map(event) do
    Map.get(event, "recurringEventId") || Map.get(event, :recurring_series_id)
  end

  defp map_event(event) do
    %{
      id: Map.get(event, "id") || Map.get(event, :id),
      title: Map.get(event, "summary") || Map.get(event, :title) || "(untitled)",
      start_at: parse_time(get_in(event, ["start"])) || parse_time(Map.get(event, :start)) || DateTime.utc_now(),
      end_at: parse_time(get_in(event, ["end"])) || parse_time(Map.get(event, :end)) || DateTime.utc_now(),
      recurring_series_id: recurrence_id(event)
    }
  end

  defp parse_time(nil), do: nil
  defp parse_time(%{"dateTime" => dt}) when is_binary(dt) do
    case DateTime.from_iso8601(dt) do
      {:ok, v, _offset} -> v
      _ -> nil
    end
  end

  # All-day events: Google returns exclusive end date.
  defp parse_time(%{"date" => d}) when is_binary(d) do
    with {:ok, date} <- Date.from_iso8601(d),
         {:ok, dt} <- DateTime.new(date, ~T[00:00:00], "Etc/UTC") do
      dt
    else
      _ -> nil
    end
  end

  defp scrub(opts) do
    # Avoid logging tokens/headers
    Keyword.drop(opts, [:token, :headers])
  end
end
