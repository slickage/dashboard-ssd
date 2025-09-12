defmodule DashboardSSDWeb.TelemetryTest do
  use ExUnit.Case, async: true

  test "metrics returns list" do
    assert is_list(DashboardSSDWeb.Telemetry.metrics())
  end
end
