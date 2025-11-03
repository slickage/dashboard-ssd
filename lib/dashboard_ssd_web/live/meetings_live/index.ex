defmodule DashboardSSDWeb.MeetingsLive.Index do
  @moduledoc "Meetings index listing upcoming meetings and agenda previews."
  use DashboardSSDWeb, :live_view

  alias DashboardSSD.Integrations.GoogleCalendar
  alias DashboardSSD.Integrations.Fireflies
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, meetings: [], loading: true)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    # Load upcoming meetings (next 14 days). In dev without integration, pass :sample mock.
    now = DateTime.utc_now()
    later = DateTime.add(now, 14 * 24 * 60 * 60, :second)
    mock? = Map.get(params, "mock") in ["1", "true"]
    {:ok, meetings} = GoogleCalendar.list_upcoming(now, later, mock: (mock? && :sample))

    # Build agenda previews from Fireflies (latest for series)
    preview =
      Enum.reduce(meetings, %{}, fn m, acc ->
        case m[:recurring_series_id] do
          nil -> Map.put(acc, m.id, [])
          series_id ->
            case Fireflies.fetch_latest_for_series(series_id) do
              {:ok, %{action_items: items}} -> Map.put(acc, m.id, Enum.take(items, 3))
              _ -> Map.put(acc, m.id, [])
            end
        end
      end)

    {:noreply, assign(socket, meetings: meetings, preview: preview, loading: false)}
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
                    <%= if Map.get(@preview, m.id, []) != [] do %>
                      <div class="text-sm mt-2">
                        <div class="opacity-75">Agenda preview:</div>
                        <ul class="list-disc ml-5">
                          <%= for it <- Map.get(@preview, m.id, []) do %>
                            <li><%= it %></li>
                          <% end %>
                        </ul>
                      </div>
                    <% end %>
                  </div>
                  <.link navigate={~p"/meetings/#{m.id}" <> if(m[:recurring_series_id], do: "?series_id=" <> m.recurring_series_id, else: "")} class="underline">Open</.link>
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
