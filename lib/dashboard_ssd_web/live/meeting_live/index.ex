defmodule DashboardSSDWeb.MeetingLive.Index do
  @moduledoc "Meeting detail: agenda editing, what-to-bring, summary/action items."
  use DashboardSSDWeb, :live_view

  alias DashboardSSD.Meetings.Agenda
  alias DashboardSSD.Meetings.Associations
  alias DashboardSSD.Integrations.Fireflies
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, meeting_id: nil, agenda: [], association: nil, loading: true)}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _uri, socket) do
    series_id = Map.get(params, "series_id")
    manual = Agenda.list_items(id)
    assoc = Associations.get_for_event(id)

    # Derive from Fireflies latest for series, then merge with manual and de-dup
    merged = Agenda.merged_items_for_event(id, series_id)
    what_to_bring =
      merged
      |> Enum.filter(&String.contains?(String.downcase(&1.text || ""), "prepare"))
      |> Enum.map(& &1.text)

    {:noreply,
     assign(socket,
       meeting_id: id,
       series_id: series_id,
       agenda: merged,
       manual_agenda: manual,
       what_to_bring: what_to_bring,
       association: assoc,
       loading: false
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-4">
      <h1 class="text-xl font-semibold mb-4">Meeting</h1>

      <h2 class="font-medium">Agenda</h2>
      <%= if @agenda == [] do %>
        <p class="opacity-75">No agenda items yet.</p>
      <% else %>
        <ul class="list-disc ml-6 space-y-1">
          <%= for item <- @agenda do %>
            <li>
              <%= item.text %>
              <%= if item[:source] == "derived" do %>
                <span class="ml-2 text-xs opacity-60">(from last meeting)</span>
              <% end %>
            </li>
          <% end %>
        </ul>
      <% end %>

      <%= if @what_to_bring && @what_to_bring != [] do %>
        <div class="mt-6">
          <h3 class="font-medium">What to bring</h3>
          <ul class="list-disc ml-6 space-y-1">
            <%= for t <- @what_to_bring do %>
              <li><%= t %></li>
            <% end %>
          </ul>
        </div>
      <% end %>

      <div class="mt-6">
        <.link navigate={~p"/meetings"} class="underline">Back to Meetings</.link>
      </div>
    </div>
    """
  end
end
