defmodule DashboardSSDWeb.SettingsLive.RBACSettingsTest do
  use DashboardSSDWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts
  alias DashboardSSD.Auth.Capabilities
  alias Floki

  setup do
    Enum.each(["admin", "employee", "client"], &Accounts.ensure_role!/1)

    {:ok, admin} =
      Accounts.create_user(%{
        email: "admin@example.com",
        name: "Admin",
        role_id: Accounts.ensure_role!("admin").id
      })

    Capabilities.default_assignments()
    |> Enum.each(fn {role, caps} ->
      Accounts.replace_role_capabilities(role, caps, granted_by_id: admin.id)
    end)

    {:ok, conn: Phoenix.ConnTest.init_test_session(build_conn(), %{user_id: admin.id})}
  end

  test "renders RBAC configuration table for admins", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/settings")

    assert html =~ "Role capabilities"
    assert html =~ "Projects (Manage)"
    assert html =~ "data-section=\"settings-personal\""
    assert html =~ "data-section=\"settings-integrations\""
  end

  test "admin mandatory capabilities are locked", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/settings")

    {:ok, document} = Floki.parse_document(html)

    checkbox =
      document
      |> Floki.find("input[type='checkbox'][value='settings.rbac']")
      |> Enum.find(fn {"input", attrs, _} -> {"form", "rbac-form-admin"} in attrs end)

    refute is_nil(checkbox)

    assert Floki.attribute(checkbox, "disabled") != []

    hidden_inputs =
      document
      |> Floki.find("input[type='hidden'][value='settings.rbac']")
      |> Enum.filter(fn {"input", attrs, _} -> {"form", "rbac-form-admin"} in attrs end)

    assert [_] = hidden_inputs

    personal_checkbox =
      document
      |> Floki.find("input[type='checkbox'][value='settings.personal']")
      |> Enum.find(fn {"input", attrs, _} -> {"form", "rbac-form-admin"} in attrs end)

    refute is_nil(personal_checkbox)
    assert Floki.attribute(personal_checkbox, "disabled") == []
  end

  test "submits capability changes and shows flash", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings")

    params = %{"role" => "employee", "capabilities" => ["dashboard.view", "clients.view"]}

    view
    |> element("form[data-role='rbac-role-form'][data-role-name='employee']")
    |> render_change(params)

    assert render(view) =~ "Capabilities updated for employee"

    assert Enum.sort(Accounts.capabilities_for_role("employee")) ==
             Enum.sort(params["capabilities"])
  end

  test "admin can remove personal settings capability", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings")

    params = %{"role" => "admin", "capabilities" => ["settings.rbac"]}

    view
    |> element("form[data-role='rbac-role-form'][data-role-name='admin']")
    |> render_change(params)

    assert render(view) =~ "Capabilities updated for admin"
    assert Accounts.capabilities_for_role("admin") |> Enum.sort() == Enum.sort(["settings.rbac"])
    refute render(view) =~ "data-section=\"settings-personal\""
    assert render(view) =~ "data-section=\"settings-integrations\""
  end

  test "reset defaults restores catalog assignments", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings")

    params = %{"role" => "client", "capabilities" => ["dashboard.view"]}

    view
    |> element("form[data-role='rbac-role-form'][data-role-name='client']")
    |> render_change(params)

    view |> element("form[data-role='rbac-reset-form']") |> render_submit(%{})

    expected = Map.fetch!(Capabilities.default_assignments(), "client")
    assert Enum.sort(Accounts.capabilities_for_role("client")) == Enum.sort(expected)
  end

  test "hides RBAC section when lacking capability", %{conn: conn} do
    {:ok, employee} =
      Accounts.create_user(%{
        email: "employee@example.com",
        name: "Employee",
        role_id: Accounts.ensure_role!("employee").id
      })

    {:ok, _view, html} =
      conn
      |> Phoenix.ConnTest.init_test_session(%{user_id: employee.id})
      |> live(~p"/settings")

    refute html =~ "Role capabilities"
    refute html =~ "data-section=\"settings-integrations\""
  end
end
