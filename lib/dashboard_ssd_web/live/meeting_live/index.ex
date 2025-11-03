defmodule DashboardSSDWeb.MeetingLive.Index do
  @moduledoc "Meeting detail: agenda editing, what-to-bring, summary/action items."
  use DashboardSSDWeb, :live_view

  alias DashboardSSD.Meetings.Agenda
  alias DashboardSSD.Meetings.Associations
  alias DashboardSSD.Integrations.Fireflies

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, meeting_id: nil, agenda: [], association: nil, loading: true)}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    agenda = Agenda.list_items(id)
    assoc = Associations.get_for_event(id)
    {:noreply, assign(socket, meeting_id: id, agenda: agenda, association: assoc, loading: false)}
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
            <li><%= item.text %></li>
          <% end %>
        </ul>
      <% end %>

      <div class="mt-6">
        <.link navigate={~p"/meetings"} class="underline">Back to Meetings</.link>
      </div>
    </div>
    """
  end
end

