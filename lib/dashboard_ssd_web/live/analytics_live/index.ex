defmodule DashboardSSDWeb.AnalyticsLive.Index do
  @moduledoc """
  Analytics dashboard for viewing system metrics and exporting data.

  Displays calculated averages for uptime, MTTR, and Linear throughput,
  along with a table of recent metric snapshots. Includes CSV export functionality.
  """
  use DashboardSSDWeb, :live_view

  alias DashboardSSD.Analytics
  alias DashboardSSD.Auth.Policy
  alias DashboardSSD.Projects

  @impl true
  @doc "Mount Analytics view and load current metrics."
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if Policy.can?(user, :read, :analytics) do
      projects = Projects.list_projects()
      selected_project_id = if projects != [], do: hd(projects).id, else: nil

      {:ok,
       socket
       |> assign(:current_path, "/analytics")
       |> assign(:page_title, "Analytics")
       |> assign(:projects, projects)
       |> assign(:selected_project_id, selected_project_id)
       |> load_metrics()
       |> assign(:mobile_menu_open, false)}
    else
      {:ok,
       socket
       |> assign(:current_path, "/analytics")
       |> put_flash(:error, "You don't have permission to access this page")
       |> redirect(to: ~p"/")}
    end
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
  def handle_event("toggle_mobile_menu", _params, socket) do
    {:noreply, assign(socket, mobile_menu_open: !socket.assigns.mobile_menu_open)}
  end

  @impl true
  def handle_event("close_mobile_menu", _params, socket) do
    {:noreply, assign(socket, mobile_menu_open: false)}
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
    <div class="flex flex-col gap-8">
      <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div class="flex items-center gap-3">
          <button
            phx-click="refresh"
            class="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-3 py-2 text-sm font-semibold uppercase tracking-[0.16em] text-white transition hover:border-white/20 hover:bg-white/10"
          >
            Refresh
          </button>
          <button
            phx-click="export_csv"
            class="phx-submit-loading:opacity-75 rounded-full bg-theme-primary hover:bg-theme-primary py-2 px-3 text-sm font-semibold leading-6 text-white active:text-white/80"
          >
            Export CSV
          </button>
        </div>
      </div>

      <div class="theme-card px-4 py-4 sm:px-6">
        <form
          phx-change="select_project"
          class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between"
        >
          <div class="flex flex-1 flex-col gap-2 sm:flex-row sm:items-center">
            <label
              for="project-select"
              class="text-xs font-semibold uppercase tracking-[0.2em] text-theme-muted"
            >
              Select Project
            </label>
            <select
              id="project-select"
              name="project_id"
              class="w-full rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm text-white transition focus:border-white/30 focus:outline-none sm:w-64"
              phx-value-project_id={@selected_project_id || ""}
            >
              <%= for project <- @projects do %>
                <option value={project.id} selected={project.id == @selected_project_id}>
                  {project.name}
                </option>
              <% end %>
            </select>
          </div>
        </form>
      </div>

      <div class="grid gap-4 md:grid-cols-3">
        <div
          class="theme-card p-6"
          title="Average percentage of time the system is operational and available"
        >
          <p class="text-xs font-semibold uppercase tracking-[0.2em] text-theme-muted">
            Average Uptime
          </p>
          <p class="mt-3 text-3xl font-semibold text-emerald-300" data-testid="uptime-metric">
            {format_percentage(@uptime_avg)}
          </p>
        </div>
        <div
          class="theme-card p-6"
          title="Mean Time To Recovery - average time taken to resolve system issues"
        >
          <p class="text-xs font-semibold uppercase tracking-[0.2em] text-theme-muted">
            Average MTTR
          </p>
          <p class="mt-3 text-3xl font-semibold text-amber-400" data-testid="mttr-metric">
            {format_minutes(@mttr_avg)}
          </p>
        </div>
        <div class="theme-card p-6" title="Average number of Linear issues processed per time period">
          <p class="text-xs font-semibold uppercase tracking-[0.2em] text-theme-muted">
            Average Linear Throughput
          </p>
          <p class="mt-3 text-3xl font-semibold text-sky-300" data-testid="linear-throughput-metric">
            {format_throughput(@linear_throughput_avg)}
          </p>
        </div>
      </div>

      <div class="theme-card overflow-x-auto">
        <table class="theme-table">
          <thead>
            <tr>
              <th>Project ID</th>
              <th>Type</th>
              <th>Value</th>
              <th>Recorded At</th>
            </tr>
          </thead>
          <tbody>
            <%= for metric <- @metrics do %>
              <tr>
                <td class="text-sm text-theme-muted">{metric.project_id}</td>
                <td>
                  <span class={"inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium #{metric_type_class(metric.type)}"}>
                    {format_metric_type(metric.type)}
                  </span>
                </td>
                <td class="tabular-nums">{format_metric_value(metric)}</td>
                <td class="text-sm text-theme-muted">
                  {DateTime.to_date(metric.inserted_at) |> Date.to_string()}
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <%= if @metrics == [] do %>
        <div class="theme-card px-6 py-8 text-center text-sm text-theme-muted">
          No metrics recorded yet.
        </div>
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

  defp metric_type_class("uptime"), do: "bg-emerald-500/10 text-emerald-200"
  defp metric_type_class("mttr"), do: "bg-amber-500/10 text-amber-200"
  defp metric_type_class("linear_throughput"), do: "bg-sky-500/10 text-sky-200"
  defp metric_type_class(_), do: "bg-white/10 text-white/70"

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
