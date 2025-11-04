defmodule DashboardSSDWeb.ClientsLive.ReadComponent do
  @moduledoc "Read-only modal component to view Client details without navigation."
  use DashboardSSDWeb, :live_component

  alias DashboardSSD.Clients

  @impl true
  def update(assigns, socket) do
    id = assigns[:id] || assigns[:client_id]
    client =
      case id do
        nil -> nil
        v when is_integer(v) -> Clients.get_client!(v)
        v when is_binary(v) ->
          case Integer.parse(v) do
            {n, _} -> Clients.get_client!(n)
            _ -> nil
          end
      end

    {:ok, socket |> assign(assigns) |> assign(:client, client)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <h2 class="text-lg font-medium">Client</h2>
      <%= if @client do %>
        <div class="grid grid-cols-1 gap-3">
          <div>
            <div class="text-xs uppercase tracking-wider text-theme-muted">Name</div>
            <div class="text-white/90"><%= @client.name %></div>
          </div>
          <div class="grid grid-cols-2 gap-3 text-sm">
            <div>
              <div class="text-xs uppercase tracking-wider text-theme-muted">Created</div>
              <div class="text-white/70"><%= @client.inserted_at %></div>
            </div>
            <div>
              <div class="text-xs uppercase tracking-wider text-theme-muted">Updated</div>
              <div class="text-white/70"><%= @client.updated_at %></div>
            </div>
          </div>
        </div>
      <% else %>
        <div class="text-sm text-theme-muted">Client not found.</div>
      <% end %>
    </div>
    """
  end
end

