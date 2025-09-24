defmodule DashboardSSDWeb.HomeLive.Index do
  @moduledoc "Home dashboard displaying projects, clients, workload summary, incidents, and CI status."
  use DashboardSSDWeb, :live_view

  require Logger

  alias DashboardSSD.{Clients, Projects, Notifications, Deployments, Analytics}
  alias DashboardSSD.Integrations

  @impl true
  @doc "Mount the home dashboard and initialize state."
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:projects, [])
     |> assign(:clients, [])
     |> assign(:alerts, [])
     |> assign(:deployments, [])
     |> assign(:workload_summary, %{})
     |> assign(:analytics_summary, %{})
     |> assign(:linear_enabled, linear_enabled?())
     |> assign(:loaded, false)}
  end

  @impl true
  @doc "Handle params and load dashboard data."
  def handle_params(_params, _url, socket) do
    if socket.assigns.loaded do
      {:noreply, socket}
    else
      # Load all dashboard data
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
        |> assign(:loaded, true)

      # Load workload summary asynchronously if Linear is enabled
      if socket.assigns.linear_enabled do
        spawn(fn -> load_workload_summary(self(), projects) end)
      end

      # Load analytics summary
      analytics_summary = load_analytics_summary()
      socket = assign(socket, :analytics_summary, analytics_summary)

      {:noreply, socket}
    end
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
    if socket.assigns.linear_enabled do
      spawn(fn -> load_workload_summary(self(), projects) end)
    end

    # Reload analytics
    analytics_summary = load_analytics_summary()
    socket = assign(socket, :analytics_summary, analytics_summary)

    {:noreply, socket}
  end

  # Load workload summary from Linear
  defp load_workload_summary(pid, projects) do
    summary = summarize_all_projects(projects)
    send(pid, {:workload_summary_loaded, summary})
  end

  # Summarize workload across all projects
  defp summarize_all_projects(projects) do
    if linear_enabled?() do
      Enum.reduce(projects, %{total: 0, in_progress: 0, finished: 0}, fn project, acc ->
        case fetch_linear_summary(project) do
          %{total: t, in_progress: ip, finished: f} ->
            %{total: acc.total + t, in_progress: acc.in_progress + ip, finished: acc.finished + f}

          _ ->
            acc
        end
      end)
    else
      %{total: 0, in_progress: 0, finished: 0}
    end
  end

  # Fetch Linear summary for a single project (copied from ProjectsLive)
  defp fetch_linear_summary(project) do
    if Application.get_env(:dashboard_ssd, :env) == :test do
      if Application.get_env(:tesla, :adapter) == Tesla.Mock do
        do_fetch_linear_summary(project)
      else
        :unavailable
      end
    else
      do_fetch_linear_summary(project)
    end
  end

  defp do_fetch_linear_summary(project) do
    case issue_nodes_for_project(project.name) do
      {:ok, nodes} -> summarize_issue_nodes(nodes)
      :empty -> %{total: 0, in_progress: 0, finished: 0}
      :error -> :unavailable
    end
  end

  # Issue nodes fetching logic (copied from ProjectsLive)
  defp issue_nodes_for_project(name) do
    eq_query = """
    query IssuesByProject($name: String!, $first: Int!) {
      issues(first: $first, filter: { project: { name: { eq: $name } } }) {
        nodes { id state { name } }
      }
    }
    """

    contains_query = """
    query IssuesByProjectContains($name: String!, $first: Int!) {
      issues(first: $first, filter: { project: { name: { contains: $name } } }) {
        nodes { id state { name } }
      }
    }
    """

    search_query = """
    query IssueSearch($q: String!) {
      issueSearch(query: $q, first: 50) {
        nodes { id state { name } }
      }
    }
    """

    queries = [
      {eq_query, %{"name" => name, "first" => 50}},
      {contains_query, %{"name" => name, "first" => 50}},
      {search_query, %{"q" => ~s(project:"#{name}")}}
    ]

    try_issue_queries(queries)
  end

  defp try_issue_queries([{query, vars} | rest]) do
    case Integrations.linear_list_issues(query, vars) do
      {:ok, %{"data" => %{"issues" => %{"nodes" => nodes}}}} when is_list(nodes) ->
        {:ok, nodes}

      {:ok, %{"data" => %{"issueSearch" => %{"nodes" => nodes}}}} when is_list(nodes) ->
        {:ok, nodes}

      {:ok, _} ->
        try_issue_queries(rest)

      {:error, _} ->
        if rest == [], do: :error, else: try_issue_queries(rest)
    end
  end

  defp try_issue_queries([]), do: :empty

  # Summarize issue nodes (copied from ProjectsLive)
  defp summarize_issue_nodes(nodes) when is_list(nodes) do
    total = length(nodes)
    {in_progress, finished} = summarize_nodes(nodes)
    %{total: total, in_progress: in_progress, finished: finished}
  end

  defp summarize_nodes(nodes) do
    Enum.reduce(nodes, {0, 0}, fn n, {ip, fin} ->
      s = String.downcase(get_in(n, ["state", "name"]) || "")

      done? =
        Enum.any?(
          [
            "done",
            "complete",
            "completed",
            "closed",
            "merged",
            "released",
            "shipped",
            "resolved"
          ],
          &String.contains?(s, &1)
        )

      inprog? =
        Enum.any?(
          [
            "progress",
            "doing",
            "started",
            "active",
            "review",
            "qa",
            "testing",
            "block",
            "verify"
          ],
          &String.contains?(s, &1)
        )

      cond do
        done? -> {ip, fin + 1}
        inprog? -> {ip + 1, fin}
        true -> {ip, fin}
      end
    end)
  end

  # Load analytics summary
  defp load_analytics_summary do
    %{
      uptime: Analytics.calculate_uptime() |> ensure_float(),
      mttr: Analytics.calculate_mttr() |> ensure_float(),
      throughput: Analytics.calculate_linear_throughput() |> ensure_float()
    }
  end

  # Ensure value is a float for display
  defp ensure_float(value) when is_float(value), do: value
  defp ensure_float(value) when is_integer(value), do: value / 1.0
  defp ensure_float(_), do: 0.0

  # Check if Linear is enabled
  defp linear_enabled? do
    token = Application.get_env(:dashboard_ssd, :integrations, [])[:linear_token]
    is_binary(token) and String.trim(to_string(token)) != ""
  end

  # Function component: workload summary card
  attr :summary, :map, required: true

  defp workload_card(assigns) do
    summary = assigns.summary
    total = summary[:total] || 0
    ip = summary[:in_progress] || 0
    fin = summary[:finished] || 0

    done_pct = percent(fin, total)
    ip_pct = percent(ip, total)
    rest_pct = max(0, 100 - done_pct - ip_pct)

    assigns =
      assign(assigns,
        total: total,
        ip: ip,
        fin: fin,
        done_pct: done_pct,
        ip_pct: ip_pct,
        rest_pct: rest_pct
      )

    ~H"""
    <div class="bg-white p-6 rounded-lg shadow">
      <h3 class="text-lg font-semibold mb-4">Workload Summary</h3>
      <div class="flex items-center gap-4">
        <div class="grid grid-cols-3 gap-2 w-48 shrink-0">
          <span class="flex items-center gap-1" title="Total">
            <span class="inline-block h-3 w-3 rounded-full bg-zinc-400"></span>
            <span class="tabular-nums text-sm text-zinc-800">{@total}</span>
          </span>
          <span class="flex items-center gap-1" title="In Progress">
            <span class="inline-block h-3 w-3 rounded-full bg-amber-500"></span>
            <span class="tabular-nums text-sm text-amber-900">{@ip}</span>
          </span>
          <span class="flex items-center gap-1" title="Finished">
            <span class="inline-block h-3 w-3 rounded-full bg-emerald-500"></span>
            <span class="tabular-nums text-sm text-emerald-900">{@fin}</span>
          </span>
        </div>
        <div class="flex h-3 w-48 rounded overflow-hidden bg-zinc-200">
          <div class="h-full bg-emerald-500" style={"width: #{@done_pct}%"}></div>
          <div class="h-full bg-amber-500" style={"width: #{@ip_pct}%"}></div>
          <div class="h-full bg-transparent" style={"width: #{@rest_pct}%"}></div>
        </div>
      </div>
    </div>
    """
  end

  # Function component: analytics summary card
  attr :summary, :map, required: true

  defp analytics_card(assigns) do
    summary = assigns.summary
    uptime = summary[:uptime] || 0.0
    mttr = summary[:mttr] || 0.0
    throughput = summary[:throughput] || 0.0

    assigns = assign(assigns, uptime: uptime, mttr: mttr, throughput: throughput)

    ~H"""
    <div class="bg-white p-6 rounded-lg shadow">
      <h3 class="text-lg font-semibold mb-4">Analytics Summary</h3>
      <div class="grid grid-cols-3 gap-4">
        <div>
          <div class="text-2xl font-bold text-emerald-600">
            {:erlang.float_to_binary(@uptime, decimals: 1)}%
          </div>
          <div class="text-sm text-zinc-600">Uptime</div>
        </div>
        <div>
          <div class="text-2xl font-bold text-blue-600">
            {:erlang.float_to_binary(@mttr, decimals: 1)}
          </div>
          <div class="text-sm text-zinc-600">MTTR (min)</div>
        </div>
        <div>
          <div class="text-2xl font-bold text-purple-600">
            {:erlang.float_to_binary(@throughput, decimals: 1)}
          </div>
          <div class="text-sm text-zinc-600">Throughput</div>
        </div>
      </div>
    </div>
    """
  end

  # Function component: incidents card
  attr :alerts, :list, required: true

  defp incidents_card(assigns) do
    count = length(assigns.alerts)
    recent_alerts = Enum.take(assigns.alerts, 5)

    assigns = assign(assigns, count: count, recent_alerts: recent_alerts)

    ~H"""
    <div class="bg-white p-6 rounded-lg shadow">
      <h3 class="text-lg font-semibold mb-4">Incidents</h3>
      <div class="text-3xl font-bold text-red-600 mb-2">{@count}</div>
      <div class="text-sm text-zinc-600 mb-4">Active alerts</div>
      <%= if @recent_alerts != [] do %>
        <div class="space-y-2">
          <%= for alert <- @recent_alerts do %>
            <div class="text-sm text-zinc-700 truncate">
              {alert.message}
            </div>
          <% end %>
        </div>
      <% else %>
        <div class="text-sm text-zinc-500">No active incidents</div>
      <% end %>
    </div>
    """
  end

  # Function component: CI status card
  attr :deployments, :list, required: true

  defp ci_status_card(assigns) do
    recent_deployments = Enum.take(assigns.deployments, 10)
    success_count = Enum.count(recent_deployments, &(&1.status == "success"))
    total_count = length(recent_deployments)
    success_rate = if total_count > 0, do: success_count * 100.0 / total_count, else: 0.0

    assigns =
      assign(assigns,
        recent_deployments: recent_deployments,
        success_rate: success_rate,
        success_count: success_count,
        total_count: total_count
      )

    ~H"""
    <div class="bg-white p-6 rounded-lg shadow">
      <h3 class="text-lg font-semibold mb-4">CI Status</h3>
      <div class="text-3xl font-bold text-green-600 mb-2">
        {:erlang.float_to_binary(@success_rate, decimals: 1)}%
      </div>
      <div class="text-sm text-zinc-600 mb-4">Success rate</div>
      <%= if @recent_deployments != [] do %>
        <div class="space-y-2">
          <%= for deployment <- @recent_deployments do %>
            <div class="flex items-center gap-2 text-sm">
              <span class={"inline-block h-2 w-2 rounded-full #{status_color(deployment.status)}"}>
              </span>
              <span class="text-zinc-700">{deployment.status}</span>
              <span class="text-zinc-500 ml-auto">
                {Calendar.strftime(deployment.inserted_at, "%m/%d %H:%M")}
              </span>
            </div>
          <% end %>
        </div>
      <% else %>
        <div class="text-sm text-zinc-500">No recent deployments</div>
      <% end %>
    </div>
    """
  end

  # Helper for CI status colors
  defp status_color("success"), do: "bg-green-500"
  defp status_color("failure"), do: "bg-red-500"
  defp status_color("pending"), do: "bg-yellow-500"
  defp status_color(_), do: "bg-gray-400"

  # Helper for percentage calculation
  defp percent(_n, 0), do: 0

  defp percent(n, total) when is_integer(n) and is_integer(total) and total > 0 do
    trunc(n * 100 / total)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center justify-between">
        <h1 class="text-2xl font-bold">{@page_title}</h1>
        <button phx-click="refresh" class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700">
          Refresh
        </button>
      </div>
      
    <!-- Summary Cards -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <div class="bg-white p-6 rounded-lg shadow">
          <h3 class="text-lg font-semibold mb-4">Projects</h3>
          <div class="text-3xl font-bold text-blue-600">{length(@projects)}</div>
          <div class="text-sm text-zinc-600">Total projects</div>
        </div>

        <div class="bg-white p-6 rounded-lg shadow">
          <h3 class="text-lg font-semibold mb-4">Clients</h3>
          <div class="text-3xl font-bold text-green-600">{length(@clients)}</div>
          <div class="text-sm text-zinc-600">Active clients</div>
        </div>

        <.workload_card summary={@workload_summary} />
        <.analytics_card summary={@analytics_summary} />
      </div>
      
    <!-- Detailed Cards -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <.incidents_card alerts={@alerts} />
        <.ci_status_card deployments={@deployments} />
      </div>
      
    <!-- Recent Projects -->
      <div class="bg-white p-6 rounded-lg shadow">
        <h3 class="text-lg font-semibold mb-4">Recent Projects</h3>
        <%= if @projects == [] do %>
          <p class="text-zinc-600">No projects found.</p>
        <% else %>
          <div class="overflow-hidden rounded border">
            <table class="w-full text-left text-sm">
              <thead class="bg-zinc-50">
                <tr>
                  <th class="px-3 py-2">Name</th>
                  <th class="px-3 py-2">Client</th>
                  <th class="px-3 py-2">Created</th>
                </tr>
              </thead>
              <tbody>
                <%= for project <- Enum.take(@projects, 10) do %>
                  <tr class="border-t">
                    <td class="px-3 py-2">{project.name}</td>
                    <td class="px-3 py-2">
                      <%= if is_nil(project.client) do %>
                        <span class="text-zinc-500">—</span>
                      <% else %>
                        {project.client.name}
                      <% end %>
                    </td>
                    <td class="px-3 py-2 text-zinc-600">
                      {Calendar.strftime(project.inserted_at, "%Y-%m-%d")}
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
