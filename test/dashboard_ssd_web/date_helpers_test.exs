defmodule DashboardSSDWeb.DateHelpersTest do
  use ExUnit.Case, async: true

  alias DashboardSSDWeb.DateHelpers

  test "human_date and human_datetime handle nil and structs" do
    assert DateHelpers.human_date(nil) == "n/a"
    assert DateHelpers.human_datetime(nil) == "n/a"

    d = ~D[2025-11-04]
    assert DateHelpers.human_date(d) =~ "Nov 04, 2025"

    ndt = ~N[2025-11-04 09:30:00]
    assert DateHelpers.human_datetime(ndt) =~ "Nov 04, 2025 · 09:30"

    dt = DateTime.new!(d, ~T[09:30:00], "Etc/UTC")
    assert DateHelpers.human_datetime(dt) =~ "Nov 04, 2025 · 09:30 UTC"
    assert DateHelpers.human_date(dt) =~ "Nov 04, 2025"
  end

  test "localized date/time helpers apply offsets" do
    dt = DateTime.new!(~D[2025-11-04], ~T[09:30:00], "Etc/UTC")

    # UTC-8
    assert DateHelpers.human_datetime_local(dt, -480) =~ "Nov 04, 2025 · 01:30"
    assert DateHelpers.human_date_local(dt, -480) == "Nov 04, 2025"
    assert DateHelpers.human_time_local(dt, -480) == "01:30"

    # UTC+2
    assert DateHelpers.human_datetime_local(dt, 120) =~ "Nov 04, 2025 · 11:30"
    assert DateHelpers.human_date_local(dt, 120) == "Nov 04, 2025"
    assert DateHelpers.human_time_local(dt, 120) == "11:30"
  end

  test "today?/same_day? respect local offset boundaries" do
    # 23:30 UTC on 3rd becomes 15:30 same day at UTC-8
    a = DateTime.new!(~D[2025-11-03], ~T[23:30:00], "Etc/UTC")
    # 00:15 UTC on 4th becomes 16:15 previous day at UTC-8
    b = DateTime.new!(~D[2025-11-04], ~T[00:15:00], "Etc/UTC")

    # In UTC-8, both are on 3rd
    assert DateHelpers.same_day?(a, b, -480)
    refute DateHelpers.same_day?(a, b, 0)

    # today? compares against now; create a value that is today in UTC offset 0
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    assert DateHelpers.today?(now, 0)
  end
end

