defmodule DashboardSSDWeb.MeetingsLive.Index do
  @moduledoc "Meetings index listing upcoming meetings and agenda previews."
  use DashboardSSDWeb, :live_view

  alias DashboardSSD.Integrations.GoogleCalendar
  alias DashboardSSD.Integrations.Fireflies

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, meetings: [], loading: true)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    # Placeholder: load upcoming meetings (next 14 days)
    now = DateTime.utc_now()
    later = DateTime.add(now, 14 * 24 * 60 * 60, :second)
    {:ok, meetings} = GoogleCalendar.list_upcoming(now, later)

    # For previews, we could fetch Fireflies artifacts per series (omitted here)
    {:noreply, assign(socket, meetings: meetings, loading: false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-4">
      <h1 class="text-xl font-semibold mb-4">Meetings</h1>
      <%= if @loading do %>
        <p>Loading…</p>
      <% else %>
        <%= if @meetings == [] do %>
          <p>No upcoming meetings found.</p>
        <% else %>
          <ul class="space-y-2">
            <%= for m <- @meetings do %>
              <li class="border rounded p-3">
                <div class="flex items-center justify-between">
                  <div>
                    <div class="font-medium"><%= m.title %></div>
                    <div class="text-sm opacity-75">
                      <%= m.start_at %> – <%= m.end_at %>
                    </div>
                  </div>
                  <.link navigate={~p"/meetings/#{m.id}"} class="underline">Open</.link>
                </div>
              </li>
            <% end %>
          </ul>
        <% end %>
      <% end %>
    </div>
    """
  end
end

