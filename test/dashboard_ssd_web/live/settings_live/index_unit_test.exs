defmodule DashboardSSDWeb.SettingsLive.IndexUnitTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Accounts
  alias DashboardSSD.Repo
  alias DashboardSSDWeb.SettingsLive.Index
  alias Phoenix.LiveView.Socket
  alias Phoenix.LiveView.Utils, as: LVUtils

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

  describe "update_user linear linking" do
    setup do
      Enum.each(["admin", "employee", "client"], &Accounts.ensure_role!/1)

      admin_role = Accounts.ensure_role!("admin")
      employee_role = Accounts.ensure_role!("employee")

      {:ok, admin} =
        Accounts.create_user(%{
          email: "linear-admin@example.com",
          name: "Linear Admin",
          role_id: admin_role.id
        })

      {:ok, managed} =
        Accounts.create_user(%{
          email: "linear-managed@example.com",
          name: "Linear Managed",
          role_id: employee_role.id
        })

      %{admin: Repo.preload(admin, :role), managed: managed}
    end

    test "links selected Linear member when roster present", %{admin: admin, managed: managed} do
      member = %{
        linear_user_id: "lin_123",
        email: "lin123@example.com",
        name: "Lin Person",
        display_name: "Lin Person",
        avatar_url: "https://example.com/avatar.png"
      }

      socket =
        rbac_socket(admin, %{
          linear_roster: [%{member: member, link: nil}],
          linear_member_lookup: %{"lin_123" => member}
        })

      params = %{
        "user_id" => "#{managed.id}",
        "role" => "employee",
        "client_id" => "",
        "linear_user_id" => "  lin_123  "
      }

      assert {:noreply, _socket} = Index.handle_event("update_user", params, socket)

      link = Accounts.get_linear_user_link_by_user_id(managed.id)
      assert link.linear_user_id == "lin_123"
      assert link.linear_email == "lin123@example.com"
      refute link.auto_linked
    end

    test "unlinks Linear member when selection cleared", %{admin: admin, managed: managed} do
      {:ok, _} =
        Accounts.upsert_linear_user_link(managed, %{
          linear_user_id: "lin_old",
          auto_linked: false
        })

      params = %{
        "user_id" => "#{managed.id}",
        "role" => "employee",
        "client_id" => "",
        "linear_user_id" => ""
      }

      assert {:noreply, _socket} = Index.handle_event("update_user", params, rbac_socket(admin))

      assert Accounts.get_linear_user_link_by_user_id(managed.id) == nil
    end

    test "shows error when linking before Linear roster sync", %{admin: admin, managed: managed} do
      params = %{
        "user_id" => "#{managed.id}",
        "role" => "employee",
        "client_id" => "",
        "linear_user_id" => "lin_missing"
      }

      assert {:noreply, socket} = Index.handle_event("update_user", params, rbac_socket(admin))

      assert socket.assigns.flash["error"] =~ "Linear isn't synced yet"
      assert Accounts.get_linear_user_link_by_user_id(managed.id) == nil
    end

    test "shows error when selected Linear member is missing", %{admin: admin, managed: managed} do
      member = %{
        linear_user_id: "lin_missing",
        email: "missing@example.com",
        name: "Missing Member",
        display_name: "Missing Member"
      }

      socket =
        rbac_socket(admin, %{
          linear_roster: [%{member: member, link: nil}],
          linear_member_lookup: %{}
        })

      params = %{
        "user_id" => "#{managed.id}",
        "role" => "employee",
        "client_id" => "",
        "linear_user_id" => "lin_missing"
      }

      assert {:noreply, socket} = Index.handle_event("update_user", params, socket)
      assert socket.assigns.flash["error"] =~ "Selected Linear user is no longer available"
      assert Accounts.get_linear_user_link_by_user_id(managed.id) == nil
    end

    test "ignores Linear changes when user identifier is an email", %{
      admin: admin,
      managed: managed
    } do
      member = %{
        linear_user_id: "lin_email_id",
        email: "lin-email@example.com",
        name: "Linear Email",
        display_name: "Linear Email"
      }

      socket =
        rbac_socket(admin, %{
          linear_roster: [%{member: member, link: nil}],
          linear_member_lookup: %{"lin_email_id" => member}
        })

      params = %{
        "user_id" => managed.email,
        "role" => "employee",
        "client_id" => "",
        "linear_user_id" => "lin_email_id"
      }

      assert {:noreply, socket} = Index.handle_event("update_user", params, socket)
      assert socket.assigns.flash["info"] == "User updated."
      refute Map.has_key?(socket.assigns.flash, "error")
      assert Accounts.get_linear_user_link_by_user_id(managed.id) == nil
    end
  end

  describe "update_capabilities events" do
    setup do
      Enum.each(["admin", "employee"], &Accounts.ensure_role!/1)

      admin_role = Accounts.ensure_role!("admin")

      {:ok, admin} =
        Accounts.create_user(%{
          email: "caps-admin@example.com",
          name: "Caps Admin",
          role_id: admin_role.id
        })

      %{admin: Repo.preload(admin, :role)}
    end

    test "no-ops when RBAC disabled", %{admin: _admin} do
      socket = assign(%Socket{}, rbac_enabled?: false)
      assert {:noreply, ^socket} = Index.handle_event("update_capabilities", %{}, socket)
    end

    test "persists capability changes", %{admin: admin} do
      socket = rbac_socket(admin)

      params = %{
        "role" => "employee",
        "capabilities" => ["settings.personal"]
      }

      assert {:noreply, socket} = Index.handle_event("update_capabilities", params, socket)
      assert socket.assigns.flash["info"] == "Capabilities updated for employee"
    end

    test "shows error for invalid capability codes", %{admin: admin} do
      socket = rbac_socket(admin)

      params = %{
        "role" => "employee",
        "capabilities" => ["unknown.capability"]
      }

      assert {:noreply, socket} = Index.handle_event("update_capabilities", params, socket)
      assert socket.assigns.flash["error"] =~ "Unknown capability"
    end

    test "prevents removing required admin capabilities", %{admin: admin} do
      socket = rbac_socket(admin)

      params = %{
        "role" => "admin",
        "capabilities" => []
      }

      assert {:noreply, socket} = Index.handle_event("update_capabilities", params, socket)
      assert socket.assigns.flash["error"] =~ "Admin role must retain required capabilities"
    end
  end

  describe "reset_capabilities event" do
    setup do
      Enum.each(["admin", "employee"], &Accounts.ensure_role!/1)

      admin_role = Accounts.ensure_role!("admin")

      {:ok, admin} =
        Accounts.create_user(%{
          email: "reset-admin@example.com",
          name: "Reset Admin",
          role_id: admin_role.id
        })

      %{admin: Repo.preload(admin, :role)}
    end

    test "no-ops when RBAC disabled" do
      socket = assign(%Socket{}, rbac_enabled?: false)
      assert {:noreply, ^socket} = Index.handle_event("reset_capabilities", %{}, socket)
    end

    test "resets capabilities and flashes info when allowed", %{admin: admin} do
      socket = rbac_socket(admin)

      assert {:noreply, socket} = Index.handle_event("reset_capabilities", %{}, socket)
      assert socket.assigns.flash["info"] =~ "Role capabilities reset to defaults"
    end
  end

  defp rbac_socket(user, extra_assigns \\ %{}) do
    base_assigns = %{
      current_user: user,
      rbac_enabled?: true,
      linear_roster: [],
      linear_member_lookup: %{},
      personal_settings_enabled?: true,
      integrations: %{
        google: %{connected: false, details: :missing},
        linear: %{connected: false, details: :missing}
      },
      users: [],
      roles: [],
      user_clients: [],
      pending_invites: [],
      used_invites: [],
      invite_form: nil
    }

    %Socket{}
    |> LVUtils.clear_flash()
    |> assign(Map.merge(base_assigns, extra_assigns))
  end
end
