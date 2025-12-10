defmodule DashboardSSDWeb.DateHelpersTest do
  use ExUnit.Case, async: true

  alias DashboardSSDWeb.DateHelpers

  test "human_date handles NaiveDateTime" do
    ndt = ~N[2025-01-02 03:04:05]
    assert DateHelpers.human_date(ndt) == "Jan 02, 2025"
  end

  test "human_date_local shifts date by offset for naive and datetime" do
    ndt = ~N[2025-01-01 23:30:00]
    # +60 minutes should push to next day
    assert DateHelpers.human_date_local(ndt, 60) == "Jan 02, 2025"

    dt = DateTime.from_naive!(~N[2025-01-01 23:30:00], "Etc/UTC")
    assert DateHelpers.human_date_local(dt, 60) == "Jan 02, 2025"
  end

  test "human_datetime_local and human_time_local" do
    assert DateHelpers.human_datetime_local(nil, 0) == "n/a"

    ndt = ~N[2025-04-05 06:07:08]
    assert DateHelpers.human_datetime_local(ndt, 0) == "Apr 05, 2025 · 06:07"
    # human_time_local extracts trailing time
    assert DateHelpers.human_time_local(ndt, 0) == "06:07"

    dt = DateTime.from_naive!(~N[2025-04-05 06:07:08], "Etc/UTC")
    assert DateHelpers.human_time_local(dt, 0) == "06:07"
  end

  test "today? and same_day? with offsets" do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    assert DateHelpers.today?(now, 0)

    # Crossing day boundary with offset
    a = DateTime.from_naive!(~N[2025-01-01 23:30:00], "Etc/UTC")
    b = DateTime.from_naive!(~N[2025-01-02 00:15:00], "Etc/UTC")
    refute DateHelpers.same_day?(a, b, 0)
    # +60 min shifts a into next day
    assert DateHelpers.same_day?(a, b, 60)
  end
end
