defmodule DashboardSSDWeb.ClientsLive.Index do
  @moduledoc "LiveView for listing and managing clients."
  use DashboardSSDWeb, :live_view

  alias DashboardSSD.Clients

  @impl true
  def mount(_params, _session, socket) do
    _ = Clients.subscribe()

    {:ok,
     socket
     |> assign(:q, "")
     |> assign(:clients, Clients.list_clients())
     |> assign(:page_title, "Clients")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    action = socket.assigns.live_action

    case action do
      :index ->
        {:noreply, socket |> assign(:params, params) |> refresh_clients()}

      :new ->
        {:noreply, socket |> assign(:page_title, "New Client") |> assign(:params, params)}

      :edit ->
        client = Clients.get_client!(String.to_integer(params["id"]))

        {:noreply,
         socket
         |> assign(:page_title, "Edit Client: #{client.name}")
         |> assign(:params, params)}
    end
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, socket |> assign(:q, q) |> assign(:clients, Clients.search_clients(q))}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    client = Clients.get_client!(String.to_integer(id))
    {:ok, _} = Clients.delete_client(client)
    {:noreply, refresh_clients(socket)}
  end

  @impl true
  def handle_info({:client, _event, _client}, socket) do
    {:noreply, refresh_clients(socket)}
  end

  defp refresh_clients(socket) do
    assign(socket, :clients, Clients.search_clients(socket.assigns.q))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center justify-between">
        <h1 class="text-xl font-semibold">{@page_title}</h1>
        <%= if @current_user && @current_user.role && @current_user.role.name == "admin" do %>
          <.link navigate={~p"/clients/new"} class="px-3 py-2 rounded bg-zinc-900 text-white text-sm">
            New Client
          </.link>
        <% end %>
      </div>

      <div class="flex gap-3 items-center">
        <form phx-change="search" phx-submit="search" class="flex items-center gap-2">
          <input
            name="q"
            value={@q}
            placeholder="Search clients"
            class="border rounded px-2 py-1 text-sm"
          />
          <button type="submit" class="px-2 py-1 border rounded text-sm">Search</button>
        </form>
      </div>

      <%= if @clients == [] do %>
        <p class="text-zinc-600">No clients found.</p>
      <% else %>
        <div class="overflow-hidden rounded border">
          <table class="w-full text-left text-sm">
            <thead class="bg-zinc-50">
              <tr>
                <th class="px-3 py-2">Name</th>
                <th class="px-3 py-2">Actions</th>
              </tr>
            </thead>
            <tbody>
              <%= for c <- @clients do %>
                <tr class="border-t">
                  <td class="px-3 py-2">{c.name}</td>
                  <td class="px-3 py-2">
                    <.link
                      navigate={~p"/projects?client_id=#{c.id}"}
                      class="text-zinc-700 hover:underline"
                    >
                      View Projects
                    </.link>
                    <%= if @current_user && @current_user.role && @current_user.role.name == "admin" do %>
                      <span class="mx-2">•</span>
                      <.link
                        navigate={~p"/clients/#{c.id}/edit"}
                        class="text-zinc-700 hover:underline"
                      >
                        Edit
                      </.link>
                      <span class="mx-2">•</span>
                      <button
                        phx-click="delete"
                        phx-value-id={c.id}
                        onclick="return confirm('Delete this client?')"
                        class="text-red-600 hover:underline"
                      >
                        Delete
                      </button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>

      <%= if @live_action in [:new, :edit] do %>
        <.modal id="client-modal" show on_cancel={JS.navigate(~p"/clients")}>
          <.live_component
            module={DashboardSSDWeb.ClientsLive.FormComponent}
            id={(@live_action == :new && :new) || @params["id"]}
            action={@live_action}
            current_user={@current_user}
            q={@q}
            client_id={@params["id"]}
            patch={~p"/clients"}
          />
        </.modal>
      <% end %>
    </div>
    """
  end
end
