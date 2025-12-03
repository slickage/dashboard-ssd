defmodule DashboardSSD.Accounts.RoleCapabilitiesTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Accounts
  alias DashboardSSD.Accounts.RoleCapability

  setup do
    Enum.each(["admin", "employee", "client"], &Accounts.ensure_role!/1)
    :ok
  end

  describe "replace_role_capabilities/3" do
    test "stores a normalized, unique capability list for the role" do
      {:ok, result} =
        Accounts.replace_role_capabilities(
          "employee",
          ["projects.view", "projects.view", " clients.view "],
          granted_by_id: nil
        )

      assert Enum.sort(result) == ["clients.view", "projects.view"]

      assert Enum.sort(Accounts.capabilities_for_role("employee")) == [
               "clients.view",
               "projects.view"
             ]

      {:ok, updated} =
        Accounts.replace_role_capabilities("employee", ["dashboard.view"], granted_by_id: nil)

      assert updated == ["dashboard.view"]
      assert Accounts.capabilities_for_role("employee") == ["dashboard.view"]
    end
  end

  describe "list_role_capabilities/0" do
    test "returns capability records with associated roles preloaded" do
      {:ok, _} = Accounts.replace_role_capabilities("client", ["knowledge_base.view"])

      result = Accounts.list_role_capabilities()

      assert Enum.any?(result, fn
               %RoleCapability{role: %{name: "client"}, capability: "knowledge_base.view"} ->
                 true

               _ ->
                 false
             end)
    end
  end
end
