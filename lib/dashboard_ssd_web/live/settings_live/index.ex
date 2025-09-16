defmodule DashboardSSDWeb.SettingsLive.Index do
  @moduledoc "Settings page for viewing and connecting external integrations."
  use DashboardSSDWeb, :live_view

  alias DashboardSSD.Accounts.ExternalIdentity
  alias DashboardSSD.Repo

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Settings")
     |> assign(:integrations, integration_states(socket.assigns[:current_user]))}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply,
     socket
     |> assign(:page_title, "Settings")
     |> assign(:integrations, integration_states(socket.assigns[:current_user]))}
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
      <span class="inline-flex items-center rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-800">
        Connected
      </span>
      """
    else
      ~H"""
      <span class="inline-flex items-center rounded-full bg-zinc-100 px-2 py-0.5 text-xs text-zinc-700">
        Not connected
      </span>
      """
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <h1 class="text-xl font-semibold">{@page_title}</h1>

      <div class="rounded border overflow-hidden">
        <table class="w-full text-left text-sm">
          <thead class="bg-zinc-50">
            <tr>
              <th class="px-3 py-2">Integration</th>
              <th class="px-3 py-2">Status</th>
              <th class="px-3 py-2">Action</th>
            </tr>
          </thead>
          <tbody>
            <tr class="border-t">
              <td class="px-3 py-2">Google Drive</td>
              <td class="px-3 py-2">
                <.status_badge state={@integrations.google} />
              </td>
              <td class="px-3 py-2">
                <%= if @integrations.google.connected do %>
                  <span class="text-zinc-500 text-xs">Linked via Google OAuth</span>
                <% else %>
                  <.link navigate={~p"/auth/google"} class="text-zinc-700 hover:underline">
                    Connect Google
                  </.link>
                <% end %>
              </td>
            </tr>

            <tr class="border-t">
              <td class="px-3 py-2">Linear</td>
              <td class="px-3 py-2">
                <.status_badge state={@integrations.linear} />
              </td>
              <td class="px-3 py-2">
                <%= if @integrations.linear.connected do %>
                  <span class="text-zinc-500 text-xs">Configured via LINEAR_TOKEN</span>
                <% else %>
                  <span class="text-zinc-600 text-xs">Set LINEAR_TOKEN or LINEAR_API_KEY</span>
                <% end %>
              </td>
            </tr>

            <tr class="border-t">
              <td class="px-3 py-2">Slack</td>
              <td class="px-3 py-2">
                <.status_badge state={@integrations.slack} />
              </td>
              <td class="px-3 py-2">
                <%= if @integrations.slack.connected do %>
                  <span class="text-zinc-500 text-xs">Configured via SLACK_BOT_TOKEN</span>
                <% else %>
                  <span class="text-zinc-600 text-xs">
                    Set SLACK_BOT_TOKEN or SLACK_API_KEY (+ SLACK_CHANNEL)
                  </span>
                <% end %>
              </td>
            </tr>

            <tr class="border-t">
              <td class="px-3 py-2">Notion</td>
              <td class="px-3 py-2">
                <.status_badge state={@integrations.notion} />
              </td>
              <td class="px-3 py-2">
                <%= if @integrations.notion.connected do %>
                  <span class="text-zinc-500 text-xs">Configured via NOTION_TOKEN</span>
                <% else %>
                  <span class="text-zinc-600 text-xs">Set NOTION_TOKEN or NOTION_API_KEY</span>
                <% end %>
              </td>
            </tr>

            <tr class="border-t">
              <td class="px-3 py-2">GitHub</td>
              <td class="px-3 py-2">
                <span class="inline-flex items-center rounded-full bg-zinc-100 px-2 py-0.5 text-xs text-zinc-700">
                  Not connected
                </span>
              </td>
              <td class="px-3 py-2">
                <span class="text-zinc-600 text-xs">Coming soon</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end
end
