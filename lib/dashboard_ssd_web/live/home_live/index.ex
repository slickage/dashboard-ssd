defmodule DashboardSSDWeb.HomeLive.Index do
  @moduledoc "Home dashboard displaying projects, clients, workload summary, incidents, and CI status."
  use DashboardSSDWeb, :live_view

  require Logger

  alias DashboardSSD.Integrations.LinearUtils
  alias DashboardSSD.{Analytics, Clients, Deployments, Notifications, Projects}
  alias DashboardSSD.Analytics.Workload
  alias DashboardSSDWeb.Layouts

  @impl true
  @doc "Mount the home dashboard and initialize state."
  def mount(_params, _session, socket) do
    current_user = socket.assigns[:current_user]

    {:ok,
     socket
     |> assign(:current_path, "/")
     |> assign(:page_title, "Overview")
     |> assign(:theme_section, "Dashboard")
     |> assign(:theme_header_meta, nil)
     |> assign(:theme_header_actions, header_actions_for(current_user))
     |> assign(:projects, [])
     |> assign(:clients, [])
     |> assign(:alerts, [])
     |> assign(:deployments, [])
     |> assign(:workload_summary, %{})
     |> assign(:analytics_summary, %{})
     |> assign(:linear_enabled, LinearUtils.linear_enabled?())
     |> assign(:last_synced_at, nil)
     |> assign(:loaded, false)
     |> assign(:mobile_menu_open, false)}
  end

  @impl true
  @doc "Handle params and load dashboard data."
  def handle_params(_params, _url, socket) do
    if socket.assigns.loaded do
      {:noreply, socket}
    else
      load_dashboard_data(socket)
    end
  end

  defp load_dashboard_data(socket) do
    # Load all dashboard data
    projects = Projects.list_projects()
    clients = Clients.list_clients()
    alerts = Notifications.list_alerts()
    deployments = Deployments.list_deployments()

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    socket =
      socket
      |> assign(:projects, projects)
      |> assign(:clients, clients)
      |> assign(:alerts, alerts)
      |> assign(:deployments, deployments)
      |> assign(:loaded, true)
      |> assign(:last_synced_at, now)
      |> assign(:theme_header_meta, format_last_synced(now))

    # Load workload summary (sync in test, async in prod)
    socket = load_workload_summary_if_enabled(socket, projects)

    # Load analytics summary
    analytics_summary = load_analytics_summary()

    socket =
      socket
      |> assign(:analytics_summary, analytics_summary)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:workload_summary_loaded, summary}, socket) do
    {:noreply, assign(socket, :workload_summary, summary)}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    # Reload all data
    projects = Projects.list_projects()
    clients = Clients.list_clients()
    alerts = Notifications.list_alerts()
    deployments = Deployments.list_deployments()

    socket =
      socket
      |> assign(:projects, projects)
      |> assign(:clients, clients)
      |> assign(:alerts, alerts)
      |> assign(:deployments, deployments)

    # Reload workload summary
    socket = load_workload_summary_if_enabled(socket, projects)

    # Reload analytics
    analytics_summary = load_analytics_summary()

    socket =
      socket
      |> assign(:analytics_summary, analytics_summary)

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_mobile_menu", _params, socket) do
    {:noreply, assign(socket, mobile_menu_open: !socket.assigns.mobile_menu_open)}
  end

  @impl true
  def handle_event("close_mobile_menu", _params, socket) do
    {:noreply, assign(socket, mobile_menu_open: false)}
  end

  # Load workload summary from Linear
  defp load_workload_summary(pid, projects) do
    summary = summarize_all_projects(projects)
    send(pid, {:workload_summary_loaded, summary})
  end

  # Synchronous version for tests
  defp load_workload_summary_sync(projects) do
    summarize_all_projects(projects)
  end

  # Load workload summary if enabled, handling test vs prod
  defp load_workload_summary_if_enabled(socket, _projects) when not socket.assigns.linear_enabled,
    do: socket

  defp load_workload_summary_if_enabled(socket, projects) do
    if Application.get_env(:dashboard_ssd, :env) == :test do
      summary = load_workload_summary_sync(projects)
      assign(socket, :workload_summary, summary)
    else
      spawn(fn -> load_workload_summary(self(), projects) end)
      socket
    end
  end

  # Summarize workload across all projects
  defp summarize_all_projects(projects) do
    Workload.summarize_all_projects(projects)
  end

  # Load analytics summary
  defp load_analytics_summary do
    %{
      uptime: Analytics.calculate_uptime(),
      mttr: Analytics.calculate_mttr(),
      throughput: Analytics.calculate_linear_throughput()
    }
  end

  # Function component: stat card
  attr :title, :string, required: true
  attr :value, :any, required: true
  attr :meta, :string, default: nil
  attr :tone, :atom, default: :accent

  defp stat_card(assigns) do
    assigns = assign(assigns, :tone_class, stat_tone_class(assigns.tone))

    ~H"""
    <div class="dashboard-widget">
      <p class="text-xs font-semibold uppercase tracking-[0.28em] text-theme-muted">
        {@title}
      </p>
      <p class={["mt-3 text-3xl font-semibold tabular-nums", @tone_class]}>
        {@value}
      </p>
      <p :if={@meta} class="mt-2 text-sm text-theme-muted">
        {@meta}
      </p>
    </div>
    """
  end

  # Function component: workload summary card
  attr :summary, :map, required: true
  attr :linear_enabled, :boolean, default: false

  defp workload_card(assigns) do
    summary = assigns.summary || %{}
    total = summary[:total] || 0
    ip = summary[:in_progress] || 0
    fin = summary[:finished] || 0

    done_pct = Workload.percent(fin, total)
    ip_pct = Workload.percent(ip, total)
    rest_pct = max(0, 100 - done_pct - ip_pct)
    queued = max(total - fin - ip, 0)

    {status_label, status_class} = workload_status(total, fin, ip, assigns.linear_enabled)

    assigns =
      assign(assigns,
        total: total,
        ip: ip,
        fin: fin,
        queued: queued,
        done_pct: done_pct,
        ip_pct: ip_pct,
        rest_pct: rest_pct,
        status_label: status_label,
        status_class: status_class
      )

    ~H"""
    <div class="theme-card theme-gradient-border p-6 lg:p-8">
      <div class="flex flex-col gap-6">
        <div class="flex items-start justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.2em] text-theme-muted">
              Workload
            </p>
            <p class="mt-3 text-3xl font-semibold text-white tabular-nums">
              {@total}
            </p>
            <p class="mt-2 text-sm text-theme-muted">
              Issues synced from Linear across all active projects
            </p>
          </div>
          <span class={["theme-badge", @status_class]}>
            {@status_label}
          </span>
        </div>

        <div class="space-y-4">
          <div class="h-2 w-full overflow-hidden rounded-full bg-white/10">
            <div class="h-full bg-emerald-400" style={"width: #{@done_pct}%"}></div>
            <div class="h-full bg-sky-400" style={"width: #{@ip_pct}%"}></div>
            <div class="h-full bg-white/10" style={"width: #{@rest_pct}%"}></div>
          </div>

          <div class="grid grid-cols-3 gap-3 text-sm">
            <div>
              <p class="text-[0.65rem] font-semibold uppercase tracking-[0.32em] text-theme-muted">
                Finished
              </p>
              <p class="mt-1 text-lg font-semibold text-white tabular-nums">
                {@fin}
              </p>
            </div>
            <div>
              <p class="text-[0.65rem] font-semibold uppercase tracking-[0.32em] text-theme-muted">
                In Progress
              </p>
              <p class="mt-1 text-lg font-semibold text-white tabular-nums">
                {@ip}
              </p>
            </div>
            <div>
              <p class="text-[0.65rem] font-semibold uppercase tracking-[0.32em] text-theme-muted">
                Queue
              </p>
              <p class="mt-1 text-lg font-semibold text-white tabular-nums">
                {@queued}
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Function component: analytics summary card
  attr :summary, :map, required: true

  defp analytics_card(assigns) do
    summary = assigns.summary || %{}
    uptime = summary[:uptime] || 0.0
    mttr = summary[:mttr] || 0.0
    throughput = summary[:throughput] || 0.0

    assigns =
      assign(assigns,
        uptime: uptime,
        mttr: mttr,
        throughput: throughput
      )

    ~H"""
    <div class="theme-card p-6 lg:p-8">
      <div class="flex items-start justify-between">
        <div>
          <p class="text-xs font-semibold uppercase tracking-[0.2em] text-theme-muted">
            Analytics
          </p>
          <p class="mt-3 text-2xl font-semibold text-white">
            Platform performance
          </p>
          <p class="mt-2 text-sm text-theme-muted">
            Rolling 30 day aggregates
          </p>
        </div>
        <span class="theme-pill">Live</span>
      </div>

      <div class="mt-6 space-y-4">
        <div class="flex items-center justify-between rounded-2xl bg-white/5 px-4 py-3">
          <span class="text-sm font-medium uppercase tracking-[0.18em] text-theme-muted">
            Uptime
          </span>
          <span class="text-xl font-semibold text-emerald-300 tabular-nums">
            {format_success_rate(@uptime)}
          </span>
        </div>
        <div class="flex items-center justify-between rounded-2xl bg-white/5 px-4 py-3">
          <span class="text-sm font-medium uppercase tracking-[0.18em] text-theme-muted">
            MTTR
          </span>
          <span class="text-xl font-semibold text-sky-300 tabular-nums">
            {:erlang.float_to_binary(@mttr, decimals: 1)} min
          </span>
        </div>
        <div class="flex items-center justify-between rounded-2xl bg-white/5 px-4 py-3">
          <span class="text-sm font-medium uppercase tracking-[0.18em] text-theme-muted">
            Throughput
          </span>
          <span class="text-xl font-semibold text-violet-300 tabular-nums">
            {:erlang.float_to_binary(@throughput, decimals: 1)} /day
          </span>
        </div>
      </div>
    </div>
    """
  end

  # Function component: incidents card
  attr :alerts, :list, required: true

  defp incidents_card(assigns) do
    alerts = assigns.alerts || []

    recent_alerts =
      alerts
      |> Enum.take(5)
      |> Enum.map(&format_alert/1)

    count = length(alerts)

    assigns =
      assign(assigns,
        count: count,
        recent_alerts: recent_alerts,
        badge_class: incidents_badge_class(count),
        badge_label: incidents_badge_label(count)
      )

    ~H"""
    <div class="theme-card p-6 lg:p-8">
      <div class="flex items-start justify-between gap-4">
        <div>
          <p class="text-xs font-semibold uppercase tracking-[0.2em] text-theme-muted">
            Incidents
          </p>
          <p class="mt-3 text-3xl font-semibold text-white tabular-nums">
            {@count}
          </p>
          <p class="mt-2 text-sm text-theme-muted">
            Active alerts across monitored services
          </p>
        </div>
        <span class={["theme-badge", @badge_class]}>
          {@badge_label}
        </span>
      </div>

      <div class="mt-6 space-y-3">
        <%= if @recent_alerts == [] do %>
          <p class="text-sm text-theme-muted">
            All systems nominal.
          </p>
        <% else %>
          <div class="divide-y divide-white/5 rounded-2xl border border-white/5 bg-white/5">
            <div
              :for={alert <- @recent_alerts}
              class="flex items-start justify-between gap-4 px-4 py-3"
            >
              <div class="flex-1">
                <p class="text-sm font-medium text-white">
                  {alert.message}
                </p>
                <p :if={alert.subtitle} class="mt-1 text-xs text-theme-muted">
                  {alert.subtitle}
                </p>
              </div>
              <p :if={alert.timestamp} class="text-xs text-theme-muted whitespace-nowrap">
                {alert.timestamp}
              </p>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Function component: CI status card
  attr :metrics, :map, required: true

  defp ci_status_card(assigns) do
    metrics = assigns.metrics || %{}

    recent_deployments = metrics[:recent] || []
    success_rate = metrics[:success_rate] || 0.0
    success_count = metrics[:success_count] || 0
    total_count = metrics[:total_count] || 0
    failed_count = max(total_count - success_count, 0)

    assigns =
      assign(assigns,
        recent_deployments: recent_deployments,
        success_rate: success_rate,
        success_count: success_count,
        total_count: total_count,
        failed_count: failed_count
      )

    ~H"""
    <div class="theme-card p-6 lg:p-8">
      <div class="flex items-start justify-between gap-4">
        <div>
          <p class="text-xs font-semibold uppercase tracking-[0.2em] text-theme-muted">
            CI Status
          </p>
          <p class="mt-3 text-3xl font-semibold text-white tabular-nums">
            {format_success_rate(@success_rate)}
          </p>
          <p class="mt-2 text-sm text-theme-muted">
            Success rate across the last {@total_count} runs
          </p>
        </div>
        <span class="theme-pill">Pipelines</span>
      </div>

      <div class="mt-6 flex items-center gap-4 text-xs text-theme-muted">
        <span class="flex items-center gap-2">
          <span class="h-2 w-2 rounded-full bg-emerald-400"></span>
          {@success_count} passed
        </span>
        <span class="flex items-center gap-2">
          <span class="h-2 w-2 rounded-full bg-rose-500"></span>
          {@failed_count} failed
        </span>
      </div>

      <div class="mt-6 space-y-2">
        <%= if @recent_deployments == [] do %>
          <p class="text-sm text-theme-muted">
            No recent deployments recorded.
          </p>
        <% else %>
          <div
            :for={deployment <- @recent_deployments}
            class="flex items-center gap-3 rounded-xl border border-white/5 bg-white/5 px-4 py-3 text-sm"
          >
            <span class={"h-2.5 w-2.5 rounded-full " <> status_color(deployment.status)}></span>
            <span class="capitalize text-white/90">
              {deployment.status}
            </span>
            <span :if={deployment.label} class="text-xs text-theme-muted">
              {deployment.label}
            </span>
            <span
              :if={deployment.timestamp}
              class="ml-auto text-xs text-theme-muted whitespace-nowrap"
            >
              {deployment.timestamp}
            </span>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Function component: recent projects list
  attr :projects, :list, required: true

  defp recent_projects(assigns) do
    rows =
      assigns.projects
      |> Enum.take(8)
      |> Enum.map(&format_project/1)

    assigns = assign(assigns, :rows, rows)

    ~H"""
    <div class="theme-card p-0">
      <div class="flex items-center justify-between px-6 py-5">
        <div>
          <p class="text-xs font-semibold uppercase tracking-[0.2em] text-theme-muted">
            Recent projects
          </p>
          <p class="mt-1 text-sm text-theme-muted">
            Latest updates from your portfolio
          </p>
        </div>
        <.link
          navigate={~p"/projects"}
          class="text-sm font-medium text-theme-muted transition hover:text-white"
        >
          View all
        </.link>
      </div>

      <%= if @rows == [] do %>
        <p class="px-6 pb-6 text-sm text-theme-muted">
          No projects available yet.
        </p>
      <% else %>
        <div class="divide-y divide-white/5">
          <div :for={project <- @rows} class="flex items-center gap-4 px-6 py-4">
            <div class="flex-1">
              <p class="text-sm font-medium text-white">
                {project.name}
              </p>
              <p class="text-xs text-theme-muted">
                {project.client}
              </p>
            </div>
            <p :if={project.timestamp} class="text-xs text-theme-muted whitespace-nowrap">
              {project.timestamp}
            </p>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp status_color(status) when is_binary(status) do
    case String.downcase(status) do
      "success" -> "bg-emerald-400"
      "failed" -> "bg-rose-500"
      "failure" -> "bg-rose-500"
      "pending" -> "bg-amber-400"
      _ -> "bg-slate-500"
    end
  end

  defp status_color(_), do: "bg-slate-500"

  defp stat_tone_class(:emerald), do: "text-emerald-300"
  defp stat_tone_class(:rose), do: "text-rose-300"
  defp stat_tone_class(:amber), do: "text-amber-300"
  defp stat_tone_class(:violet), do: "text-violet-300"
  defp stat_tone_class(:sky), do: "text-sky-300"
  defp stat_tone_class(_), do: "text-theme-accent"

  defp incidents_badge_class(0), do: "bg-emerald-500/10 text-emerald-200"
  defp incidents_badge_class(_), do: "bg-rose-500/10 text-rose-200"

  defp incidents_badge_label(0), do: "Operational"
  defp incidents_badge_label(_), do: "Needs attention"

  defp alert_meta(alerts) do
    alerts = alerts || []
    if Enum.empty?(alerts), do: "All clear", else: "Needs attention"
  end

  defp workload_status(_total, _fin, _ip, false),
    do: {"Integration disabled", "bg-amber-500/10 text-amber-200"}

  defp workload_status(total, _fin, _ip, true) when total == 0,
    do: {"Awaiting updates", "bg-sky-500/10 text-sky-200"}

  defp workload_status(_total, fin, ip, true) when fin >= ip,
    do: {"On track", "bg-emerald-500/10 text-emerald-200"}

  defp workload_status(_total, _fin, _ip, true),
    do: {"Monitoring", "bg-rose-500/10 text-rose-200"}

  defp deployment_metrics(deployments) do
    recent_raw = Enum.take(deployments, 10)

    success_count =
      Enum.count(recent_raw, fn deployment ->
        deployment
        |> Map.get(:status, "")
        |> to_string()
        |> String.downcase()
        |> Kernel.==("success")
      end)

    total_count = length(recent_raw)
    success_rate = if total_count > 0, do: success_count * 100.0 / total_count, else: 0.0
    recent = Enum.map(recent_raw, &format_deployment/1)

    %{
      recent: recent,
      total_count: total_count,
      success_count: success_count,
      success_rate: success_rate
    }
  end

  defp deployment_meta_text(%{total_count: 0}), do: "Awaiting pipeline runs"

  defp deployment_meta_text(%{total_count: total, success_rate: rate}) when rate >= 95.0 do
    "Stable across last #{total} runs"
  end

  defp deployment_meta_text(%{total_count: total}), do: "Monitoring last #{total} runs"

  defp format_alert(alert) do
    message =
      alert
      |> Map.get(:message, "Alert")
      |> to_string()

    timestamp =
      case Map.get(alert, :inserted_at) do
        %_{} = dt -> Calendar.strftime(dt, "%b %d · %H:%M")
        _ -> nil
      end

    subtitle =
      Map.get(alert, :service) ||
        Map.get(alert, :source) ||
        Map.get(alert, :severity)

    %{message: message, subtitle: subtitle, timestamp: timestamp}
  end

  defp format_deployment(deployment) do
    status =
      deployment
      |> Map.get(:status, "unknown")
      |> to_string()
      |> String.downcase()

    timestamp =
      case Map.get(deployment, :inserted_at) do
        %_{} = dt -> Calendar.strftime(dt, "%b %d · %H:%M")
        _ -> nil
      end

    label =
      Map.get(deployment, :environment) ||
        Map.get(deployment, :ref) ||
        Map.get(deployment, :service)

    %{status: status, label: label, timestamp: timestamp}
  end

  defp format_project(project) do
    name = Map.get(project, :name, "Untitled")

    client =
      project
      |> Map.get(:client)
      |> case do
        nil -> "Unassigned"
        client -> Map.get(client, :name) || "Client"
      end

    timestamp =
      case Map.get(project, :inserted_at) do
        %_{} = dt -> Calendar.strftime(dt, "%b %d, %Y")
        _ -> nil
      end

    %{name: name, client: client, timestamp: timestamp}
  end

  defp format_success_rate(value) when is_number(value) do
    value
    |> Float.round(1)
    |> :erlang.float_to_binary(decimals: 1)
    |> Kernel.<>("%")
  end

  defp format_success_rate(_), do: "0.0%"

  defp header_actions_for(nil), do: Layouts.default_header_actions(nil)

  defp header_actions_for(current_user) do
    [
      %{label: "Refresh Data", phx_click: "refresh", variant: :primary}
      | Layouts.default_header_actions(current_user)
    ]
  end

  defp format_last_synced(%DateTime{} = datetime) do
    "Updated " <> Calendar.strftime(datetime, "%b %d, %H:%M UTC")
  end

  @impl true
  def render(assigns) do
    deployment_stats = deployment_metrics(assigns.deployments)

    assigns =
      assigns
      |> assign(:projects_total, length(assigns.projects))
      |> assign(:clients_total, length(assigns.clients))
      |> assign(:alerts_total, length(assigns.alerts))
      |> assign(:alerts_meta, alert_meta(assigns.alerts))
      |> assign(:deployment_stats, deployment_stats)
      |> assign(:deployment_meta, deployment_meta_text(deployment_stats))

    ~H"""
    <div class="flex flex-col gap-8">
      <div class="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <.stat_card title="Projects" value={@projects_total} meta="Tracked initiatives" tone={:sky} />
        <.stat_card
          title="Clients"
          value={@clients_total}
          meta="Partner organizations"
          tone={:emerald}
        />
        <.stat_card
          title="Alerts"
          value={@alerts_total}
          meta={@alerts_meta}
          tone={if @alerts_total > 0, do: :rose, else: :emerald}
        />
        <.stat_card
          title="CI Success"
          value={format_success_rate(@deployment_stats.success_rate)}
          meta={@deployment_meta}
          tone={:violet}
        />
      </div>

      <div class="grid gap-4 xl:grid-cols-[2fr,1fr]">
        <.workload_card summary={@workload_summary} linear_enabled={@linear_enabled} />
        <.analytics_card summary={@analytics_summary} />
      </div>

      <div class="grid gap-4 lg:grid-cols-2">
        <.incidents_card alerts={@alerts} />
        <.ci_status_card metrics={@deployment_stats} />
      </div>

      <.recent_projects projects={@projects} />
    </div>
    """
  end
end
