defmodule DashboardSSDWeb.LayoutsTest do
  use ExUnit.Case, async: true

  alias DashboardSSDWeb.Layouts

  describe "app_version/0" do
    test "returns prefixed version string" do
      assert Layouts.app_version() =~ ~r/^v\d+\.\d+\.\d+/
    end
  end

  describe "header_action_classes/1" do
    test "returns primary classes" do
      assert Layouts.header_action_classes(:primary) =~ "bg-theme-primary"
    end

    test "falls back to ghost classes" do
      ghost = Layouts.header_action_classes(:ghost)
      assert ghost =~ "hover:bg-white/10"

      assert Layouts.header_action_classes(:unknown) == ghost
    end
  end

  describe "default_header_actions/1" do
    test "returns sign-in action when user missing" do
      assert [%{href: "/auth/google", variant: :primary}] = Layouts.default_header_actions(nil)
    end

    test "returns logout action when user present" do
      assert [%{href: "/logout", variant: :ghost}] = Layouts.default_header_actions(%{id: 1})
    end
  end

  describe "user_initials/1" do
    test "derives initials from name" do
      assert Layouts.user_initials(%{name: "Jane Doe"}) == "JD"
    end

    test "derives initials from email" do
      assert Layouts.user_initials(%{email: "user@example.com"}) == "U"
    end

    test "defaults to question mark" do
      assert Layouts.user_initials(nil) == "?"
      assert Layouts.user_initials(%{}) == "?"
    end
  end

  describe "user_display_name/1" do
    test "prefers trimmed name" do
      assert Layouts.user_display_name(%{name: "  Alice  "}) == "Alice"
    end

    test "falls back to email" do
      assert Layouts.user_display_name(%{name: "", email: "alice@example.com"}) ==
               "alice@example.com"
    end

    test "returns nil when unavailable" do
      assert Layouts.user_display_name(nil) == nil
      assert Layouts.user_display_name(%{}) == nil
    end
  end

  describe "user_role/1" do
    test "capitalizes role name" do
      assert Layouts.user_role(%{role: %{name: "admin"}}) == "Admin"
    end

    test "returns nil for missing role" do
      assert Layouts.user_role(nil) == nil
      assert Layouts.user_role(%{}) == nil
    end
  end
end
