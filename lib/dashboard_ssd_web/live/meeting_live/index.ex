defmodule DashboardSSDWeb.MeetingLive.Index do
  @moduledoc "Meeting detail: agenda editing, what-to-bring, summary/action items."
  use DashboardSSDWeb, :live_view

  alias DashboardSSD.Meetings.Agenda
  alias DashboardSSD.Meetings.Associations
  alias DashboardSSD.Integrations.Fireflies
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       meeting_id: nil,
       series_id: nil,
       agenda: [],
       manual_agenda: [],
       new_item_text: "",
       editing_id: nil,
       editing_text: "",
       association: nil,
       loading: true,
       what_to_bring: []
     )}
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
  def handle_event("add_item", %{"agenda_text" => text}, socket) do
    id = socket.assigns.meeting_id
    pos = length(socket.assigns.manual_agenda)
    case Agenda.create_item(%{calendar_event_id: id, text: String.trim(text), position: pos}) do
      {:ok, _} ->
        refresh_assigns(socket)

      {:error, _cs} ->
        {:noreply, socket}
    end
  end

  def handle_event("edit_item", %{"id" => id}, socket) do
    id = String.to_integer(id)
    case Enum.find(socket.assigns.manual_agenda, &(&1.id == id)) do
      nil -> {:noreply, socket}
      item -> {:noreply, assign(socket, editing_id: id, editing_text: item.text || "")}
    end
  end

  def handle_event("save_item", %{"id" => id, "text" => text}, socket) do
    id = String.to_integer(id)
    case Enum.find(socket.assigns.manual_agenda, &(&1.id == id)) do
      nil -> {:noreply, socket}
      item ->
        case Agenda.update_item(item, %{text: String.trim(text)}) do
          {:ok, _} -> refresh_assigns(assign(socket, editing_id: nil, editing_text: ""))
          {:error, _} -> {:noreply, socket}
        end
    end
  end

  def handle_event("delete_item", %{"id" => id}, socket) do
    id = String.to_integer(id)
    case Enum.find(socket.assigns.manual_agenda, &(&1.id == id)) do
      nil -> {:noreply, socket}
      item ->
        case Agenda.delete_item(item) do
          {:ok, _} -> refresh_assigns(socket)
          {:error, _} -> {:noreply, socket}
        end
    end
  end

  def handle_event("move", %{"id" => id, "dir" => dir}, socket) do
    id = String.to_integer(id)
    manual = socket.assigns.manual_agenda
    idx = Enum.find_index(manual, &(&1.id == id))
    if is_nil(idx) do
      {:noreply, socket}
    else
      new_index =
        case dir do
          "up" -> max(idx - 1, 0)
          "down" -> min(idx + 1, length(manual) - 1)
          _ -> idx
        end

      new_order =
        manual
        |> List.delete_at(idx)
        |> List.insert_at(new_index, Enum.at(manual, idx))
        |> Enum.map(& &1.id)

      case Agenda.reorder_items(socket.assigns.meeting_id, new_order) do
        :ok -> refresh_assigns(socket)
        {:error, _} -> {:noreply, socket}
      end
    end
  end

  defp refresh_assigns(socket) do
    id = socket.assigns.meeting_id
    series_id = socket.assigns.series_id
    manual = Agenda.list_items(id)
    merged = Agenda.merged_items_for_event(id, series_id)
    what_to_bring =
      merged
      |> Enum.filter(&String.contains?(String.downcase(&1.text || ""), "prepare"))
      |> Enum.map(& &1.text)

    {:noreply, assign(socket, manual_agenda: manual, agenda: merged, what_to_bring: what_to_bring)}
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
              <%= if item[:source] != "derived" do %>
                <span class="ml-3 text-xs">
                  <.link phx-click="move" phx-value-id={item[:id]} phx-value-dir="up" class="underline">up</.link>
                  <span class="mx-1">|</span>
                  <.link phx-click="move" phx-value-id={item[:id]} phx-value-dir="down" class="underline">down</.link>
                  <span class="mx-1">|</span>
                  <.link phx-click="edit_item" phx-value-id={item[:id]} class="underline">edit</.link>
                  <span class="mx-1">|</span>
                  <.link phx-click="delete_item" phx-value-id={item[:id]} data-confirm="Delete this item?" class="underline">delete</.link>
                </span>
                <%= if @editing_id == item[:id] do %>
                  <div class="mt-2">
                    <form phx-submit="save_item">
                      <input type="hidden" name="id" value={item[:id]} />
                      <input type="text" name="text" value={@editing_text} class="border rounded px-2 py-1 w-80" />
                      <button type="submit" class="ml-2 underline">Save</button>
                    </form>
                  </div>
                <% end %>
              <% end %>
            </li>
          <% end %>
        </ul>
      <% end %>

      <div class="mt-4">
        <form phx-submit="add_item" class="flex items-center gap-2">
          <input type="text" name="agenda_text" placeholder="Add agenda item" class="border rounded px-2 py-1 w-96" />
          <button type="submit" class="underline">Add</button>
        </form>
      </div>

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
