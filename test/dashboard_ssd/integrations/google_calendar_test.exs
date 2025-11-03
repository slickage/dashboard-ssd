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
end

