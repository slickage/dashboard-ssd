defmodule DashboardSSDWeb.ClientsLive.Index do
  @moduledoc "LiveView for listing and managing clients."
  use DashboardSSDWeb, :live_view

  alias DashboardSSD.Auth.Policy
  alias DashboardSSD.Clients

  @impl true
  @doc "Mount the Clients index and subscribe to client updates."
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if Policy.can?(user, :read, :clients) do
      _ = Clients.subscribe()

      {:ok,
       socket
       |> assign(:current_path, "/clients")
       |> assign(:q, "")
       |> assign(:clients, Clients.list_clients())
       |> assign(:page_title, "Clients")
       |> assign(:mobile_menu_open, false)}
    else
      {:ok,
       socket
       |> assign(:current_path, "/clients")
       |> put_flash(:error, "You don't have permission to access this page")
       |> redirect(to: ~p"/")}
    end
  end

  @impl true
  @doc "Handle LiveView params for index/new/edit/delete actions."
  def handle_params(params, _url, socket) do
    action = socket.assigns.live_action

    case action do
      :index ->
        {:noreply, socket |> assign(:params, params) |> refresh_clients()}

      :new ->
        {:noreply, socket |> assign(:params, params)}

      :edit ->
        _client = Clients.get_client!(String.to_integer(params["id"]))

        {:noreply,
         socket
         |> assign(:params, params)}

      :delete ->
        client = Clients.get_client!(String.to_integer(params["id"]))

        {:noreply,
         socket
         |> assign(:params, params)
         |> assign(:client, client)}
    end
  end

  @impl true
  @doc "Handle clients page events (search/delete)."
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, socket |> assign(:q, q) |> assign(:clients, Clients.search_clients(q))}
  end

  def handle_event("delete_client", %{"id" => id}, socket) do
    client = Clients.get_client!(String.to_integer(id))
    {:ok, _} = Clients.delete_client(client)

    {:noreply,
     socket
     |> put_flash(:info, "Client deleted successfully")
     |> push_navigate(to: ~p"/clients" <> ((Map.get(socket.assigns[:params] || %{}, "mock") && ("?mock=" <> Map.get(socket.assigns.params, "mock"))) || ""))}
  end

  @impl true
  def handle_event("toggle_mobile_menu", _params, socket) do
    {:noreply, assign(socket, mobile_menu_open: !socket.assigns.mobile_menu_open)}
  end

  @impl true
  def handle_event("close_mobile_menu", _params, socket) do
    {:noreply, assign(socket, mobile_menu_open: false)}
  end

  @impl true
  @doc "Handle PubSub notifications for client changes and refresh the list."
  def handle_info({:client, _event, _client}, socket) do
    {:noreply, refresh_clients(socket)}
  end

  defp refresh_clients(socket) do
    assign(socket, :clients, Clients.search_clients(socket.assigns.q))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-8">
      <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <%= if @current_user && @current_user.role && @current_user.role.name == "admin" do %>
          <div class="flex items-center gap-3">
            <.link
              patch={
                ~p"/clients/new" <>
                  ((Map.get(@params || %{}, "mock") && ("?mock=" <> Map.get(@params, "mock"))) || "")
              }
              class="phx-submit-loading:opacity-75 rounded-full bg-theme-primary hover:bg-theme-primary-soft py-2 px-3 text-sm font-semibold leading-6 text-white active:text-white/80"
            >
              New Client
            </.link>
          </div>
        <% end %>
      </div>

      <div class="theme-card px-4 py-4 sm:px-6">
        <form
          phx-change="search"
          phx-submit="search"
          class="flex flex-col gap-3 sm:flex-row sm:items-center"
        >
          <div class="flex flex-1 items-center gap-2">
            <input
              name="q"
              value={@q}
              placeholder="Search clients"
              class="w-full rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm text-white placeholder:text-theme-muted focus:border-white/30 focus:outline-none"
            />
          </div>
          <button
            type="submit"
            class="inline-flex items-center justify-center rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm font-medium text-white transition hover:border-white/20 hover:bg-white/10"
          >
            Search
          </button>
        </form>
      </div>

      <%= if @clients == [] do %>
        <div class="theme-card px-6 py-8 text-center text-sm text-theme-muted">
          No clients found.
        </div>
      <% else %>
        <div class="theme-card overflow-x-auto">
          <table class="theme-table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              <%= for c <- @clients do %>
                <tr>
                  <td>{c.name}</td>
                  <td class="flex flex-wrap items-center gap-2 text-sm text-theme-muted">
                    <.link
                      navigate={~p"/projects?client_id=#{c.id}"}
                      class="text-white/80 transition hover:text-white"
                    >
                      View Projects
                    </.link>
                    <%= if @current_user && @current_user.role && @current_user.role.name == "admin" do %>
                      <span class="text-white/30">•</span>
                      <.link
                        patch={
                          ~p"/clients/#{c.id}/edit" <>
                            ((Map.get(@params || %{}, "mock") && ("?mock=" <> Map.get(@params, "mock"))) || "")
                        }
                        class="text-white/80 transition hover:text-white"
                      >
                        Edit
                      </.link>
                      <span class="text-white/30">•</span>
                      <.link
                        patch={
                          ~p"/clients/#{c.id}/delete" <>
                            ((Map.get(@params || %{}, "mock") && ("?mock=" <> Map.get(@params, "mock"))) || "")
                        }
                        class="text-rose-500 transition hover:text-rose-400"
                      >
                        Delete
                      </.link>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>

      <%= if @live_action in [:new, :edit] do %>
        <.modal id="client-modal" show on_cancel={JS.patch(~p"/clients" <> ((Map.get(@params || %{}, "mock") && ("?mock=" <> Map.get(@params, "mock"))) || ""))}>
          <.live_component
            module={DashboardSSDWeb.ClientsLive.FormComponent}
            id={(@live_action == :new && :new) || @params["id"]}
            action={@live_action}
            current_user={@current_user}
            q={@q}
            client_id={@params["id"]}
            patch={~p"/clients" <> ((Map.get(@params || %{}, "mock") && ("?mock=" <> Map.get(@params, "mock"))) || "")}
          />
        </.modal>
      <% end %>

      <%= if @live_action == :delete do %>
        <.modal id="delete-client-modal" show on_cancel={JS.patch(~p"/clients" <> ((Map.get(@params || %{}, "mock") && ("?mock=" <> Map.get(@params, "mock"))) || ""))}>
          <div class="flex flex-col gap-6">
            <div class="flex items-center gap-3">
              <div class="flex h-10 w-10 items-center justify-center rounded-full bg-rose-500/10">
                <.icon name="hero-exclamation-triangle" class="h-6 w-6 text-rose-500" />
              </div>
              <div class="flex flex-col">
                <h3 class="text-lg font-semibold text-white">Delete Client</h3>
                <p class="text-sm text-theme-muted">This action cannot be undone.</p>
              </div>
            </div>

            <p class="text-sm text-theme-muted">
              Are you sure you want to delete <strong class="text-white">{@client.name}</strong>?
              This will permanently remove the client and cannot be undone.
            </p>

            <div class="flex justify-start">
              <.button phx-click="delete_client" phx-value-id={@client.id} class="theme-btn-danger">
                Delete Client
              </.button>
            </div>
          </div>
        </.modal>
      <% end %>
    </div>
    """
  end
end
