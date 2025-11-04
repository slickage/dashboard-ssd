defmodule DashboardSSDWeb.MeetingLive.DetailComponent do
  @moduledoc "Meeting detail modal component: agenda text, summary, and association."
  use DashboardSSDWeb, :live_component

  alias DashboardSSD.Meetings.{Agenda, Associations}
  alias DashboardSSD.{Clients, Projects}
  alias DashboardSSD.Integrations.Fireflies

  @impl true
  def update(assigns, socket) do
    meeting_id = assigns[:meeting_id] || assigns[:id]
    series_id = assigns[:series_id]
    title = assigns[:title]

    manual = Agenda.list_items(meeting_id)
    assoc = Associations.get_for_event_or_series(meeting_id, series_id)
    clients = Clients.list_clients()
    projects = Projects.list_projects()

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

    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       meeting_id: meeting_id,
       series_id: series_id,
       manual_agenda: manual,
       summary_text: post.accomplished,
       action_items: post.action_items,
       agenda_text: agenda_text,
       assoc: assoc,
       clients: clients,
       projects: projects,
       guess: guess
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

  @impl true
  def handle_event("refresh_post", _params, socket) do
    case socket.assigns.series_id do
      nil -> {:noreply, socket}
      s ->
        _ = Fireflies.refresh_series(s)
        refresh_assigns(socket)
    end
  end

  @impl true
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

  @impl true
  def handle_event("assoc_save", %{"entity" => entity}, socket) do
    handle_event("assoc_save", %{"entity" => entity, "persist_series" => "true"}, socket)
  end

  @impl true
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

  @impl true
  def handle_event("assoc_reset_event", _params, socket) do
    meeting_id = socket.assigns.meeting_id
    series_id = socket.assigns.series_id
    :ok = Associations.delete_for_event(meeting_id)
    assoc = Associations.get_for_event_or_series(meeting_id, series_id)
    {:noreply, assign(socket, assoc: assoc, association: assoc)}
  end

  @impl true
  def handle_event("assoc_reset_series", _params, socket) do
    series_id = socket.assigns.series_id
    meeting_id = socket.assigns.meeting_id
    if is_binary(series_id) do
      :ok = Associations.delete_series(series_id)
    end
    assoc = Associations.get_for_event_or_series(meeting_id, series_id)
    {:noreply, assign(socket, assoc: assoc, association: assoc)}
  end

  defp respond_assoc({:ok, assoc}, socket), do: {:noreply, assign(socket, assoc: assoc, association: assoc)}
  defp respond_assoc({:error, _}, socket), do: {:noreply, socket}

  defp refresh_assigns(socket) do
    id = socket.assigns.meeting_id
    series_id = socket.assigns.series_id
    manual = Agenda.list_items(id)
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
       summary_text: post.accomplished,
       action_items: post.action_items,
       agenda_text: agenda_text
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="font-medium">Agenda</h2>
      <form phx-target={@myself} phx-submit="save_agenda_text" class="mt-2">
        <textarea name="agenda_text" class="border rounded px-2 py-1 w-full h-40" placeholder="Agenda notes..."><%= @agenda_text %></textarea>
        <div class="mt-2">
          <button type="submit" class="underline">Save agenda</button>
        </div>
      </form>

      <div class="mt-8">
        <h3 class="font-medium">Last meeting summary</h3>
        <%= if is_binary(@summary_text) and String.trim(@summary_text) != "" or @action_items != [] do %>
          <%= if is_binary(@summary_text) and String.trim(@summary_text) != "" do %>
            <div class="prose max-w-none"><p><%= @summary_text %></p></div>
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
          <div class="opacity-75">Summary pending. <button phx-target={@myself} phx-click="refresh_post" class="underline">Refresh</button></div>
        <% end %>
      </div>

      <div class="mt-8">
        <h3 class="font-medium">Association</h3>
        <div class="mt-2 text-sm">
          <div class="mt-3">
            <form phx-target={@myself} phx-submit="assoc_save" class="flex flex-col gap-3">
              <div class="flex items-center gap-2">
                <label class="text-xs uppercase tracking-wider">Select</label>
                <select name="entity" class="border rounded px-2 py-1 text-sm bg-white/5 w-72">
                  <option value="">— Choose —</option>
                  <optgroup label="Clients">
                    <%= for c <- @clients do %>
                      <option value={"client:" <> to_string(c.id)} selected={@assoc && @assoc.client_id == c.id}>
                        <%= c.name %>
                      </option>
                    <% end %>
                  </optgroup>
                  <optgroup label="Projects">
                    <%= for p <- @projects do %>
                      <option value={"project:" <> to_string(p.id)} selected={@assoc && @assoc.project_id == p.id}>
                        <%= p.name %>
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
                <button type="button" phx-target={@myself} phx-click="assoc_reset_event" class="underline text-white/70">Reset event</button>
                <button type="button" phx-target={@myself} phx-click="assoc_reset_series" class="underline text-white/70">Reset series</button>
              </div>
            </form>
            <%= case @guess do %>
              <% {:client, c} when not is_nil(c) -> %>
                <div class="mt-2 text-xs text-white/70">
                  Suggested: Client <span class="text-white/80"><%= c.name %></span>
                  <button phx-target={@myself} phx-click="assoc_apply_guess" phx-value-entity={"client:" <> to_string(c.id)} class="underline ml-2">Apply</button>
                </div>
              <% {:project, p} when not is_nil(p) -> %>
                <div class="mt-2 text-xs text-white/70">
                  Suggested: Project <span class="text-white/80"><%= p.name %></span>
                  <button phx-target={@myself} phx-click="assoc_apply_guess" phx-value-entity={"project:" <> to_string(p.id)} class="underline ml-2">Apply</button>
                </div>
              <% {:ambiguous, _list} -> %>
                <div class="mt-2 text-xs text-white/50">Multiple possible matches; please choose from the select.</div>
              <% _ -> %>
                
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
