defmodule DashboardSSDWeb.NavigationTest do
  use DashboardSSDWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias DashboardSSDWeb.Navigation

  describe "nav/1" do
    test "marks active sidebar link based on current path" do
      html =
        render_component(&Navigation.nav/1, %{
          current_user: nil,
          current_path: "/projects",
          variant: :sidebar
        })

      assert html =~ "data-active=\"true\""
      assert html =~ "hero-squares-2x2-mini"
    end

    test "renders topbar variant with inactive state styles" do
      html =
        render_component(&Navigation.nav/1, %{
          current_user: nil,
          current_path: "/",
          variant: :topbar
        })

      assert html =~ "flex w-full items-center gap-2"
      assert html =~ "text-theme-muted group-hover:text-white"
    end
  end
end
