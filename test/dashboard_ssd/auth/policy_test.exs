defmodule DashboardSSD.Auth.PolicyTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Accounts
  alias DashboardSSD.Auth.Capabilities
  alias DashboardSSD.Auth.Policy

  setup do
    Enum.each(["admin", "employee", "client"], &Accounts.ensure_role!/1)

    Capabilities.default_assignments()
    |> Enum.each(fn {role, caps} ->
      Accounts.ensure_role!(role)
      Accounts.replace_role_capabilities(role, caps, granted_by_id: nil)
    end)

    {:ok,
     admin: build_user("admin"), employee: build_user("employee"), client: build_user("client")}
  end

  test "admin respects capability map but bypasses unmapped actions", _ do
    {:ok, _} =
      Accounts.replace_role_capabilities("admin", [
        "dashboard.view",
        "settings.rbac"
      ])

    admin = build_user("admin")

    refute Policy.can?(admin, :read, :projects)
    assert Policy.can?(admin, :manage, :rbac)
    assert Policy.can?(admin, :delete, :projects)
    assert Policy.can?(admin, :read, :settings)
  end

  test "employee permissions follow stored capabilities", %{employee: employee} do
    assert Policy.can?(employee, :read, :projects)
    refute Policy.can?(employee, :manage, :rbac)

    {:ok, _} =
      Accounts.replace_role_capabilities("employee", ["settings.personal"], granted_by_id: nil)

    employee = build_user("employee")

    refute Policy.can?(employee, :read, :projects)
    assert Policy.can?(employee, :read, :settings)
  end

  test "client limited to default view-only capabilities", %{client: client} do
    assert Policy.can?(client, :read, :projects)
    assert Policy.can?(client, :read, :clients)
    assert Policy.can?(client, :read, :settings)
    refute Policy.can?(client, :read, :knowledge_base)
  end

  test "nil user cannot access anything" do
    refute Policy.can?(nil, :read, :projects)
    refute Policy.can?(nil, :manage, :rbac)
  end

  defp build_user(role_name) do
    role = Accounts.ensure_role!(role_name)

    %Accounts.User{
      id: System.unique_integer([:positive]),
      email: "#{role_name}@slickage.com",
      role: role
    }
  end
end
