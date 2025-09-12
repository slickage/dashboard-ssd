defmodule DashboardSSD.ApplicationTest do
  use ExUnit.Case, async: true

  test "config_change returns :ok" do
    assert :ok = DashboardSSD.Application.config_change([], [], [])
  end
end
