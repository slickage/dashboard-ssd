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

    agenda_text =
      manual
      |> Enum.sort_by(& &1.position)
      |> Enum.map(&(&1.text || ""))
      |> Enum.join("\n")

    {:noreply,
     assign(socket,
       meeting_id: id,
       series_id: series_id,
       agenda: merged,
       manual_agenda: manual,
       agenda_text: agenda_text,
       what_to_bring: what_to_bring,
       association: assoc,
       loading: false
     )}
  end

  @impl true
  def handle_event("save_agenda_text", %{"agenda_text" => text}, socket) do
    id = socket.assigns.meeting_id
    case Agenda.replace_manual_text(id, text) do
      :ok -> refresh_assigns(socket)
      {:error, _} -> {:noreply, socket}
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
      <form phx-submit="save_agenda_text" class="mt-2">
        <textarea name="agenda_text" class="border rounded px-2 py-1 w-full h-40" placeholder="Agenda notes..."><%= @agenda_text %></textarea>
        <div class="mt-2">
          <button type="submit" class="underline">Save agenda</button>
        </div>
      </form>

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
