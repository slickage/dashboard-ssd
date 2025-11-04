defmodule DashboardSSDWeb.SettingsLive.Index do
  @moduledoc "Settings page for viewing and connecting external integrations."
  use DashboardSSDWeb, :live_view

  alias DashboardSSD.Accounts
  alias DashboardSSD.Accounts.ExternalIdentity
  alias DashboardSSD.Auth.Capabilities
  alias DashboardSSD.Clients
  alias DashboardSSD.Repo
  alias DashboardSSDWeb.SettingsLive.RbacTableComponent

  @impl true
  @doc "Mount Settings view and compute current integration connection states."
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:current_path, "/settings")
      |> assign(:page_title, "Settings")
      |> assign(:integrations, integration_states(socket.assigns[:current_user]))
      |> assign(:mobile_menu_open, false)
      |> assign(
        :personal_settings_enabled?,
        personal_settings_enabled?(socket.assigns[:current_user])
      )
      |> assign(:rbac_enabled?, can_manage_rbac?(socket.assigns[:current_user]))
      |> assign_rbac_context()
      |> assign_user_management()

    {:ok, socket}
  end

  @impl true
  @doc "Handle navigation params; recompute integration states."
  def handle_params(_params, _url, socket) do
    {:noreply,
     socket
     |> assign(:page_title, "Settings")
     |> assign(:integrations, integration_states(socket.assigns[:current_user]))
     |> assign(:mobile_menu_open, false)
     |> assign(
       :personal_settings_enabled?,
       personal_settings_enabled?(socket.assigns[:current_user])
     )
     |> assign(:rbac_enabled?, can_manage_rbac?(socket.assigns[:current_user]))
     |> assign_rbac_context()
     |> assign_user_management()}
  end

  defp integration_states(nil) do
    %{
      google: %{connected: false, details: :missing},
      linear: connected_if_present(linear_token()),
      slack: connected_if_present(slack_token()),
      notion: connected_if_present(notion_token()),
      github: %{connected: false, details: :coming_soon}
    }
  end

  defp integration_states(user) do
    %{
      google: google_state(user),
      linear: connected_if_present(linear_token()),
      slack: connected_if_present(slack_token()),
      notion: connected_if_present(notion_token()),
      github: %{connected: false, details: :coming_soon}
    }
  end

  defp google_state(%{id: user_id}) do
    case Repo.get_by(ExternalIdentity, user_id: user_id, provider: "google") do
      %ExternalIdentity{token: token} when is_binary(token) and byte_size(token) > 0 ->
        %{connected: true, details: :ok}

      _ ->
        %{connected: false, details: :missing}
    end
  end

  defp linear_token do
    Application.get_env(:dashboard_ssd, :integrations, [])[:linear_token]
  end

  defp slack_token do
    Application.get_env(:dashboard_ssd, :integrations, [])[:slack_bot_token]
  end

  defp notion_token do
    Application.get_env(:dashboard_ssd, :integrations, [])[:notion_token]
  end

  defp connected_if_present(val) do
    if is_binary(val) and String.trim(to_string(val)) != "" do
      %{connected: true, details: :ok}
    else
      %{connected: false, details: :missing}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-8">
      <%= if @personal_settings_enabled? do %>
        <!-- Theme Settings -->
        <div class="card" data-role="settings-theme">
          <div class="p-6">
            <h3 class="text-lg font-semibold text-theme-text mb-4">Appearance</h3>
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-theme-text">Theme</p>
                <p class="text-xs text-theme-text-muted">Choose your preferred theme</p>
              </div>
              <div class="flex items-center gap-3">
                <span class="text-sm text-theme-text-muted" id="theme-label">Dark</span>
                <button
                  type="button"
                  id="theme-toggle"
                  class="theme-toggle relative inline-flex h-6 w-11 items-center rounded-full bg-theme-border transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-theme-primary focus:ring-offset-2 focus:ring-offset-theme-surface"
                  phx-click="toggle_theme"
                >
                  <span class="sr-only">Toggle theme</span>
                  <span class="inline-block h-4 w-4 transform rounded-full bg-theme-primary shadow-sm transition-transform duration-200 ease-in-out translate-x-1">
                  </span>
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <%= if @rbac_enabled? do %>
        <div class="theme-card overflow-x-auto" data-role="settings-integrations">
          <table class="theme-table">
            <thead>
              <tr>
                <th>Integration</th>
                <th>Status</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td>Google Drive</td>
                <td>
                  <.status_badge state={@integrations.google} />
                </td>
                <td class="text-sm text-theme-muted">
                  <%= if @integrations.google.connected do %>
                    <span>Linked via Google OAuth</span>
                  <% else %>
                    <.link
                      navigate={~p"/auth/google"}
                      class="text-white/80 transition hover:text-white"
                    >
                      Connect Google
                    </.link>
                  <% end %>
                </td>
              </tr>

              <tr>
                <td>Linear</td>
                <td>
                  <.status_badge state={@integrations.linear} />
                </td>
                <td class="text-sm text-theme-muted">
                  <%= if @integrations.linear.connected do %>
                    <span>Configured via LINEAR_TOKEN</span>
                  <% else %>
                    <span>Set LINEAR_TOKEN or LINEAR_API_KEY</span>
                  <% end %>
                </td>
              </tr>

              <tr>
                <td>Slack</td>
                <td>
                  <.status_badge state={@integrations.slack} />
                </td>
                <td class="text-sm text-theme-muted">
                  <%= if @integrations.slack.connected do %>
                    <span>App token configured</span>
                  <% else %>
                    <span>Add SLACK_BOT_TOKEN</span>
                  <% end %>
                </td>
              </tr>

              <tr>
                <td>Notion</td>
                <td>
                  <.status_badge state={@integrations.notion} />
                </td>
                <td class="text-sm text-theme-muted">
                  <%= if @integrations.notion.connected do %>
                    <span>Integration token active</span>
                  <% else %>
                    <span>Add NOTION_TOKEN</span>
                  <% end %>
                </td>
              </tr>

              <tr>
                <td>GitHub</td>
                <td>
                  <.status_badge state={@integrations.github} />
                </td>
                <td class="text-sm text-theme-muted">Coming soon</td>
              </tr>
            </tbody>
          </table>
        </div>
      <% end %>

      <%= if @rbac_enabled? do %>
        <div class="theme-card overflow-x-auto">
          <div class="flex items-center justify-between border-b border-white/10 px-6 py-4">
            <div>
              <h3 class="text-lg font-semibold text-theme-text">Users</h3>
              <p class="text-xs text-theme-text-muted">Manage roles and client assignments.</p>
            </div>
          </div>
          <table class="theme-table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Email</th>
                <th>Role</th>
                <th>Client</th>
                <th class="w-32">Actions</th>
              </tr>
            </thead>
            <tbody>
              <%= for user <- @users do %>
                <% form_id = "manage-user-" <> to_string(user.id) %>
                <tr>
                  <td>{user.name || "—"}</td>
                  <td class="font-mono text-sm">{user.email}</td>
                  <td>
                    <select
                      form={form_id}
                      name="role"
                      class="w-full rounded-md border border-white/10 bg-white/5 px-2 py-1 text-sm text-white"
                      required
                    >
                      <%= for role <- @roles do %>
                        <option value={role.name} selected={user.role && user.role.name == role.name}>
                          {role.name}
                        </option>
                      <% end %>
                    </select>
                  </td>
                  <td>
                    <select
                      form={form_id}
                      name="client_id"
                      class="w-full rounded-md border border-white/10 bg-white/5 px-2 py-1 text-sm text-white"
                    >
                      <option value="" selected={is_nil(user.client_id)}>
                        {gettext("No client")}
                      </option>
                      <%= for client <- @user_clients do %>
                        <option value={client.id} selected={user.client_id == client.id}>
                          {client.name}
                        </option>
                      <% end %>
                    </select>
                  </td>
                  <td>
                    <form id={form_id} phx-submit="update_user" class="flex items-center justify-end">
                      <input type="hidden" name="user_id" value={user.id} />
                      <button
                        type="submit"
                        class="rounded-full border border-white/10 bg-white/5 px-3 py-1 text-xs font-semibold uppercase tracking-[0.18em] text-white transition hover:border-white/20 hover:bg-white/10"
                      >
                        {gettext("Save")}
                      </button>
                    </form>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <div class="theme-card p-6">
          <h3 class="text-lg font-semibold text-theme-text">Invite Client User</h3>
          <p class="text-xs text-theme-text-muted mb-4">
            Send an invitation email that assigns the role and client automatically after Google sign-in.
          </p>
          <form phx-submit="send_invite" class="flex flex-col gap-4 md:flex-row md:items-end">
            <div class="flex-1 flex flex-col gap-2">
              <label class="text-xs font-semibold uppercase tracking-[0.2em] text-theme-muted">
                Email
              </label>
              <input
                type="email"
                name="invite[email]"
                required
                class="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm text-white focus:border-white/30 focus:outline-none"
              />
            </div>
            <div class="md:w-48 flex flex-col gap-2">
              <label class="text-xs font-semibold uppercase tracking-[0.2em] text-theme-muted">
                Role
              </label>
              <select
                name="invite[role]"
                class="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm text-white focus:border-white/30 focus:outline-none"
              >
                <%= for role <- @roles do %>
                  <option value={role.name} selected={role.name == "client"}>
                    {role.name}
                  </option>
                <% end %>
              </select>
            </div>
            <div class="md:w-56 flex flex-col gap-2">
              <label class="text-xs font-semibold uppercase tracking-[0.2em] text-theme-muted">
                Client
              </label>
              <select
                name="invite[client_id]"
                class="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm text-white focus:border-white/30 focus:outline-none"
              >
                <option value="">Select a client</option>
                <%= for client <- @user_clients do %>
                  <option value={client.id}>{client.name}</option>
                <% end %>
              </select>
            </div>
            <div class="flex w-full items-center justify-end md:w-auto">
              <button
                type="submit"
                class="w-full rounded-full bg-theme-primary px-6 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-white transition hover:bg-theme-primary-soft md:w-auto"
              >
                {gettext("Send invite")}
              </button>
            </div>
          </form>
        </div>

        <%= if @pending_invites != [] do %>
          <div class="theme-card overflow-x-auto">
            <div class="flex items-center justify-between border-b border-white/10 px-6 py-4">
              <div>
                <h3 class="text-lg font-semibold text-theme-text">Pending Invites</h3>
                <p class="text-xs text-theme-text-muted">Awaiting acceptance.</p>
              </div>
            </div>
            <table class="theme-table">
              <thead>
                <tr>
                  <th>Email</th>
                  <th>Role</th>
                  <th>Client</th>
                  <th>Invited</th>
                </tr>
              </thead>
              <tbody>
                <%= for invite <- @pending_invites do %>
                  <tr>
                    <td class="font-mono text-sm">{invite.email}</td>
                    <td>{invite.role_name}</td>
                    <td>{(invite.client && invite.client.name) || "—"}</td>
                    <td>{Calendar.strftime(invite.inserted_at, "%Y-%m-%d %H:%M")}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
      <% end %>

      <%= if @rbac_enabled? do %>
        <.live_component
          module={RbacTableComponent}
          id="rbac-settings"
          roles={@rbac_roles}
          catalog={@capability_catalog}
          current_user={@current_user}
        />
      <% end %>
    </div>
    """
  end

  defp assign_rbac_context(%{assigns: %{rbac_enabled?: false}} = socket) do
    socket
    |> assign(:rbac_roles, [])
    |> assign(:capability_catalog, Capabilities.all())
    |> assign_user_management()
  end

  defp assign_rbac_context(socket) do
    socket
    |> assign(:rbac_roles, Accounts.role_capability_summary())
    |> assign(:capability_catalog, Capabilities.all())
    |> assign_user_management()
  end

  defp assign_user_management(%{assigns: %{rbac_enabled?: false}} = socket) do
    socket
    |> assign(:users, [])
    |> assign(:roles, Accounts.list_roles())
    |> assign(:user_clients, Clients.list_clients())
    |> assign(:pending_invites, [])
    |> assign(:used_invites, [])
  end

  defp assign_user_management(socket) do
    invites = Accounts.list_user_invites()
    {pending, used} = Enum.split_with(invites, &is_nil(&1.used_at))

    socket
    |> assign(:users, Accounts.list_users_with_details())
    |> assign(:roles, Accounts.list_roles())
    |> assign(:user_clients, Clients.list_clients())
    |> assign(:pending_invites, pending)
    |> assign(:used_invites, used)
  end

  defp can_manage_rbac?(nil), do: false

  defp can_manage_rbac?(%{role: nil}), do: false

  defp can_manage_rbac?(user) do
    user
    |> role_capabilities()
    |> Enum.member?("settings.rbac")
  end

  defp role_capabilities(%{role: %{id: role_id}}), do: Accounts.capabilities_for_role(role_id)
  defp role_capabilities(_), do: []

  defp personal_settings_enabled?(user) do
    user
    |> role_capabilities()
    |> Enum.member?("settings.personal")
  end

  @impl true
  def handle_event("update_capabilities", _params, %{assigns: %{rbac_enabled?: false}} = socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_capabilities", params, socket) do
    role = Map.get(params, "role")
    capabilities = List.wrap(Map.get(params, "capabilities"))

    result =
      Accounts.replace_role_capabilities(role, capabilities,
        granted_by_id: socket.assigns[:current_user] && socket.assigns.current_user.id
      )

    current_user = socket.assigns[:current_user]

    socket =
      case result do
        {:ok, _} ->
          socket
          |> assign_rbac_context()
          |> assign(:personal_settings_enabled?, personal_settings_enabled?(current_user))
          |> assign(:integrations, integration_states(current_user))
          |> put_flash(:info, "Capabilities updated for #{role}")

        {:error, {:invalid_capability, code}} ->
          socket
          |> put_flash(:error, "Unknown capability #{code}")
          |> assign(:personal_settings_enabled?, personal_settings_enabled?(current_user))
          |> assign(:integrations, integration_states(current_user))

        {:error, :missing_required_admin_capability} ->
          socket
          |> put_flash(:error, "Admin role must retain required capabilities")
          |> assign(:personal_settings_enabled?, personal_settings_enabled?(current_user))
          |> assign(:integrations, integration_states(current_user))

        {:error, _reason} ->
          socket
          |> put_flash(:error, "Unable to update capabilities")
          |> assign(:personal_settings_enabled?, personal_settings_enabled?(current_user))
          |> assign(:integrations, integration_states(current_user))
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("reset_capabilities", _params, %{assigns: %{rbac_enabled?: false}} = socket) do
    {:noreply, socket}
  end

  def handle_event("reset_capabilities", _params, socket) do
    defaults = Capabilities.default_assignments()

    Enum.each(defaults, fn {role_name, caps} ->
      Accounts.replace_role_capabilities(role_name, caps,
        granted_by_id: socket.assigns[:current_user] && socket.assigns.current_user.id
      )
    end)

    {:noreply,
     socket |> assign_rbac_context() |> put_flash(:info, "Role capabilities reset to defaults")}
  end

  @impl true
  def handle_event(
        "update_user",
        %{"user_id" => user_id, "role" => role, "client_id" => client_id},
        %{assigns: %{rbac_enabled?: true}} = socket
      ) do
    client_id = normalize_form_client_id(client_id)

    case Accounts.update_user_role_and_client(user_id, role, client_id) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> assign_user_management()
         |> put_flash(:info, gettext("User updated."))}

      {:error, reason} ->
        message = invite_error_message(reason)

        {:noreply,
         socket
         |> assign_user_management()
         |> put_flash(:error, message)}
    end
  end

  def handle_event("update_user", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event(
        "send_invite",
        %{"invite" => params},
        %{assigns: %{rbac_enabled?: true, current_user: current_user}} = socket
      ) do
    params =
      params
      |> Map.put("invited_by_id", current_user && current_user.id)

    case Accounts.create_user_invite(params) do
      {:ok, _invite} ->
        {:noreply,
         socket
         |> assign_user_management()
         |> put_flash(:info, gettext("Invitation sent."))}

      {:error, :user_exists} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("A user with that email already exists."))}

      {:error, %Ecto.Changeset{} = changeset} ->
        message = changeset_errors_to_string(changeset)

        {:noreply,
         socket
         |> put_flash(:error, message)}

      {:error, other} ->
        {:noreply,
         socket
         |> put_flash(:error, inspect(other))}
    end
  end

  def handle_event("send_invite", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("toggle_mobile_menu", _params, socket) do
    {:noreply, assign(socket, mobile_menu_open: !socket.assigns.mobile_menu_open)}
  end

  @impl true
  def handle_event("close_mobile_menu", _params, socket) do
    {:noreply, assign(socket, mobile_menu_open: false)}
  end

  @impl true
  def handle_event("toggle_theme", _params, socket) do
    # Theme toggle is handled client-side via JavaScript
    {:noreply, socket}
  end

  defp normalize_form_client_id(nil), do: nil
  defp normalize_form_client_id(""), do: nil

  defp normalize_form_client_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp normalize_form_client_id(value) when is_integer(value), do: value
  defp normalize_form_client_id(_), do: nil

  defp changeset_errors_to_string(changeset) do
    errors =
      changeset
      |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
        Enum.reduce(opts, msg, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", to_string(value))
        end)
      end)

    Enum.map_join(errors, ". ", fn {field, messages} ->
      "#{Phoenix.Naming.humanize(field)} #{Enum.join(messages, ", ")}"
    end)
  end

  defp invite_error_message(%Ecto.Changeset{} = changeset),
    do: changeset_errors_to_string(changeset)

  defp invite_error_message(other), do: inspect(other)
end
