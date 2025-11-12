defmodule DashboardSSDWeb.MeetingsLive.Index do
  @moduledoc "Meetings index listing upcoming meetings and agenda previews."
  use DashboardSSDWeb, :live_view

  alias DashboardSSD.Integrations
  alias DashboardSSD.Integrations.Fireflies
  alias DashboardSSD.Meetings.{Agenda, Associations}
  alias DashboardSSD.{Clients, Projects}
  alias DashboardSSDWeb.DateHelpers
  alias DashboardSSD.Meetings.CacheStore
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
    # Selected date drives a +/- 6 day window
    selected_date =
      case Map.get(params, "d") do
        nil ->
          Date.utc_today()

        s ->
          case Date.from_iso8601(s) do
            {:ok, d} -> d
            _ -> Date.utc_today()
          end
      end

    start_date = Date.add(selected_date, -6)
    end_date = Date.add(selected_date, 6)

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

    # Compute previous, current, next months for calendar strip (anchor on selected month)
    cal_anchor = %Date{year: selected_date.year, month: selected_date.month, day: 1}
    {month_prev, month_curr, month_next} = month_triplet(cal_anchor)

    # Build a Date => has_meetings? map for all three months (cached 5 minutes)
    month_prev_start = %Date{year: month_prev.year, month: month_prev.month, day: 1}
    last_day_next = :calendar.last_day_of_the_month(month_next.year, month_next.month)
    month_next_end = %Date{year: month_next.year, month: month_next.month, day: last_day_next}

    {:ok, range3_start} = DateTime.new(month_prev_start, ~T[00:00:00], "Etc/UTC")
    {:ok, range3_end} = DateTime.new(month_next_end, ~T[23:59:59], "Etc/UTC")

    user_id = (socket.assigns.current_user && socket.assigns.current_user.id) || :anon
    key = {:gcal_has_event_days, user_id, {month_prev_start, month_next_end}, tz_offset}
    ttl = :timer.minutes(5)

    {:ok, has_meetings} =
      CacheStore.fetch(
        key,
        fn ->
          opts = if mock?, do: [mock: :sample], else: []

          case Integrations.calendar_list_upcoming_for_user(
                 socket.assigns.current_user || %{},
                 range3_start,
                 range3_end,
                 opts
               ) do
            {:ok, list} when is_list(list) ->
              tz = tz_offset || 0

              dates =
                Enum.reduce(list, MapSet.new(), fn e, acc ->
                  s = DateTime.add(e.start_at, tz * 60, :second) |> DateTime.to_date()
                  en = DateTime.add(e.end_at, tz * 60, :second) |> DateTime.to_date()
                  expand_dates(s, en, acc)
                end)

              {:ok, Map.new(dates, fn d -> {d, true} end)}

            _ ->
              {:ok, %{}}
          end
        end,
        ttl: ttl
      )

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
                      {:ok, %{action_items: items}} ->
                        cond do
                          is_list(items) -> Enum.join(items, "\n")
                          is_binary(items) -> items
                          true -> ""
                        end

                      _ ->
                        ""
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
       tz_offset: tz_offset,
       has_meetings: has_meetings,
       cal_anchor: cal_anchor,
       month_prev: month_prev,
       month_curr: month_curr,
       month_next: month_next
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
            <!-- Removed manual range prev/next and date inputs; selection driven by calendar -->
            <div class="flex items-center gap-2">
              <button
                type="button"
                phx-click="cal_prev_month"
                class="px-2 py-1 rounded border border-white/10 text-xs hover:bg-white/5"
                aria-label="Previous months"
              >
                ‹
              </button>
              <div class="grid grid-cols-3 gap-4">
                <div class="p-2 rounded-md">
                  <.month_calendar
                    month={@month_prev}
                    today={Date.utc_today()}
                    start_date={@range_start}
                    end_date={@range_end}
                    compact={true}
                    on_day_click="calendar_pick"
                    has_meetings={@has_meetings}
                  />
                </div>
                <div class="p-2 rounded-md ring-2 ring-theme-primary">
                  <.month_calendar
                    month={@month_curr}
                    today={Date.utc_today()}
                    start_date={@range_start}
                    end_date={@range_end}
                    compact={true}
                    on_day_click="calendar_pick"
                    has_meetings={@has_meetings}
                  />
                </div>
                <div class="p-2 rounded-md">
                  <.month_calendar
                    month={@month_next}
                    today={Date.utc_today()}
                    start_date={@range_start}
                    end_date={@range_end}
                    compact={true}
                    on_day_click="calendar_pick"
                    has_meetings={@has_meetings}
                  />
                </div>
              </div>
              <button
                type="button"
                phx-click="cal_next_month"
                class="px-2 py-1 rounded border border-white/10 text-xs hover:bg-white/5"
                aria-label="Next months"
              >
                ›
              </button>
            </div>
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
              <% past? = DateTime.compare(m.end_at, DateTime.utc_now()) == :lt %>
              <div class={[
                "theme-card px-6 py-5",
                DateHelpers.today?(m.start_at, @tz_offset || 0) && "ring-1 ring-theme-primary/40",
                past? && "bg-white/5"
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
                               (Map.get(@params || %{}, "d") && "d=" <> Map.get(@params, "d")) || nil,
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
                                        (Map.get(@params || %{}, "d") && "d=" <> Map.get(@params, "d")) || nil,
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
                                        (Map.get(@params || %{}, "d") && "d=" <> Map.get(@params, "d")) || nil,
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
                 (Map.get(@params || %{}, "d") && "d=" <> Map.get(@params, "d")) || nil,
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
                 (Map.get(@params || %{}, "d") && "d=" <> Map.get(@params, "d")) || nil,
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
                 (Map.get(@params || %{}, "d") && "d=" <> Map.get(@params, "d")) || nil,
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
    {:noreply, socket}
  end

  @impl true
  def handle_event("range_next", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("calendar_pick", %{"date" => iso}, socket) do
    with {:ok, d} <- Date.from_iso8601(to_string(iso)) do
      new_start = Date.add(d, -6)
      new_end = Date.add(d, 6)
      # Center the clicked date's month as the anchor
      anchor = %Date{year: d.year, month: d.month, day: 1}
      {m_prev, m_curr, m_next} = month_triplet(anchor)

      {:noreply,
       socket
       |> assign(cal_anchor: anchor, month_prev: m_prev, month_curr: m_curr, month_next: m_next)
       |> push_patch_to_range(new_start, new_end)}
    else
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("range_set", _params, socket) do
    {:noreply, socket}
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

  @impl true
  def handle_event("cal_prev_month", _params, socket) do
    anchor =
      Map.get(socket.assigns, :cal_anchor) ||
        %Date{
          year: socket.assigns.range_start.year,
          month: socket.assigns.range_start.month,
          day: 1
        }

    new_anchor = prev_month(anchor)
    {m_prev, m_curr, m_next} = month_triplet(new_anchor)
    # Move selection to the middle month start while preserving window length
    len = Date.diff(socket.assigns.range_end, socket.assigns.range_start) + 1
    new_start = new_anchor
    new_end = Date.add(new_start, max(len - 1, 0))

    {:noreply,
     socket
     |> assign(cal_anchor: new_anchor, month_prev: m_prev, month_curr: m_curr, month_next: m_next)
     |> push_patch_to_range(new_start, new_end)}
  end

  @impl true
  def handle_event("cal_next_month", _params, socket) do
    anchor =
      Map.get(socket.assigns, :cal_anchor) ||
        %Date{
          year: socket.assigns.range_start.year,
          month: socket.assigns.range_start.month,
          day: 1
        }

    new_anchor = next_month(anchor)
    {m_prev, m_curr, m_next} = month_triplet(new_anchor)
    # Move selection to the middle month start while preserving window length
    len = Date.diff(socket.assigns.range_end, socket.assigns.range_start) + 1
    new_start = new_anchor
    new_end = Date.add(new_start, max(len - 1, 0))

    {:noreply,
     socket
     |> assign(cal_anchor: new_anchor, month_prev: m_prev, month_curr: m_curr, month_next: m_next)
     |> push_patch_to_range(new_start, new_end)}
  end

  defp month_triplet(%Date{} = anchor) do
    {prev_month(anchor), anchor, next_month(anchor)}
  end

  defp prev_month(%Date{year: y, month: 1}), do: %Date{year: y - 1, month: 12, day: 1}
  defp prev_month(%Date{year: y, month: m}), do: %Date{year: y, month: m - 1, day: 1}

  defp next_month(%Date{year: y, month: 12}), do: %Date{year: y + 1, month: 1, day: 1}
  defp next_month(%Date{year: y, month: m}), do: %Date{year: y, month: m + 1, day: 1}

  defp push_patch_to_range(socket, start_date, _end_date) do
    qs =
      [
        (Map.get(socket.assigns[:params] || %{}, "mock") &&
           "mock=" <> Map.get(socket.assigns.params, "mock")) || nil,
        "d=" <> Date.to_iso8601(Date.add(start_date, 6))
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("&")

    Phoenix.LiveView.push_patch(socket,
      to: ~p"/meetings" <> if(qs == "", do: "", else: "?" <> qs)
    )
  end

  defp expand_dates(s, e, acc) do
    case Date.compare(s, e) do
      :gt -> acc
      _ -> expand_dates(Date.add(s, 1), e, MapSet.put(acc, s))
    end
  end
end
