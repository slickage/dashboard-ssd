defmodule DashboardSSD.Integrations.GoogleCalendarTest do
  use ExUnit.Case, async: true

  alias DashboardSSD.Integrations.GoogleCalendar

  test "recurrence_id extracts from various shapes" do
    assert GoogleCalendar.recurrence_id(%{"recurringEventId" => "series-1"}) == "series-1"
    assert GoogleCalendar.recurrence_id(%{recurring_series_id: "series-2"}) == "series-2"
    assert GoogleCalendar.recurrence_id(%{}) == nil
  end

  test "list_upcoming returns ok tuple (skeleton)" do
    now = DateTime.utc_now()
    later = DateTime.add(now, 3600, :second)
    assert {:ok, list} = GoogleCalendar.list_upcoming(now, later)
    assert is_list(list)
  end

  test "list_upcoming transforms API response (dateTime and date)" do
    now = ~U[2025-11-04 00:00:00Z]
    later = DateTime.add(now, 3600, :second)

    Tesla.Mock.mock(fn
      %{
        method: :get,
        url: "https://www.googleapis.com/calendar/v3/calendars/primary/events",
        headers: headers,
        query: query
      } ->
        # Ensure Authorization header present
        assert Enum.any?(headers, fn {k, v} ->
                 k == "authorization" and String.starts_with?(v, "Bearer ")
               end)

        # Ensure typical query keys present
        assert Enum.any?(query, fn {k, _} -> k in [:timeMin, :timeMax] end)

        %Tesla.Env{
          status: 200,
          body: %{
            "items" => [
              %{
                "id" => "evt-dt",
                "summary" => "Design Sync",
                "start" => %{"dateTime" => "2025-11-04T09:00:00Z"},
                "end" => %{"dateTime" => "2025-11-04T10:00:00Z"},
                "recurringEventId" => "series-dt"
              },
              %{
                "id" => "evt-all",
                "summary" => "All-day Planning",
                "start" => %{"date" => "2025-11-05"},
                "end" => %{"date" => "2025-11-06"}
              }
            ]
          }
        }
    end)

    assert {:ok, events} = GoogleCalendar.list_upcoming(now, later, token: "tok")

    assert [
             %{id: "evt-dt", title: "Design Sync", start_at: %DateTime{}, end_at: %DateTime{}},
             %{
               id: "evt-all",
               title: "All-day Planning",
               start_at: %DateTime{},
               end_at: %DateTime{}
             }
           ] = events

    dt = Enum.find(events, &(&1.id == "evt-dt"))
    assert DateTime.to_iso8601(dt.start_at) == "2025-11-04T09:00:00Z"
    assert DateTime.to_iso8601(dt.end_at) == "2025-11-04T10:00:00Z"

    allday = Enum.find(events, &(&1.id == "evt-all"))
    # All-day start at midnight UTC on the given date
    assert DateTime.to_iso8601(allday.start_at) == "2025-11-05T00:00:00Z"
  end
end
