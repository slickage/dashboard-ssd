defmodule DashboardSSDWeb.AnalyticsLive.Index do
  @moduledoc """
  Analytics dashboard for viewing system metrics and exporting data.

  Displays calculated averages for uptime, MTTR, and Linear throughput,
  along with a table of recent metric snapshots. Includes CSV export functionality.
  """
  use DashboardSSDWeb, :live_view

  alias DashboardSSD.Analytics
  alias DashboardSSD.Projects

  @impl true
  @doc "Mount Analytics view and load current metrics."
  def mount(_params, _session, socket) do
    projects = Projects.list_projects()
    selected_project_id = if projects != [], do: hd(projects).id, else: nil

    socket =
      socket
      |> assign(:page_title, "Analytics")
      |> assign(:projects, projects)
      |> assign(:selected_project_id, selected_project_id)
      |> load_metrics()

    {:ok, socket}
  end

  defp load_metrics(socket) do
    selected_project_id = socket.assigns.selected_project_id

    socket
    |> assign(:metrics, Analytics.list_metrics(selected_project_id))
    |> assign(:uptime_avg, Analytics.calculate_uptime(selected_project_id))
    |> assign(:mttr_avg, Analytics.calculate_mttr(selected_project_id))
    |> assign(:linear_throughput_avg, Analytics.calculate_linear_throughput(selected_project_id))
  end

  @impl true
  @doc "Handle navigation params; refresh metrics data."
  def handle_params(_params, _url, socket) do
    {:noreply, load_metrics(socket)}
  end

  @impl true
  @doc "Handle export event to download CSV."
  def handle_event("export_csv", _params, socket) do
    selected_project_id = socket.assigns.selected_project_id
    csv_data = Analytics.export_to_csv(selected_project_id)

    project_suffix =
      if selected_project_id, do: "_project_#{selected_project_id}", else: "_all_projects"

    {:noreply,
     socket
     |> push_event("download", %{
       data: csv_data,
       filename:
         "analytics_metrics#{project_suffix}_#{DateTime.utc_now() |> DateTime.to_date() |> Date.to_string()}.csv"
     })}
  end

  @impl true
  def handle_event("select_project", %{"project_id" => project_id}, socket) do
    selected_project_id = if project_id == "", do: nil, else: String.to_integer(project_id)

    {:noreply,
     socket
     |> assign(:selected_project_id, selected_project_id)
     |> load_metrics()}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply,
     socket
     |> load_metrics()
     |> put_flash(:info, "Metrics refreshed")}
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(
        assigns,
        :selected_project,
        Enum.find(assigns.projects, &(&1.id == assigns.selected_project_id))
      )

    ~H"""
    <div class="space-y-6">
      <div class="flex items-center justify-between">
        <h1 class="text-xl font-semibold">
          {@page_title}
          <%= if @selected_project do %>
            <span class="text-zinc-600">- {@selected_project.name}</span>
          <% end %>
        </h1>
        <div class="flex items-center gap-2">
          <button
            phx-click="refresh"
            class="px-3 py-2 bg-zinc-100 text-zinc-900 text-sm rounded hover:bg-zinc-200"
          >
            Refresh
          </button>
          <button
            phx-click="export_csv"
            class="px-3 py-2 bg-zinc-900 text-white text-sm rounded hover:bg-zinc-800"
          >
            Export CSV
          </button>
        </div>
      </div>
      
    <!-- Project Selector -->
      <div class="flex items-center gap-4">
        <label for="project-select" class="text-sm font-medium">Select Project:</label>
        <form phx-change="select_project" class="flex-1 max-w-xs">
          <select
            id="project-select"
            name="project_id"
            class="w-full px-3 py-2 border border-zinc-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
            phx-value-project_id={@selected_project_id || ""}
          >
            <%= for project <- @projects do %>
              <option value={project.id} selected={project.id == @selected_project_id}>
                {project.name}
              </option>
            <% end %>
          </select>
        </form>
      </div>
      
    <!-- Summary Cards -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div
          class="rounded border p-4"
          title="Average percentage of time the system is operational and available"
        >
          <h3 class="text-sm font-medium text-zinc-600 mb-1">Average Uptime</h3>
          <p class="text-2xl font-bold text-emerald-600" data-testid="uptime-metric">
            {format_percentage(@uptime_avg)}
          </p>
        </div>

        <div
          class="rounded border p-4"
          title="Mean Time To Recovery - average time taken to resolve system issues"
        >
          <h3 class="text-sm font-medium text-zinc-600 mb-1">Average MTTR</h3>
          <p class="text-2xl font-bold text-amber-600" data-testid="mttr-metric">
            {format_minutes(@mttr_avg)}
          </p>
        </div>

        <div
          class="rounded border p-4"
          title="Average number of Linear issues processed per time period"
        >
          <h3 class="text-sm font-medium text-zinc-600 mb-1">Average Linear Throughput</h3>
          <p class="text-2xl font-bold text-blue-600" data-testid="linear-throughput-metric">
            {format_throughput(@linear_throughput_avg)}
          </p>
        </div>
      </div>
      
    <!-- Metrics Table -->
      <div class="rounded border overflow-hidden">
        <table class="w-full text-left text-sm">
          <thead class="bg-zinc-50">
            <tr>
              <th class="px-3 py-2">Project ID</th>
              <th class="px-3 py-2">Type</th>
              <th class="px-3 py-2">Value</th>
              <th class="px-3 py-2">Recorded At</th>
            </tr>
          </thead>
          <tbody>
            <%= for metric <- @metrics do %>
              <tr class="border-t">
                <td class="px-3 py-2">{metric.project_id}</td>
                <td class="px-3 py-2">
                  <span class={"inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium #{metric_type_class(metric.type)}"}>
                    {format_metric_type(metric.type)}
                  </span>
                </td>
                <td class="px-3 py-2 tabular-nums">{format_metric_value(metric)}</td>
                <td class="px-3 py-2 text-zinc-600">
                  {DateTime.to_date(metric.inserted_at) |> Date.to_string()}
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <%= if @metrics == [] do %>
        <p class="text-zinc-600 text-center py-8">No metrics recorded yet.</p>
      <% end %>
    </div>
    """
  end

  # Helper functions for formatting
  defp format_percentage(value) when is_float(value) do
    "#{Float.round(value, 1)}%"
  end

  defp format_percentage(_), do: "N/A"

  defp format_minutes(value) when is_float(value) do
    "#{Float.round(value, 1)} min"
  end

  defp format_minutes(_), do: "N/A"

  defp format_throughput(value) when is_float(value) do
    "#{Float.round(value, 1)}"
  end

  defp format_throughput(_), do: "N/A"

  defp metric_type_class("uptime"), do: "bg-emerald-100 text-emerald-800"
  defp metric_type_class("mttr"), do: "bg-amber-100 text-amber-800"
  defp metric_type_class("linear_throughput"), do: "bg-blue-100 text-blue-800"
  defp metric_type_class(_), do: "bg-zinc-100 text-zinc-800"

  defp format_metric_type("uptime"), do: "Uptime"
  defp format_metric_type("mttr"), do: "MTTR"
  defp format_metric_type("linear_throughput"), do: "Linear Throughput"
  defp format_metric_type(type), do: String.capitalize(type)

  defp format_metric_value(metric) do
    case metric.type do
      "uptime" -> "#{metric.value}%"
      "mttr" -> "#{metric.value}m"
      "linear_throughput" -> "#{metric.value}"
      _ -> to_string(metric.value)
    end
  end
end
