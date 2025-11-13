defmodule DashboardSSDWeb.SettingsLive.Index do
  @moduledoc """
  Settings page for viewing and connecting external integrations.

    - Surfaces personal settings, RBAC management, and integration connection status.
  - Manages invites, user role/client assignments, and Linear linking workflows.
  - Enforces capability gates so only authorized users see RBAC/user-management controls.
  """
  use DashboardSSDWeb, :live_view

  alias DashboardSSD.Accounts
  alias DashboardSSD.Accounts.ExternalIdentity
  alias DashboardSSD.Auth.Capabilities
  alias DashboardSSD.Clients
  alias DashboardSSD.Repo
  alias DashboardSSDWeb.SettingsLive.RbacTableComponent
  alias Ecto.Changeset

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
    <div class="flex flex-col gap-10">
      <section
        :if={@personal_settings_enabled?}
        class="card space-y-6"
        data-section="settings-personal"
      >
        <header class="space-y-1">
          <h2 class="text-xl font-semibold text-theme-text">{gettext("Personal preferences")}</h2>
          <p class="text-sm text-theme-text-muted">
            {gettext("Control how the dashboard looks just for you.")}
          </p>
        </header>

        <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p class="text-sm font-medium text-theme-text">{gettext("Theme")}</p>
            <p class="text-xs text-theme-text-muted">
              {gettext("Toggle between light and dark modes at any time.")}
            </p>
          </div>
          <div class="flex items-center gap-3">
            <span class="text-sm text-theme-text-muted" id="theme-label">{gettext("Dark")}</span>
            <button
              type="button"
              id="theme-toggle"
              class="theme-toggle relative inline-flex h-6 w-11 items-center rounded-full bg-theme-border transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-theme-primary focus:ring-offset-2 focus:ring-offset-theme-surface"
              phx-click="toggle_theme"
            >
              <span class="sr-only">{gettext("Toggle theme")}</span>
              <span class="inline-block h-4 w-4 translate-x-1 transform rounded-full bg-theme-primary shadow-sm transition-transform duration-200 ease-in-out">
              </span>
            </button>
          </div>
        </div>
      </section>

      <section
        :if={@rbac_enabled?}
        class="card space-y-6"
        data-section="settings-integrations"
      >
        <header class="space-y-1">
          <h2 class="text-xl font-semibold text-theme-text">{gettext("Integrations")}</h2>
          <p class="text-sm text-theme-text-muted">
            {gettext("Review which services are connected and where attention is needed.")}
          </p>
        </header>

        <div class="overflow-x-auto">
          <table class="theme-table">
            <thead>
              <tr>
                <th>{gettext("Integration")}</th>
                <th>{gettext("Status")}</th>
                <th>{gettext("Details")}</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td>{gettext("Google")}</td>
                <td>
                  <.status_badge state={@integrations.google} />
                </td>
                <td class="text-sm text-theme-text-muted">
                  <%= if @integrations.google.connected do %>
                    <span>{gettext("Linked via Google OAuth")}</span>
                  <% else %>
                    <.link
                      navigate={~p"/auth/google"}
                      class="text-theme-primary transition hover:text-theme-primary-soft"
                    >
                      {gettext("Connect Google")}
                    </.link>
                  <% end %>
                </td>
              </tr>

              <tr>
                <td>{gettext("Linear")}</td>
                <td>
                  <.status_badge state={@integrations.linear} />
                </td>
                <td class="text-sm text-theme-text-muted">
                  <%= if @integrations.linear.connected do %>
                    <span>{gettext("Configured via LINEAR_TOKEN")}</span>
                  <% else %>
                    <span>{gettext("Set LINEAR_TOKEN or LINEAR_API_KEY")}</span>
                  <% end %>
                </td>
              </tr>

              <tr>
                <td>{gettext("Slack")}</td>
                <td>
                  <.status_badge state={@integrations.slack} />
                </td>
                <td class="text-sm text-theme-text-muted">
                  <%= if @integrations.slack.connected do %>
                    <span>{gettext("App token configured")}</span>
                  <% else %>
                    <span>{gettext("Add SLACK_BOT_TOKEN")}</span>
                  <% end %>
                </td>
              </tr>

              <tr>
                <td>{gettext("Notion")}</td>
                <td>
                  <.status_badge state={@integrations.notion} />
                </td>
                <td class="text-sm text-theme-text-muted">
                  <%= if @integrations.notion.connected do %>
                    <span>{gettext("Integration token active")}</span>
                  <% else %>
                    <span>{gettext("Add NOTION_TOKEN")}</span>
                  <% end %>
                </td>
              </tr>

              <tr>
                <td>{gettext("GitHub")}</td>
                <td>
                  <.status_badge state={@integrations.github} />
                </td>
                <td class="text-sm text-theme-text-muted">
                  {gettext("Coming soon")}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <section
        :if={@rbac_enabled?}
        class="card space-y-6"
        data-section="settings-users"
      >
        <header class="space-y-1">
          <h2 class="text-xl font-semibold text-theme-text">{gettext("User management")}</h2>
          <p class="text-sm text-theme-text-muted">
            {gettext("Adjust roles and client assignments for teammates.")}
          </p>
        </header>

        <%= if Enum.empty?(@users) do %>
          <div class="rounded-xl border border-dashed border-theme-border px-4 py-8 text-center">
            <p class="text-sm text-theme-text-muted">
              {gettext("No additional users are connected yet.")}
            </p>
          </div>
        <% else %>
          <div class="overflow-x-auto">
            <table class="theme-table" data-role="user-management-table">
              <thead>
                <tr>
                  <th>{gettext("Name")}</th>
                  <th>{gettext("Email")}</th>
                  <th>{gettext("Role")}</th>
                  <th>{gettext("Client")}</th>
                  <th>{gettext("Linear user")}</th>
                  <th class="w-32 text-right">{gettext("Action")}</th>
                </tr>
              </thead>
              <tbody>
                <%= for user <- @users do %>
                  <% form_id = "manage-user-#{user.id}" %>
                  <tr>
                    <td>
                      <div class="flex flex-col">
                        <span class="font-semibold text-theme-text">{user.name || "—"}</span>
                        <span class="text-xs text-theme-text-muted md:hidden">{user.email}</span>
                      </div>
                    </td>
                    <td class="font-mono text-sm text-theme-text">{user.email}</td>
                    <td>
                      <select
                        name="role"
                        form={form_id}
                        class="w-full rounded-lg border border-theme-border bg-theme-surface px-3 py-2 text-sm text-theme-text focus:border-theme-primary focus:outline-none focus:ring-2 focus:ring-theme-primary focus:ring-opacity-25"
                        required
                      >
                        <%= for role <- @roles do %>
                          <option
                            value={role.name}
                            selected={user.role && user.role.name == role.name}
                          >
                            {role.name}
                          </option>
                        <% end %>
                      </select>
                    </td>
                    <td>
                      <select
                        name="client_id"
                        form={form_id}
                        class="w-full rounded-lg border border-theme-border bg-theme-surface px-3 py-2 text-sm text-theme-text focus:border-theme-primary focus:outline-none focus:ring-2 focus:ring-theme-primary focus:ring-opacity-25"
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
                      <select
                        name="linear_user_id"
                        form={form_id}
                        class="w-full rounded-lg border border-theme-border bg-theme-surface px-3 py-2 text-sm text-theme-text focus:border-theme-primary focus:outline-none focus:ring-2 focus:ring-theme-primary focus:ring-opacity-25"
                        disabled={@linear_roster == []}
                      >
                        <option value="">
                          {blank_linear_option_label(user, @linear_roster)}
                        </option>
                        <%= for {label, linear_id} <- linear_user_options(@linear_roster, user) do %>
                          <option
                            value={linear_id}
                            selected={
                              user.linear_user_link &&
                                user.linear_user_link.linear_user_id == linear_id
                            }
                          >
                            {label}
                          </option>
                        <% end %>
                      </select>

                      <%= if info = linear_link_badge(user) do %>
                        <p class="mt-1 text-xs text-theme-text-muted">{info}</p>
                      <% end %>
                    </td>
                    <td class="text-right">
                      <button
                        type="submit"
                        form={form_id}
                        class="inline-flex items-center justify-center rounded-md border border-theme-border bg-theme-surface px-3 py-1 text-xs font-semibold uppercase tracking-[0.18em] text-theme-text transition hover:bg-white/10 focus:outline-none focus:ring-2 focus:ring-theme-primary focus:ring-offset-2"
                        phx-disable-with={gettext("Saving…")}
                      >
                        {gettext("Save")}
                      </button>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>

          <div class="hidden">
            <%= for user <- @users do %>
              <form id={"manage-user-#{user.id}"} phx-submit="update_user">
                <input type="hidden" name="user_id" value={user.id} />
              </form>
            <% end %>
          </div>
        <% end %>
      </section>

      <section
        :if={@rbac_enabled?}
        class="card space-y-6"
        data-section="settings-invites"
      >
        <header class="space-y-1">
          <h2 class="text-xl font-semibold text-theme-text">{gettext("Invite people")}</h2>
          <p class="text-sm text-theme-text-muted">
            {gettext(
              "Send Google OAuth invitations with the right role and client access pre-selected."
            )}
          </p>
        </header>

        <.form
          for={@invite_form}
          id="invite-form"
          class="space-y-4"
          phx-change="validate_invite"
          phx-submit="send_invite"
        >
          <div
            class="flex flex-col gap-4 md:flex-row md:items-end md:gap-6"
            data-role="invite-create"
          >
            <div class="flex-1">
              <.input
                field={@invite_form[:email]}
                type="email"
                label={gettext("Email address")}
                placeholder="client@example.com"
                phx-debounce="300"
                required
              />
            </div>

            <div class="md:w-48">
              <.input
                field={@invite_form[:role]}
                type="select"
                label={gettext("Role")}
                options={role_options(@roles)}
              />
            </div>

            <div class="md:w-60">
              <.input
                field={@invite_form[:client_id]}
                type="select"
                label={gettext("Client (optional)")}
                prompt={gettext("No client")}
                options={client_options(@user_clients)}
              />
            </div>

            <div class="md:w-auto">
              <.button
                type="submit"
                class="btn-primary"
                disabled={invite_submit_disabled?(@invite_form)}
              >
                {gettext("Send invite")}
              </.button>
            </div>
          </div>
        </.form>

        <p class="text-xs text-theme-text-muted">
          {gettext("Invites never expire and remain pending until accepted.")}
        </p>

        <div :if={@pending_invites != []} class="space-y-3">
          <h3 class="text-sm font-semibold text-theme-text">{gettext("Pending invites")}</h3>
          <div class="overflow-x-auto">
            <table class="theme-table">
              <thead>
                <tr>
                  <th>{gettext("Email")}</th>
                  <th>{gettext("Role")}</th>
                  <th>{gettext("Client")}</th>
                  <th>{gettext("Invited on")}</th>
                </tr>
              </thead>
              <tbody>
                <%= for invite <- @pending_invites do %>
                  <tr>
                    <td class="text-sm">{invite.email}</td>
                    <td class="capitalize">{invite.role_name}</td>
                    <td>{(invite.client && invite.client.name) || gettext("No client")}</td>
                    <td class="text-sm text-theme-text-muted">
                      {Calendar.strftime(invite.inserted_at, "%Y-%m-%d %H:%M")}
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>

        <div :if={@used_invites != []} class="space-y-3">
          <h3 class="text-sm font-semibold text-theme-text">{gettext("Recently accepted")}</h3>
          <div class="overflow-x-auto">
            <table class="theme-table">
              <thead>
                <tr>
                  <th>{gettext("Email")}</th>
                  <th>{gettext("Role")}</th>
                  <th>{gettext("Client")}</th>
                  <th>{gettext("Accepted on")}</th>
                </tr>
              </thead>
              <tbody>
                <%= for invite <- @used_invites do %>
                  <tr>
                    <td class="text-sm">{invite.email}</td>
                    <td class="capitalize">{invite.role_name}</td>
                    <td>{(invite.client && invite.client.name) || gettext("No client")}</td>
                    <td class="text-sm text-theme-text-muted">
                      {Calendar.strftime(invite.used_at, "%Y-%m-%d %H:%M")}
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      </section>

      <section
        :if={@rbac_enabled?}
        class="card space-y-6"
        data-section="settings-rbac"
      >
        <header class="space-y-1">
          <h2 class="text-xl font-semibold text-theme-text">{gettext("Role capabilities")}</h2>
          <p class="text-sm text-theme-text-muted">
            {gettext("Fine-tune which actions each role can take across Dashboard SSD.")}
          </p>
        </header>

        <.live_component
          module={RbacTableComponent}
          id="rbac-settings"
          roles={@rbac_roles}
          catalog={@capability_catalog}
          current_user={@current_user}
        />
      </section>

      <section
        :if={!@personal_settings_enabled? and !@rbac_enabled?}
        class="card space-y-2"
        data-section="settings-empty"
      >
        <h2 class="text-xl font-semibold text-theme-text">{gettext("No settings available")}</h2>
        <p class="text-sm text-theme-text-muted">
          {gettext(
            "Ask an administrator to grant you additional capabilities if you need access to these controls."
          )}
        </p>
      </section>
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
    |> assign(:linear_roster, [])
    |> assign(:linear_member_lookup, %{})
    |> assign(:pending_invites, [])
    |> assign(:used_invites, [])
    |> assign(:invite_form, invite_form())
  end

  defp assign_user_management(socket) do
    invites = Accounts.list_user_invites()
    {pending, used} = Enum.split_with(invites, &is_nil(&1.used_at))
    linear_roster = Accounts.linear_roster_with_links()

    socket
    |> assign(:users, Accounts.list_users_with_details())
    |> assign(:roles, Accounts.list_roles())
    |> assign(:user_clients, Clients.list_clients())
    |> assign(:linear_roster, linear_roster)
    |> assign(:linear_member_lookup, build_linear_member_lookup(linear_roster))
    |> assign(:pending_invites, pending)
    |> assign(:used_invites, used)
    |> assign(:invite_form, invite_form())
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
        %{"user_id" => user_id, "role" => role, "client_id" => client_id} = params,
        %{assigns: %{rbac_enabled?: true}} = socket
      ) do
    client_id = normalize_form_client_id(client_id)
    linear_user_id = normalize_linear_user_id(Map.get(params, "linear_user_id"))

    case Accounts.update_user_role_and_client(user_id, role, client_id) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> maybe_update_linear_link(user_id, linear_user_id)
         |> assign_user_management()
         |> put_flash(:info, gettext("User updated."))}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, invite_error_message(reason))}
    end
  end

  def handle_event("update_user", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("validate_invite", %{"invite" => params}, socket) do
    {:noreply, assign(socket, :invite_form, invite_form(params, validate: true))}
  end

  def handle_event("validate_invite", _params, socket), do: {:noreply, socket}

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
         assign(
           socket,
           :invite_form,
           invite_form(params,
             validate: true,
             errors: [email: gettext("A user with that email already exists.")]
           )
         )}

      {:error, :invalid_email} ->
        {:noreply, assign(socket, :invite_form, invite_form(params, validate: true))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:invite_form, invite_form(params, validate: true))
         |> put_flash(:error, changeset_errors_to_string(changeset))}

      {:error, other} ->
        {:noreply,
         socket
         |> assign(:invite_form, invite_form(params, validate: true))
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

  defp normalize_linear_user_id(nil), do: nil
  defp normalize_linear_user_id(""), do: nil

  defp normalize_linear_user_id(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_linear_user_id(value), do: normalize_linear_user_id(to_string(value))

  defp role_options(roles) do
    Enum.map(roles, &{&1.name, &1.name})
  end

  defp client_options(clients) do
    Enum.map(clients, &{&1.name, &1.id})
  end

  defp linear_user_options(roster, user) do
    roster
    |> Enum.filter(fn
      %{member: %{linear_user_id: nil}} -> false
      %{link: nil} -> true
      %{link: %{user_id: user_id}} -> user.id == user_id
    end)
    |> Enum.map(fn %{member: member} -> {linear_member_label(member), member.linear_user_id} end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp linear_member_label(member) do
    cond do
      member.display_name && member.email ->
        "#{member.display_name} (#{member.email})"

      member.display_name ->
        member.display_name

      member.name ->
        member.name

      true ->
        member.linear_user_id
    end
  end

  defp blank_linear_option_label(_user, []), do: gettext("Sync Linear to link users")

  defp blank_linear_option_label(%{linear_user_link: %{}}, _roster),
    do: gettext("Unlink Linear user")

  defp blank_linear_option_label(_user, _roster), do: gettext("Not linked")

  defp linear_link_badge(_), do: nil

  defp invite_form(attrs \\ %{}, opts \\ []) do
    validate? = Keyword.get(opts, :validate, false)
    errors = Keyword.get(opts, :errors, [])

    changeset =
      Accounts.change_user_invite(attrs, validate: validate?)

    changeset =
      Enum.reduce(errors, changeset, fn {field, message}, acc ->
        Changeset.add_error(acc, field, message)
      end)

    changeset = Map.put(changeset, :action, if(validate?, do: :validate, else: nil))

    Phoenix.Component.to_form(changeset, as: :invite)
  end

  defp invite_submit_disabled?(%Phoenix.HTML.Form{source: %Changeset{} = changeset}) do
    email =
      changeset.changes
      |> Map.get(:email)
      |> case do
        nil -> ""
        value -> String.trim(to_string(value))
      end

    cond do
      email == "" -> true
      changeset.action in [:validate, :insert] and not changeset.valid? -> true
      true -> false
    end
  end

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

  defp invite_error_message(:user_exists),
    do: gettext("A user with that email already exists.")

  defp invite_error_message(:invalid_email),
    do: gettext("Please provide a valid email address.")

  defp invite_error_message(other), do: inspect(other)

  defp maybe_update_linear_link(socket, user_id_param, nil) do
    case coerce_user_id_param(user_id_param) do
      {:ok, user_id} -> Accounts.unlink_linear_user(user_id)
      :error -> :ok
    end

    socket
  end

  defp maybe_update_linear_link(socket, user_id_param, linear_user_id) do
    case coerce_user_id_param(user_id_param) do
      {:ok, user_id} ->
        if socket.assigns.linear_roster == [] do
          put_flash(
            socket,
            :error,
            gettext("Linear isn't synced yet. Connect Linear to link users.")
          )
        else
          update_linear_link(socket, user_id, linear_user_id)
        end

      :error ->
        socket
    end
  end

  defp update_linear_link(socket, user_id, linear_user_id) do
    lookup = socket.assigns[:linear_member_lookup] || %{}

    case Map.get(lookup, linear_user_id) do
      nil ->
        put_flash(
          socket,
          :error,
          gettext("Selected Linear user is no longer available. Refresh and try again.")
        )

      member ->
        attrs = %{
          linear_user_id: linear_user_id,
          linear_email: member.email,
          linear_name: member.name,
          linear_display_name: member.display_name || member.name,
          linear_avatar_url: member.avatar_url,
          auto_linked: false
        }

        case Accounts.upsert_linear_user_link(user_id, attrs) do
          {:ok, _} ->
            socket

          {:error, changeset} ->
            put_flash(socket, :error, changeset_errors_to_string(changeset))
        end
    end
  end

  defp coerce_user_id_param(value) when is_integer(value) and value >= 0,
    do: {:ok, value}

  defp coerce_user_id_param(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int >= 0 -> {:ok, int}
      _ -> :error
    end
  end

  defp coerce_user_id_param(_), do: :error

  defp build_linear_member_lookup(roster) do
    roster
    |> Enum.reduce(%{}, fn %{member: member}, acc ->
      case member.linear_user_id do
        nil -> acc
        "" -> acc
        id -> Map.put(acc, id, member)
      end
    end)
  end
end
