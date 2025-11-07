defmodule DashboardSSDWeb.MeetingsLive.Index do
  @moduledoc "Meetings index listing upcoming meetings and agenda previews."
  use DashboardSSDWeb, :live_view

  alias DashboardSSD.Integrations
  alias DashboardSSD.Integrations.Fireflies
  alias DashboardSSD.Meetings.{Agenda, Associations}
  alias DashboardSSD.{Clients, Projects}
  alias DashboardSSDWeb.DateHelpers
  import DashboardSSDWeb.CalendarComponents, only: [month_calendar: 1]
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
    # Determine date range from params or default to next 14 days from today
    start_date =
      case Map.get(params, "start") do
        nil ->
          Date.utc_today()

        s ->
          case Date.from_iso8601(s) do
            {:ok, d} -> d
            _ -> Date.utc_today()
          end
      end

    end_date =
      case Map.get(params, "end") do
        nil ->
          Date.add(start_date, 13)

        s ->
          case Date.from_iso8601(s) do
            {:ok, d} -> d
            _ -> Date.add(start_date, 13)
          end
      end

    {:ok, start_dt} = DateTime.new(start_date, ~T[00:00:00], "Etc/UTC")
    {:ok, end_dt} = DateTime.new(end_date, ~T[23:59:59], "Etc/UTC")

    tz_offset =
      case Map.get(params, "tz") || Map.get(params, "tz_offset") do
        nil ->
          0

        s ->
          case Integer.parse(to_string(s)) do
            {v, _} -> v
            _ -> 0
          end
      end

    # Load upcoming meetings for the window. In dev without integration, pass :sample mock.
    mock? = Map.get(params, "mock") in ["1", "true"]

    gc_result =
      if mock? do
        Integrations.calendar_list_upcoming_for_user(
          socket.assigns.current_user || %{},
          start_dt,
          end_dt,
          mock: :sample
        )
      else
        Integrations.calendar_list_upcoming_for_user(
          socket.assigns.current_user || %{},
          start_dt,
          end_dt
        )
      end

    meetings =
      case gc_result do
        {:ok, list} when is_list(list) -> list
        {:error, :no_token} -> []
        {:error, _} -> []
        _ -> []
      end

    # Build a Date => has_meetings? map for the current month range
    has_meetings =
      meetings
      |> Enum.map(fn m -> DateTime.to_date(m.start_at) end)
      |> Enum.frequencies()
      |> Map.new(fn {date, _} -> {date, true} end)

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
              # In mock mode, avoid Fireflies API calls entirely
              if mock? do
                ""
              else
                case m[:recurring_series_id] do
                  nil ->
                    ""

                  s ->
                    case Fireflies.fetch_latest_for_series(s, title: m.title) do
                      {:ok, %{action_items: items}} -> Enum.join(items || [], "\n")
                      _ -> ""
                    end
                end
              end

            other ->
              other
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
        case Associations.get_for_event_or_series(m.id, m[:recurring_series_id]) do
          %{client_id: id} when is_integer(id) ->
            Map.put(acc, m.id, {:client, Map.get(client_map, id)})

          %{project_id: id} when is_integer(id) ->
            Map.put(acc, m.id, {:project, Map.get(project_map, id)})

          _ ->
            acc
        end
      end)

    live_action =
      cond do
        params["id"] -> :show
        params["client_id"] -> :client_show
        params["project_id"] -> :project_show
        true -> :index
      end

    {:noreply,
     assign(socket,
       meetings: meetings,
       agenda_texts: agenda_texts,
       assoc_by_meeting: assoc_by_meeting,
       params: params,
       live_action: live_action,
       range_start: start_date,
       range_end: end_date,
       loading: false,
       tz_offset: tz_offset
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="tz-detector" phx-hook="TzDetect" class="hidden" />
    <div class="flex flex-col gap-8">
      <div class="card px-4 py-4 sm:px-6">
        <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
          <div class="flex flex-col gap-2">
            <div class="text-xs font-semibold uppercase tracking-[0.2em] text-theme-muted">
              Upcoming
            </div>
            <div class="flex items-center gap-2">
              <button phx-click="range_prev" class="underline text-sm">Prev</button>
              <button phx-click="range_next" class="underline text-sm">Next</button>
            </div>
            <form phx-submit="range_set" class="flex items-center gap-2">
              <input
                type="date"
                name="start"
                value={Date.to_iso8601(@range_start)}
                class="bg-white/5 border border-white/10 rounded px-2 py-1 text-xs"
              />
              <span class="text-white/50 text-xs">to</span>
              <input
                type="date"
                name="end"
                value={Date.to_iso8601(@range_end)}
                class="bg-white/5 border border-white/10 rounded px-2 py-1 text-xs"
              />
              <button type="submit" class="underline text-sm">Apply</button>
            </form>
            <.month_calendar
              month={%Date{year: @range_start.year, month: @range_start.month, day: 1}}
              today={Date.utc_today()}
              start_date={@range_start}
              end_date={@range_end}
              compact={true}
              on_day_click="calendar_pick"
              has_meetings={has_meetings}
            />
          </div>
        </div>
      </div>

      <%= if @loading do %>
        <div class="theme-card px-6 py-8 text-center text-sm text-theme-muted">Loading…</div>
      <% else %>
        <%= if @meetings == [] do %>
          <div class="theme-card px-6 py-8 text-center text-sm text-theme-muted">
            No upcoming meetings found.
          </div>
        <% else %>
          <div class="flex flex-col gap-4">
            <%= for m <- @meetings do %>
              <div class={[
                "theme-card px-6 py-5",
                DateHelpers.today?(m.start_at, @tz_offset || 0) && "ring-1 ring-theme-primary/40"
              ]}>
                <div class="flex items-start justify-between">
                  <div>
                    <div class="text-base font-semibold flex items-center gap-3 flex-wrap">
                      <.link
                        patch={
                          ~p"/meetings" <>
                            "?" <>
                            ([
                               # preserve existing query flags like mock=1
                               (Map.get(@params || %{}, "mock") && "mock=" <> Map.get(@params, "mock")) ||
                                 nil,
                               (Map.get(@params || %{}, "start") &&
                                  "start=" <> Map.get(@params, "start")) || nil,
                               (Map.get(@params || %{}, "end") && "end=" <> Map.get(@params, "end")) ||
                                 nil,
                               (Map.get(@params || %{}, "tz") && "tz=" <> Map.get(@params, "tz")) ||
                                 nil,
                               # add modal-driving params
                               "id=" <> m.id,
                               (m[:recurring_series_id] && "series_id=" <> m.recurring_series_id) ||
                                 nil,
                               (m[:title] && "title=" <> URI.encode_www_form(m.title)) || nil
                             ]
                             |> Enum.reject(&is_nil/1)
                             |> Enum.join("&"))
                        }
                        class="text-white/80 transition hover:text-white"
                      >
                        {m.title}
                      </.link>
                      <%= case Map.get(@assoc_by_meeting || %{}, m.id) do %>
                        <% {:client, c} when not is_nil(c) -> %>
                          <span class="text-xs text-white/70">
                            · Client:
                            <.link
                              patch={
                                ~p"/meetings" <>
                                  ("?" <>
                                     ([
                                        (Map.get(@params || %{}, "mock") && "mock=" <> Map.get(@params, "mock")) || nil,
                                        (Map.get(@params || %{}, "start") && "start=" <> Map.get(@params, "start")) || nil,
                                        (Map.get(@params || %{}, "end") && "end=" <> Map.get(@params, "end")) || nil,
                                        (Map.get(@params || %{}, "tz") && "tz=" <> Map.get(@params, "tz")) || nil,
                                        "client_id=" <> to_string(c.id)
                                      ]
                                      |> Enum.reject(&is_nil/1)
                                      |> Enum.join("&"))
                                  )
                              }
                              class="underline"
                            >
                              {c.name}
                            </.link>
                          </span>
                        <% {:project, p} when not is_nil(p) -> %>
                          <span class="text-xs text-white/70">
                            · Project:
                            <.link
                              patch={
                                ~p"/meetings" <>
                                  ("?" <>
                                     ([
                                        (Map.get(@params || %{}, "mock") && "mock=" <> Map.get(@params, "mock")) || nil,
                                        (Map.get(@params || %{}, "start") && "start=" <> Map.get(@params, "start")) || nil,
                                        (Map.get(@params || %{}, "end") && "end=" <> Map.get(@params, "end")) || nil,
                                        (Map.get(@params || %{}, "tz") && "tz=" <> Map.get(@params, "tz")) || nil,
                                        "project_id=" <> to_string(p.id)
                                      ]
                                      |> Enum.reject(&is_nil/1)
                                      |> Enum.join("&"))
                                  )
                              }
                              class="underline"
                            >
                              {p.name}
                            </.link>
                          </span>
                        <% _ -> %>
                          <span class="text-xs text-white/50">· Unassigned</span>
                      <% end %>
                    </div>
                    <div class="mt-1 text-sm text-white/70">
                      <% tz = @tz_offset || 0 %>
                      <%= if DateHelpers.same_day?(m.start_at, m.end_at, tz) do %>
                        <%= if DateHelpers.today?(m.start_at, tz) do %>
                          Today · {DateHelpers.human_time_local(m.start_at, tz)} – {DateHelpers.human_time_local(
                            m.end_at,
                            tz
                          )}
                        <% else %>
                          {DateHelpers.human_date_local(m.start_at, tz)} · {DateHelpers.human_time_local(
                            m.start_at,
                            tz
                          )} – {DateHelpers.human_time_local(m.end_at, tz)}
                        <% end %>
                      <% else %>
                        {DateHelpers.human_datetime_local(m.start_at, tz)} – {DateHelpers.human_datetime_local(
                          m.end_at,
                          tz
                        )}
                      <% end %>
                    </div>
                  </div>
                </div>
                <div class="mt-3">
                  <details>
                    <summary class="cursor-pointer underline">Agenda</summary>
                    <div class="mt-2 whitespace-pre-wrap text-white/80">
                      {Map.get(@agenda_texts, m.id, "")}
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
      <.modal
        id="meeting-modal"
        show
        on_cancel={
          JS.patch(
            ~p"/meetings" <>
              ([
                 (Map.get(@params || %{}, "mock") && "?mock=" <> Map.get(@params, "mock")) || nil,
                 (Map.get(@params || %{}, "start") && "start=" <> Map.get(@params, "start")) || nil,
                 (Map.get(@params || %{}, "end") && "end=" <> Map.get(@params, "end")) || nil,
                 (Map.get(@params || %{}, "tz") && "tz=" <> Map.get(@params, "tz")) || nil
               ]
               |> Enum.reject(&is_nil/1)
               |> Enum.join("&")
               |> case do
                 "" -> ""
                 qs -> "?" <> qs
               end)
          )
        }
      >
        <.live_component
          module={DashboardSSDWeb.MeetingLive.DetailComponent}
          id={@params["id"]}
          meeting_id={@params["id"]}
          series_id={@params["series_id"]}
          title={@params["title"]}
        />
      </.modal>
    <% end %>
    <%= if @live_action == :project_show do %>
      <.modal
        id="project-read-modal"
        show
        on_cancel={
          JS.patch(
            ~p"/meetings" <>
              ([
                 (Map.get(@params || %{}, "mock") && "?mock=" <> Map.get(@params, "mock")) || nil,
                 (Map.get(@params || %{}, "start") && "start=" <> Map.get(@params, "start")) || nil,
                 (Map.get(@params || %{}, "end") && "end=" <> Map.get(@params, "end")) || nil,
                 (Map.get(@params || %{}, "tz") && "tz=" <> Map.get(@params, "tz")) || nil
               ]
               |> Enum.reject(&is_nil/1)
               |> Enum.join("&")
               |> case do
                 "" -> ""
                 qs -> "?" <> qs
               end)
          )
        }
      >
        <.live_component
          module={DashboardSSDWeb.ProjectsLive.ReadComponent}
          id={@params["project_id"]}
          project_id={@params["project_id"]}
        />
      </.modal>
    <% end %>
    <%= if @live_action == :client_show do %>
      <.modal
        id="client-read-modal"
        show
        on_cancel={
          JS.patch(
            ~p"/meetings" <>
              ([
                 (Map.get(@params || %{}, "mock") && "?mock=" <> Map.get(@params, "mock")) || nil,
                 (Map.get(@params || %{}, "start") && "start=" <> Map.get(@params, "start")) || nil,
                 (Map.get(@params || %{}, "end") && "end=" <> Map.get(@params, "end")) || nil,
                 (Map.get(@params || %{}, "tz") && "tz=" <> Map.get(@params, "tz")) || nil
               ]
               |> Enum.reject(&is_nil/1)
               |> Enum.join("&")
               |> case do
                 "" -> ""
                 qs -> "?" <> qs
               end)
          )
        }
      >
        <.live_component
          module={DashboardSSDWeb.ClientsLive.ReadComponent}
          id={@params["client_id"]}
          client_id={@params["client_id"]}
        />
      </.modal>
    <% end %>
    """
  end

  @impl true
  def handle_event("range_prev", _params, socket) do
    start_date = socket.assigns.range_start
    end_date = socket.assigns.range_end
    len = Date.diff(end_date, start_date) + 1
    new_start = Date.add(start_date, -len)
    new_end = Date.add(end_date, -len)
    {:noreply, push_patch_to_range(socket, new_start, new_end)}
  end

  @impl true
  def handle_event("range_next", _params, socket) do
    start_date = socket.assigns.range_start
    end_date = socket.assigns.range_end
    len = Date.diff(end_date, start_date) + 1
    new_start = Date.add(start_date, len)
    new_end = Date.add(end_date, len)
    {:noreply, push_patch_to_range(socket, new_start, new_end)}
  end

  @impl true
  def handle_event("calendar_pick", %{"date" => iso}, socket) do
    with {:ok, d} <- Date.from_iso8601(to_string(iso)) do
      start_date = socket.assigns.range_start
      end_date = socket.assigns.range_end
      len = Date.diff(end_date, start_date) + 1
      new_start = d
      new_end = Date.add(new_start, max(len - 1, 0))
      {:noreply, push_patch_to_range(socket, new_start, new_end)}
    else
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("range_set", %{"start" => s, "end" => e}, socket) do
    start_date =
      case Date.from_iso8601(to_string(s)) do
        {:ok, d} -> d
        _ -> socket.assigns.range_start
      end

    end_date =
      case Date.from_iso8601(to_string(e)) do
        {:ok, d} -> d
        _ -> socket.assigns.range_end
      end

    {:noreply, push_patch_to_range(socket, start_date, end_date)}
  end

  @impl true
  def handle_event("tz:set", %{"offset" => off}, socket) do
    off_int =
      case Integer.parse(to_string(off)) do
        {v, _} -> v
        _ -> 0
      end

    {:noreply, assign(socket, tz_offset: off_int)}
  end

  defp push_patch_to_range(socket, start_date, end_date) do
    qs =
      [
        (Map.get(socket.assigns[:params] || %{}, "mock") &&
           "mock=" <> Map.get(socket.assigns.params, "mock")) || nil,
        "start=" <> Date.to_iso8601(start_date),
        "end=" <> Date.to_iso8601(end_date)
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("&")

    Phoenix.LiveView.push_patch(socket,
      to: ~p"/meetings" <> if(qs == "", do: "", else: "?" <> qs)
    )
  end
end
