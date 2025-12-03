defmodule DashboardSSDWeb.SettingsLive.IndexUnitTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Accounts
  alias DashboardSSD.Repo
  alias DashboardSSDWeb.SettingsLive.Index
  alias Phoenix.LiveView.Socket

  import Phoenix.Component, only: [assign: 2]

  test "mount assigns defaults for anonymous visitor" do
    {:ok, socket} = Index.mount(%{}, %{}, assign(%Socket{}, current_user: nil))

    assert socket.assigns.integrations.google == %{connected: false, details: :missing}
    refute socket.assigns.personal_settings_enabled?
    refute socket.assigns.rbac_enabled?
    assert socket.assigns.users == []
  end

  test "handle_params refreshes integrations" do
    initial = assign(%Socket{}, current_user: nil)
    {:noreply, socket} = Index.handle_params(%{}, "/settings", initial)

    assert socket.assigns.integrations.google == %{connected: false, details: :missing}
  end

  test "toggle_mobile_menu toggles state and close resets it" do
    socket = assign(%Socket{}, mobile_menu_open: false)

    {:noreply, toggled} = Index.handle_event("toggle_mobile_menu", %{}, socket)
    assert toggled.assigns.mobile_menu_open

    {:noreply, closed} = Index.handle_event("close_mobile_menu", %{}, toggled)
    refute closed.assigns.mobile_menu_open
  end

  test "toggle_theme returns socket unchanged" do
    socket = %Socket{}
    assert {:noreply, ^socket} = Index.handle_event("toggle_theme", %{}, socket)
  end

  test "send_invite is ignored when RBAC disabled" do
    socket = %Socket{}
    assert {:noreply, ^socket} = Index.handle_event("send_invite", %{}, socket)
  end

  test "update_user is ignored when RBAC disabled" do
    socket = %Socket{}
    assert {:noreply, ^socket} = Index.handle_event("update_user", %{}, socket)
  end

  test "handle_params flags google integration as connected when identity exists" do
    Accounts.ensure_role!("employee")

    {:ok, user} =
      Accounts.create_user(%{
        email: "connected@slickage.com",
        name: "Connected User",
        role_id: Accounts.ensure_role!("employee").id
      })

    Accounts.upsert_user_with_identity("google", %{
      email: user.email,
      name: user.name,
      provider_id: "google-123",
      token: "token"
    })

    socket =
      assign(%Socket{}, current_user: Repo.preload(user, [:role]))

    {:noreply, updated} = Index.handle_params(%{}, "/settings", socket)

    assert updated.assigns.integrations.google == %{connected: true, details: :ok}
  end

  test "mount marks personal settings as enabled when capability present" do
    Accounts.ensure_role!("employee")

    {:ok, user} =
      Accounts.create_user(%{
        email: "personal@slickage.com",
        name: "Personal",
        role_id: Accounts.ensure_role!("employee").id
      })

    {:ok, _} =
      Accounts.replace_role_capabilities("employee", ["settings.personal"], granted_by_id: nil)

    {:ok, socket} =
      Index.mount(%{}, %{}, assign(%Socket{}, current_user: Repo.preload(user, :role)))

    assert socket.assigns.personal_settings_enabled?
  end

  test "mount disables RBAC sections without capability" do
    Accounts.ensure_role!("employee")

    {:ok, user} =
      Accounts.create_user(%{
        email: "no-rbac@slickage.com",
        name: "No RBAC",
        role_id: Accounts.ensure_role!("employee").id
      })

    {:ok, socket} =
      Index.mount(%{}, %{}, assign(%Socket{}, current_user: Repo.preload(user, :role)))

    refute socket.assigns.rbac_enabled?
    assert socket.assigns.users == []
    assert socket.assigns.pending_invites == []
  end
end
