defmodule DashboardSSDWeb.MeetingsLive.Index do
  @moduledoc "Meetings index listing upcoming meetings and agenda previews."
  use DashboardSSDWeb, :live_view

  alias DashboardSSD.Integrations.GoogleCalendar
  alias DashboardSSD.Integrations.Fireflies
  alias DashboardSSD.Meetings.{Agenda, Associations}
  alias DashboardSSD.{Clients, Projects}
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

    # Build association map (meeting_id => {:client, client} | {:project, project})
    clients = Clients.list_clients()
    projects = Projects.list_projects()
    client_map = Map.new(clients, &{&1.id, &1})
    project_map = Map.new(projects, &{&1.id, &1})

    assoc_by_meeting =
      Enum.reduce(meetings, %{}, fn m, acc ->
        case Associations.get_for_event(m.id) do
          %{client_id: id} when is_integer(id) -> Map.put(acc, m.id, {:client, Map.get(client_map, id)})
          %{project_id: id} when is_integer(id) -> Map.put(acc, m.id, {:project, Map.get(project_map, id)})
          _ -> acc
        end
      end)

    {:noreply,
     assign(socket,
       meetings: meetings,
       agenda_texts: agenda_texts,
       assoc_by_meeting: assoc_by_meeting,
       params: params,
       live_action: if(params["id"], do: :show, else: :index),
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
          <div class="flex flex-col gap-4">
            <%= for m <- @meetings do %>
              <div class="theme-card px-6 py-5">
                <div class="flex items-start justify-between">
                  <div>
                    <div class="text-base font-semibold flex items-center gap-3 flex-wrap">
                      <.link patch={~p"/meetings/#{m.id}" <>
                                    ("?" <> (
                                      [
                                        (m[:recurring_series_id] && "series_id=" <> m.recurring_series_id) || nil,
                                        (m[:title] && "title=" <> URI.encode_www_form(m.title)) || ""
                                      ]
                                      |> Enum.reject(&is_nil/1)
                                      |> Enum.reject(&(&1 == ""))
                                      |> Enum.join("&")
                                    ))} class="text-white/80 transition hover:text-white">
                        <%= m.title %>
                      </.link>
                      <%= case Map.get(@assoc_by_meeting || %{}, m.id) do %>
                        <% {:client, c} when not is_nil(c) -> %>
                          <span class="text-xs text-white/70">· Client:
                            <.link navigate={~p"/clients/#{c.id}/edit"} class="underline"><%= c.name %></.link>
                          </span>
                        <% {:project, p} when not is_nil(p) -> %>
                          <span class="text-xs text-white/70">· Project:
                            <.link navigate={~p"/projects/#{p.id}/edit"} class="underline"><%= p.name %></.link>
                          </span>
                        <% _ -> %>
                          <span class="text-xs text-white/50">· Unassigned</span>
                      <% end %>
                    </div>
                    <div class="mt-1 text-sm text-white/70">
                      <%= DateHelpers.human_datetime(m.start_at) %> – <%= DateHelpers.human_datetime(m.end_at) %>
                    </div>
                  </div>
                </div>
                <div class="mt-3">
                  <details>
                    <summary class="cursor-pointer underline">Agenda</summary>
                    <div class="mt-2 whitespace-pre-wrap text-white/80">
                      <%= Map.get(@agenda_texts, m.id, "") %>
                    </div>
                  </details>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      <% end %>
    </div>
    <%= if @live_action == :show do %>
      <.modal id="meeting-modal" show on_cancel={JS.patch(~p"/meetings")}> 
        <.live_component 
          module={DashboardSSDWeb.MeetingLive.DetailComponent} 
          id={@params["id"]} 
          meeting_id={@params["id"]}
          series_id={@params["series_id"]}
          title={@params["title"]}
        />
      </.modal>
    <% end %>
    """
  end
end
