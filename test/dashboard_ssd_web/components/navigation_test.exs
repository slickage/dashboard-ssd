defmodule DashboardSSDWeb.NavigationTest do
  use DashboardSSDWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts
  alias DashboardSSD.Auth.Capabilities
  alias DashboardSSD.Repo
  alias DashboardSSDWeb.Navigation

  setup do
    Enum.each(["admin", "employee", "client"], &Accounts.ensure_role!/1)

    Capabilities.default_assignments()
    |> Enum.each(fn {role, caps} ->
      Accounts.ensure_role!(role)
      Accounts.replace_role_capabilities(role, caps, granted_by_id: nil)
    end)

    admin_role = Accounts.ensure_role!("admin")

    {:ok, admin} =
      Accounts.create_user(%{
        email: "nav-admin@slickage.com",
        name: "Admin",
        role_id: admin_role.id
      })

    admin = Repo.preload(admin, :role)
    {:ok, admin: admin, employee_role: Accounts.ensure_role!("employee")}
  end

  describe "nav/1" do
    test "marks active sidebar link based on current path", %{admin: admin} do
      html =
        render_component(&Navigation.nav/1, %{
          current_user: admin,
          current_path: "/projects",
          variant: :sidebar
        })

      assert html =~ "data-active=\"true\""
      assert html =~ "hero-squares-2x2-mini"
    end

    test "renders topbar variant with inactive state styles", %{admin: admin} do
      html =
        render_component(&Navigation.nav/1, %{
          current_user: admin,
          current_path: "/",
          variant: :topbar
        })

      assert html =~ "flex w-full items-center gap-2"
      assert html =~ "text-theme-muted group-hover:text-white"
    end
  end

  describe "capability filtering" do
    test "admin loses nav items when capability removed", %{admin: admin} do
      {:ok, _} =
        Accounts.replace_role_capabilities("admin", [
          "dashboard.view",
          "settings.personal",
          "settings.rbac"
        ])

      html =
        render_component(&Navigation.nav/1, %{
          current_user: admin,
          current_path: "/projects",
          variant: :sidebar
        })

      refute html =~ "/projects"
    end

    test "hides analytics link when capability missing", %{employee_role: employee_role} do
      user =
        %Accounts.User{id: 1, email: "employee@slickage.com", role: employee_role}

      html =
        render_component(&Navigation.nav/1, %{
          current_user: user,
          current_path: "/projects",
          variant: :sidebar
        })

      refute html =~ "/analytics"
    end

    test "shows clients link only when capability granted", %{employee_role: employee_role} do
      {:ok, _} =
        Accounts.replace_role_capabilities("employee", ["dashboard.view", "settings.personal"],
          granted_by_id: nil
        )

      user = %Accounts.User{id: 2, email: "employee2@slickage.com", role: employee_role}

      html =
        render_component(&Navigation.nav/1, %{
          current_user: user,
          current_path: "/",
          variant: :sidebar
        })

      refute html =~ "/clients"

      {:ok, _} =
        Accounts.replace_role_capabilities("employee", ["clients.view"], granted_by_id: nil)

      user = %Accounts.User{id: 3, email: "employee3@slickage.com", role: employee_role}

      html =
        render_component(&Navigation.nav/1, %{
          current_user: user,
          current_path: "/",
          variant: :sidebar
        })

      assert html =~ "/clients"
    end

    test "settings link persists when admin retains rbac capability", %{admin: admin} do
      {:ok, _} =
        Accounts.replace_role_capabilities("admin", [
          "dashboard.view",
          "settings.rbac"
        ])

      html =
        render_component(&Navigation.nav/1, %{
          current_user: admin,
          current_path: "/settings",
          variant: :sidebar_admin
        })

      assert html =~ "/settings"
    end

    test "client navigation limited to clients and settings" do
      client_role = Accounts.ensure_role!("client")
      user = %Accounts.User{id: 5, email: "client@slickage.com", role: client_role}

      html =
        render_component(&Navigation.nav/1, %{
          current_user: user,
          current_path: "/clients",
          variant: :sidebar
        })

      assert html =~ "/projects"
      assert html =~ "/clients"
      assert html =~ "/settings"
      refute html =~ "/kb"
      refute html =~ "/analytics"
    end
  end

  describe "helpers and drawers" do
    test "github_releases_url returns constant" do
      assert Navigation.github_releases_url() =~ "github.com/slickage/dashboard-ssd/releases"
    end

    test "mobile_drawer shows version and user info", %{admin: admin} do
      html =
        render_component(&Navigation.mobile_drawer/1, %{
          current_user: admin,
          current_path: "/",
          open: true,
          version: "v9.9.9"
        })

      assert html =~ "v9.9.9"
      assert html =~ "DashboardSSD"
      assert html =~ "Admin"
    end

    test "sidebar_footer shows version and initials", %{admin: admin} do
      html = render_component(&Navigation.sidebar_footer/1, %{current_user: admin, version: "v0.2.0"})
      assert html =~ "v0.2.0"
      # Admin name is "Admin" in setup, so initials are "A"
      assert html =~ ">A<"
    end
  end
end
