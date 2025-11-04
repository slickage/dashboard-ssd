defmodule DashboardSSDWeb.MeetingLive.Index do
  @moduledoc "Meeting detail: agenda editing, what-to-bring, summary/action items."
  use DashboardSSDWeb, :live_view

  alias DashboardSSD.Meetings.Agenda
  alias DashboardSSD.Meetings.Associations
  alias DashboardSSD.{Clients, Projects}
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
       loading: true
     )}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _uri, socket) do
    series_id = Map.get(params, "series_id")
    manual = Agenda.list_items(id)
    assoc = Associations.get_for_event_or_series(id, series_id)
    title = Map.get(params, "title")
    clients = Clients.list_clients()
    projects = Projects.list_projects()

    # Derive from Fireflies latest for series (used to prefill agenda when empty)
    post =
      case series_id do
        nil -> %{accomplished: nil, action_items: []}
        s ->
          case Fireflies.fetch_latest_for_series(s) do
            {:ok, v} -> v
            _ -> %{accomplished: nil, action_items: []}
          end
      end

    agenda_text =
      manual
      |> Enum.sort_by(& &1.position)
      |> Enum.map(&(&1.text || ""))
      |> Enum.join("\n")
      |> case do
        "" -> Enum.join(post.action_items || [], "\n")
        other -> other
      end

    guess = if is_binary(title) and String.trim(title) != "", do: Associations.guess_from_title(title), else: :unknown
    {auto_entity, auto_notice?} =
      case {assoc, guess} do
        {nil, {:client, c}} when not is_nil(c) -> {"client:" <> to_string(c.id), true}
        {nil, {:project, p}} when not is_nil(p) -> {"project:" <> to_string(p.id), true}
        _ -> {nil, false}
      end

    {:noreply,
     assign(socket,
       meeting_id: id,
       series_id: series_id,
       agenda: [],
        manual_agenda: manual,
        summary_text: post.accomplished,
        action_items: post.action_items,
        agenda_text: agenda_text,
        assoc: assoc,
        guess: guess,
        clients: clients,
        projects: projects,
        association: assoc,
        auto_entity: auto_entity,
        auto_suggest_notice: auto_notice?,
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

  def handle_event("refresh_post", _params, socket) do
    case socket.assigns.series_id do
      nil -> {:noreply, socket}
      s ->
        _ = Fireflies.refresh_series(s)
        refresh_assigns(socket)
    end
  end

  def handle_event("assoc_save", %{"entity" => entity, "persist_series" => persist}, socket) do
    series_id = socket.assigns.series_id
    meeting_id = socket.assigns.meeting_id

    case String.split(entity || "", ":", parts: 2) do
      ["client", id_str] ->
        case Integer.parse(id_str) do
          {v, _} -> Associations.set_manual(meeting_id, %{client_id: v}, series_id, persist in ["true", "1", "on", nil]) |> respond_assoc(socket)
          _ -> {:noreply, socket}
        end

      ["project", id_str] ->
        case Integer.parse(id_str) do
          {v, _} -> Associations.set_manual(meeting_id, %{project_id: v}, series_id, persist in ["true", "1", "on", nil]) |> respond_assoc(socket)
          _ -> {:noreply, socket}
        end

      _ -> {:noreply, socket}
    end
  end

  def handle_event("assoc_save", %{"entity" => entity}, socket) do
    handle_event("assoc_save", %{"entity" => entity, "persist_series" => "true"}, socket)
  end


  def handle_event("assoc_apply_guess", %{"entity" => entity}, socket) do
    series_id = socket.assigns.series_id
    meeting_id = socket.assigns.meeting_id

    case String.split(entity || "", ":", parts: 2) do
      ["client", id_str] ->
        case Integer.parse(id_str) do
          {v, _} -> Associations.set_manual(meeting_id, %{client_id: v}, series_id, true) |> respond_assoc(socket)
          _ -> {:noreply, socket}
        end

      ["project", id_str] ->
        case Integer.parse(id_str) do
          {v, _} -> Associations.set_manual(meeting_id, %{project_id: v}, series_id, true) |> respond_assoc(socket)
          _ -> {:noreply, socket}
        end

      _ -> {:noreply, socket}
    end
  end

  

  def handle_event("assoc_reset_event", _params, socket) do
    meeting_id = socket.assigns.meeting_id
    series_id = socket.assigns.series_id
    :ok = Associations.delete_for_event(meeting_id)
    assoc = Associations.get_for_event_or_series(meeting_id, series_id)
    {:noreply, assign(socket, assoc: assoc, association: assoc)}
  end

  def handle_event("assoc_reset_series", _params, socket) do
    series_id = socket.assigns.series_id
    meeting_id = socket.assigns.meeting_id
    if is_binary(series_id) do
      :ok = Associations.delete_series(series_id)
    end
    assoc = Associations.get_for_event_or_series(meeting_id, series_id)
    {:noreply, assign(socket, assoc: assoc, association: assoc)}
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
    # Prefill agenda when manual is empty using latest Fireflies action items
    post =
      case series_id do
        nil -> %{accomplished: nil, action_items: []}
        s ->
          case Fireflies.fetch_latest_for_series(s) do
            {:ok, v} -> v
            _ -> %{accomplished: nil, action_items: []}
          end
      end
    agenda_text =
      manual
      |> Enum.sort_by(& &1.position)
      |> Enum.map(&(&1.text || ""))
      |> Enum.join("\n")
      |> case do
        "" -> Enum.join(post.action_items || [], "\n")
        other -> other
      end

    {:noreply,
     assign(socket,
       manual_agenda: manual,
       agenda: [],
       summary_text: post.accomplished,
       action_items: post.action_items,
       agenda_text: agenda_text
     )}
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

      <div class="mt-8">
        <h3 class="font-medium">Last meeting summary</h3>
        <%= if is_binary(@summary_text) and String.trim(@summary_text) != "" or @action_items != [] do %>
          <%= if is_binary(@summary_text) and String.trim(@summary_text) != "" do %>
            <div class="prose max-w-none">
              <p><%= @summary_text %></p>
            </div>
          <% end %>
          <%= if @action_items != [] do %>
            <div class="mt-3">
              <div class="opacity-75">Action Items</div>
              <ul class="list-disc ml-6 space-y-1">
                <%= for it <- @action_items do %>
                  <li><%= it %></li>
                <% end %>
              </ul>
            </div>
          <% end %>
        <% else %>
          <div class="opacity-75">Summary pending. <button phx-click="refresh_post" class="underline">Refresh</button></div>
        <% end %>
      </div>

      <div class="mt-8">
        <h3 class="font-medium">Association</h3>
        <div class="mt-2 text-sm">
          <%= cond do %>
            <% @assoc && @assoc.client_id -> %>
              <div>Client: <span class="text-white/80"><%= Enum.find(@clients, &(&1.id == @assoc.client_id)) |> then(&(&1 && &1.name || "(deleted)")) %></span></div>
            <% @assoc && @assoc.project_id -> %>
              <div>Project: <span class="text-white/80"><%= Enum.find(@projects, &(&1.id == @assoc.project_id)) |> then(&(&1 && &1.name || "(deleted)")) %></span></div>
            <% true -> %>
              <div class="text-white/70">Unassigned</div>
          <% end %>

          <div class="mt-3">
            <form phx-submit="assoc_save" class="flex flex-col gap-3">
              <div class="flex items-center gap-2">
                <label class="text-xs uppercase tracking-wider">Select</label>
                <select name="entity" class="border rounded px-2 py-1 text-sm bg-white/5 w-72">
                  <option value="">— Choose —</option>
                  <optgroup label="Clients">
                    <%= for c <- @clients do %>
                      <option value={"client:" <> to_string(c.id)} selected={(not is_nil(@assoc) and @assoc.client_id == c.id) or (is_nil(@assoc) and @auto_entity == "client:" <> to_string(c.id))}>
                        <%= c.name %><%= if is_nil(@assoc) and @auto_entity == "client:" <> to_string(c.id), do: " (suggested)" %>
                      </option>
                    <% end %>
                  </optgroup>
                  <optgroup label="Projects">
                    <%= for p <- @projects do %>
                      <option value={"project:" <> to_string(p.id)} selected={(not is_nil(@assoc) and @assoc.project_id == p.id) or (is_nil(@assoc) and @auto_entity == "project:" <> to_string(p.id))}>
                        <%= p.name %><%= if is_nil(@assoc) and @auto_entity == "project:" <> to_string(p.id), do: " (suggested)" %>
                      </option>
                    <% end %>
                  </optgroup>
                </select>
              </div>
              <div class="flex items-center gap-2">
                <input type="checkbox" id="persist_series" name="persist_series" checked />
                <label for="persist_series" class="text-xs">Persist for series</label>
              </div>
              <div class="flex items-center gap-3">
                <button type="submit" class="underline">Save association</button>
                <button type="button" phx-click="assoc_reset_event" class="underline text-white/70">Reset event</button>
                <button type="button" phx-click="assoc_reset_series" class="underline text-white/70">Reset series</button>
              </div>
            </form>
            
          </div>
        </div>
      </div>

      <div class="mt-6">
        <.link navigate={~p"/meetings"} class="underline">Back to Meetings</.link>
      </div>
    </div>
    """
  end

  defp respond_assoc({:ok, assoc}, socket), do: {:noreply, assign(socket, assoc: assoc, association: assoc)}
  defp respond_assoc({:error, _}, socket), do: {:noreply, socket}
end
