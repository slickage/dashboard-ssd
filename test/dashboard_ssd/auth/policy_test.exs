defmodule DashboardSSD.Auth.PolicyTest do
  use ExUnit.Case, async: true
  alias DashboardSSD.Auth.Policy

  defp user(role), do: %DashboardSSD.Accounts.User{role: %{name: role}}

  test "admin can do anything" do
    assert Policy.can?(user("admin"), :delete, :projects)
  end

  test "employee can read core subjects" do
    assert Policy.can?(user("employee"), :read, :projects)
    refute Policy.can?(user("employee"), :write, :projects)
  end

  test "client can read projects and kb only" do
    assert Policy.can?(user("client"), :read, :projects)
    refute Policy.can?(user("client"), :write, :projects)
    refute Policy.can?(user("client"), :read, :clients)
  end
end
