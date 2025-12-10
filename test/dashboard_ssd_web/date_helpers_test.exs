defmodule DashboardSSDWeb.DateHelpersTest do
  use ExUnit.Case, async: true

  alias DashboardSSDWeb.DateHelpers

  test "human_date handles NaiveDateTime" do
    ndt = ~N[2025-01-02 03:04:05]
    assert DateHelpers.human_date(ndt) == "Jan 02, 2025"
  end

  test "human_date handles nil" do
    assert DateHelpers.human_date(nil) == "n/a"
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

  test "human_datetime formats for DateTime and NaiveDateTime; human_time_local nil" do
    assert DateHelpers.human_datetime(nil) == "n/a"

    dt = DateTime.from_naive!(~N[2025-02-03 04:05:06], "Etc/UTC")
    assert DateHelpers.human_datetime(dt) == "Feb 03, 2025 · 04:05 UTC"

    ndt = ~N[2025-02-03 04:05:06]
    assert DateHelpers.human_datetime(ndt) == "Feb 03, 2025 · 04:05"

    assert DateHelpers.human_time_local(nil, 0) == "n/a"
  end

  test "human_date handles Date and DateTime" do
    d = ~D[2025-01-02]
    assert DateHelpers.human_date(d) == "Jan 02, 2025"

    dt = DateTime.from_naive!(~N[2025-01-02 12:00:00], "Etc/UTC")
    assert DateHelpers.human_date(dt) == "Jan 02, 2025"
  end

  test "today? and same_day? with offsets" do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    assert DateHelpers.today?(now, 0)

    # Naive today
    nn = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    assert DateHelpers.today?(nn, 0)

    # Crossing day boundary with offset
    a = DateTime.from_naive!(~N[2025-01-01 23:30:00], "Etc/UTC")
    b = DateTime.from_naive!(~N[2025-01-02 00:15:00], "Etc/UTC")
    refute DateHelpers.same_day?(a, b, 0)
    # +60 min shifts a into next day
    assert DateHelpers.same_day?(a, b, 60)

    # Exercise naive + datetime clauses
    an = ~N[2025-01-01 10:00:00]
    bn = ~N[2025-01-01 12:00:00]
    assert DateHelpers.same_day?(an, bn, 0)

    # Mixed naive/datetime
    refute DateHelpers.same_day?(an, b, 0)
  end
end
