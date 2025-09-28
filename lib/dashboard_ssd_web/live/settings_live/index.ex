defmodule DashboardSSDWeb.SettingsLive.Index do
  @moduledoc "Settings page for viewing and connecting external integrations."
  use DashboardSSDWeb, :live_view

  alias DashboardSSD.Accounts.ExternalIdentity
  alias DashboardSSD.Repo

  @impl true
  @doc "Mount Settings view and compute current integration connection states."
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_path, "/settings")
     |> assign(:page_title, "Settings")
     |> assign(:integrations, integration_states(socket.assigns[:current_user]))
     |> assign(:mobile_menu_open, false)}
  end

  @impl true
  @doc "Handle navigation params; recompute integration states."
  def handle_params(_params, _url, socket) do
    {:noreply,
     socket
     |> assign(:page_title, "Settings")
     |> assign(:integrations, integration_states(socket.assigns[:current_user]))
     |> assign(:mobile_menu_open, false)}
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

  # UI helpers
  attr :state, :map, required: true

  defp status_badge(assigns) do
    if assigns.state[:connected] do
      ~H"""
      <span class="inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium theme-status-connected">
        Connected
      </span>
      """
    else
      ~H"""
      <span class="inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium theme-status-disconnected">
        Not connected
      </span>
      """
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-8">
      <!-- Theme Settings -->
      <div class="theme-card">
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
                class="relative inline-flex h-6 w-11 items-center rounded-full bg-theme-border transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-theme-primary focus:ring-offset-2 focus:ring-offset-theme-surface"
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

      <div class="theme-card overflow-x-auto">
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
                  <.link navigate={~p"/auth/google"} class="text-white/80 transition hover:text-white">
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
    </div>
    """
  end

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
end
