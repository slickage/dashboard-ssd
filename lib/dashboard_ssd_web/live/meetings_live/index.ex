defmodule DashboardSSDWeb.MeetingsLive.Index do
  @moduledoc "Meetings index listing upcoming meetings and agenda previews."
  use DashboardSSDWeb, :live_view

  alias DashboardSSD.Integrations.GoogleCalendar
  alias DashboardSSD.Integrations.Fireflies
  alias DashboardSSD.Meetings.Agenda
  alias DashboardSSDWeb.DateHelpers
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

    # Build read-only consolidated agenda text per meeting (manual items if present, otherwise latest Fireflies action items)
    agenda_texts =
      Enum.reduce(meetings, %{}, fn m, acc ->
        manual =
          m.id
          |> Agenda.list_items()
          |> Enum.sort_by(& &1.position)
          |> Enum.map(&(&1.text || ""))
          |> Enum.join("\n")

        text =
          case String.trim(manual) do
            "" ->
              case m[:recurring_series_id] do
                nil -> ""
                s ->
                  case Fireflies.fetch_latest_for_series(s) do
                    {:ok, %{action_items: items}} -> Enum.join(items || [], "\n")
                    _ -> ""
                  end
              end

            other -> other
          end

        Map.put(acc, m.id, text)
      end)

    {:noreply, assign(socket, meetings: meetings, agenda_texts: agenda_texts, loading: false)}
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
                      <%= DateHelpers.human_datetime(m.start_at) %> – <%= DateHelpers.human_datetime(m.end_at) %>
                    </div>
                    
                  </div>
                  <.link navigate={~p"/meetings/#{m.id}" <> if(m[:recurring_series_id], do: "?series_id=" <> m.recurring_series_id, else: "")} class="underline">Open</.link>
                </div>
                <details class="mt-2">
                  <summary class="cursor-pointer underline">Agenda</summary>
                  <div class="mt-2 text-sm whitespace-pre-wrap">
                    <%= Map.get(@agenda_texts, m.id, "") %>
                  </div>
                </details>
              </li>
            <% end %>
          </ul>
        <% end %>
      <% end %>
    </div>
    """
  end
end
