defmodule DashboardSSD.Integrations.GoogleCalendarTest do
  use ExUnit.Case, async: true

  alias DashboardSSD.Integrations.GoogleCalendar

  setup do
    prev = Application.get_env(:tesla, :adapter)
    Application.put_env(:tesla, :adapter, Tesla.Mock)

    on_exit(fn ->
      case prev do
        nil -> Application.delete_env(:tesla, :adapter)
        v -> Application.put_env(:tesla, :adapter, v)
      end
    end)

    :ok
  end

  test "list_upcoming_for_user returns sample events when mock: :sample" do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, events} =
      GoogleCalendar.list_upcoming_for_user(123, now, DateTime.add(now, 3600), mock: :sample)

    assert length(events) == 2
    assert Enum.any?(events, &(&1.id == "evt-1"))
  end

  test "list_upcoming returns http_error on non-200" do
    Tesla.Mock.mock(fn
      %{method: :get, url: "https://www.googleapis.com/calendar/v3/calendars/primary/events"} ->
        %Tesla.Env{status: 500, body: %{"error" => "boom"}}
    end)

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    assert {:error, {:http_error, 500, %{"error" => "boom"}}} =
             GoogleCalendar.list_upcoming(now, DateTime.add(now, 3600), token: "t")
  end

  test "list_upcoming maps date and dateTime forms and recurrence id" do
    start_dt = DateTime.from_naive!(~N[2025-01-01 10:00:00], "Etc/UTC")
    end_dt = DateTime.add(start_dt, 3600, :second)

    Tesla.Mock.mock(fn
      %{method: :get, url: "https://www.googleapis.com/calendar/v3/calendars/primary/events"} ->
        %Tesla.Env{
          status: 200,
          body: %{
            "items" => [
              %{
                "id" => "A",
                "summary" => "Title A",
                "start" => %{"dateTime" => DateTime.to_iso8601(start_dt)},
                "end" => %{"dateTime" => DateTime.to_iso8601(end_dt)},
                "recurringEventId" => "r-123"
              },
              %{
                "id" => "B",
                "summary" => "Title B",
                "start" => %{"date" => "2025-01-02"},
                "end" => %{"date" => "2025-01-03"}
              }
            ]
          }
        }
    end)

    {:ok, events} = GoogleCalendar.list_upcoming(start_dt, end_dt, token: "t")
    assert Enum.find(events, &(&1.id == "A"))[:recurring_series_id] == "r-123"
    assert Enum.find(events, &(&1.id == "B"))[:title] == "Title B"
  end
end
