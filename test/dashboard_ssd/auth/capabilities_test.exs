defmodule DashboardSSD.Auth.CapabilitiesTest do
  use ExUnit.Case, async: true

  alias DashboardSSD.Auth.Capabilities

  test "codes include expected entries" do
    codes = Capabilities.codes()
    assert "settings.personal" in codes
    assert "settings.rbac" in codes
  end

  test "get returns capability metadata" do
    assert %{} = Capabilities.get("dashboard.view")
    assert Capabilities.get("unknown.capability") == nil
  end

  test "default assignments expose per-role capabilities" do
    defaults = Capabilities.default_assignments()
    assert Map.has_key?(defaults, "admin")
    assert Map.has_key?(defaults, "employee")
    assert Map.has_key?(defaults, "client")
    assert "settings.rbac" in defaults["admin"]
  end

  test "valid? checks capability catalog" do
    assert Capabilities.valid?("clients.view")
    refute Capabilities.valid?("nonexistent.capability")
  end
end
