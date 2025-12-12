defmodule DashboardSSDWeb.ProjectsLive.ReadComponent do
  @moduledoc "Read-only modal component to view Project details without navigation."
  use DashboardSSDWeb, :live_component

  alias DashboardSSD.Projects

  @impl true
  def update(assigns, socket) do
    id = assigns[:id] || assigns[:project_id]

    project =
      case id do
        nil ->
          nil

        v when is_integer(v) ->
          Projects.get_project!(v)

        v when is_binary(v) ->
          case Integer.parse(v) do
            {n, _} -> Projects.get_project!(n)
            _ -> nil
          end
      end

    {:ok, socket |> assign(assigns) |> assign(:project, project)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <h2 class="text-lg font-medium">Project</h2>
      <%= if @project do %>
        <div class="grid grid-cols-1 gap-3">
          <div>
            <div class="text-xs uppercase tracking-wider text-theme-muted">Name</div>
            <div class="text-white/90">{@project.name}</div>
          </div>
          <div>
            <div class="text-xs uppercase tracking-wider text-theme-muted">Client</div>
            <div class="text-white/80">
              <%= if @project.client do %>
                {@project.client.name}
              <% else %>
                <span class="text-white/50">(none)</span>
              <% end %>
            </div>
          </div>
          <div class="grid grid-cols-2 gap-3 text-sm">
            <div>
              <div class="text-xs uppercase tracking-wider text-theme-muted">Created</div>
              <div class="text-white/70">{@project.inserted_at}</div>
            </div>
            <div>
              <div class="text-xs uppercase tracking-wider text-theme-muted">Updated</div>
              <div class="text-white/70">{@project.updated_at}</div>
            </div>
          </div>
        </div>
      <% else %>
        <div class="text-sm text-theme-muted">Project not found.</div>
      <% end %>
    </div>
    """
  end
end
