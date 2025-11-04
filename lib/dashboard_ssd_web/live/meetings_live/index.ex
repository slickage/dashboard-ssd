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
    {:ok,
     socket
     |> assign(:current_path, "/meetings")
     |> assign(:page_title, "Meetings")
     |> assign(:meetings, [])
     |> assign(:agenda_texts, %{})
     |> assign(:range_start, nil)
     |> assign(:range_end, nil)
     |> assign(:loading, true)}
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

    {:noreply,
     assign(socket,
       meetings: meetings,
       agenda_texts: agenda_texts,
       range_start: now,
       range_end: later,
       loading: false
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-8">
      <div class="card px-4 py-4 sm:px-6">
        <div class="flex flex-col gap-1 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <div class="text-xs font-semibold uppercase tracking-[0.2em] text-theme-muted">Upcoming</div>
            <div class="text-sm text-white/80">
              <%= DateHelpers.human_date(@range_start) %> – <%= DateHelpers.human_date(@range_end) %>
            </div>
          </div>
        </div>
      </div>

      <%= if @loading do %>
        <div class="theme-card px-6 py-8 text-center text-sm text-theme-muted">Loading…</div>
      <% else %>
        <%= if @meetings == [] do %>
          <div class="theme-card px-6 py-8 text-center text-sm text-theme-muted">No upcoming meetings found.</div>
        <% else %>
          <div class="theme-card overflow-x-auto">
            <table class="theme-table">
              <thead>
                <tr>
                  <th>Title</th>
                  <th>When</th>
                  <th class="hidden md:table-cell">Agenda</th>
                </tr>
              </thead>
              <tbody>
                <%= for m <- @meetings do %>
                  <tr>
                    <td>
                      <.link navigate={~p"/meetings/#{m.id}" <> if(m[:recurring_series_id], do: "?series_id=" <> m.recurring_series_id, else: "")} class="text-white/80 transition hover:text-white">
                        <%= m.title %>
                      </.link>
                    </td>
                    <td class="whitespace-nowrap text-sm text-white/80">
                      <%= DateHelpers.human_datetime(m.start_at) %> – <%= DateHelpers.human_datetime(m.end_at) %>
                    </td>
                    <td class="hidden md:table-cell text-sm">
                      <details>
                        <summary class="cursor-pointer underline">View</summary>
                        <div class="mt-2 whitespace-pre-wrap text-white/80">
                          <%= Map.get(@agenda_texts, m.id, "") %>
                        </div>
                      </details>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end
end
