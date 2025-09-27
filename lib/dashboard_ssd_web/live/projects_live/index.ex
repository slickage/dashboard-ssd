defmodule DashboardSSDWeb.ProjectsLive.Index do
  @moduledoc "Projects hub listing with Linear task summary and health status."
  use DashboardSSDWeb, :live_view

  require Logger

  alias DashboardSSD.{Clients, Projects}
  alias DashboardSSD.Deployments
  alias DashboardSSD.Integrations

  @impl true
  @doc "Mount the Projects hub view and initialize state."
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Projects")
     |> assign(:client_id, nil)
     |> assign(:projects, [])
     |> assign(:clients, Clients.list_clients())
     |> assign(:linear_enabled, linear_enabled?())
     |> assign(:summaries, %{})
     |> assign(:loaded, false)
     |> assign(:mobile_menu_open, false)}
  end

  @impl true
  @doc "Handle params for index/edit actions and load data."
  def handle_params(params, _url, socket) do
    socket = assign(socket, :params, params)

    case socket.assigns.live_action do
      :edit -> handle_params_edit(params, socket)
      _ -> handle_params_index(params, socket)
    end
  end

  @impl true
  def handle_info({:health_updated, health}, socket) do
    {:noreply, assign(socket, :health, health)}
  end

  @impl true
  def handle_info(:reload_summaries, socket) do
    Logger.info("Reloading Linear task summaries for #{length(socket.assigns.projects)} projects")
    summaries = summarize_projects(socket.assigns.projects)
    {:noreply, assign(socket, :summaries, summaries)}
  end

  defp handle_params_edit(%{"id" => id}, socket) do
    project = Projects.get_project!(String.to_integer(id))
    {:noreply, assign(socket, :page_title, "Edit Project: #{project.name}")}
  end

  defp handle_params_index(params, socket) do
    client_id = params["client_id"]

    if reuse_loaded?(socket, client_id, params["r"]) do
      {:noreply, assign(socket, page_title: "Projects", client_id: client_id)}
    else
      projects = fetch_projects(client_id)
      spawn(fn -> run_checks_and_update(projects, self()) end)

      socket =
        socket
        |> assign(:page_title, "Projects")
        |> assign(:client_id, client_id)
        |> assign(:clients, Clients.list_clients())
        |> assign(:projects, projects)
        |> assign(:health, load_existing_health(projects))
        |> assign(:loaded, true)
        |> assign(:summaries, %{})

      if socket.assigns.linear_enabled do
        Logger.info("Linear enabled, spawning reload task")
        pid = self()
        spawn_reload_task(pid)
      else
        Logger.info("Linear not enabled")
      end

      {:noreply, socket}
    end
  end

  defp reuse_loaded?(socket, client_id, r_param) do
    socket.assigns[:client_id] == client_id and r_param in [nil, ""] and
      socket.assigns[:loaded] == true and socket.assigns[:projects] != nil and
      socket.assigns[:summaries] != nil
  end

  defp fetch_projects(client_id) do
    case client_id do
      nil -> Projects.list_projects()
      "" -> Projects.list_projects()
      id -> Projects.list_projects_by_client(String.to_integer(id))
    end
  end

  defp summarize_projects(projects) do
    if linear_enabled?() do
      Enum.into(projects, %{}, fn p -> {to_string(p.id), safe_fetch_linear_summary(p)} end)
    else
      %{}
    end
  end

  defp safe_fetch_linear_summary(project) do
    if Application.get_env(:dashboard_ssd, :env) == :test do
      if Application.get_env(:tesla, :adapter) == Tesla.Mock do
        fetch_linear_summary(project)
      else
        :unavailable
      end
    else
      fetch_linear_summary(project)
    end
  end

  defp run_checks_and_update(projects, pid) do
    if Application.get_env(:dashboard_ssd, :env) != :test do
      health = run_current_health_checks(projects)
      send(pid, {:health_updated, health})
    end
  end

  defp run_current_health_checks(projects) do
    enabled_settings = Deployments.list_enabled_health_check_settings()
    enabled_ids = MapSet.new(Enum.map(enabled_settings, & &1.project_id))

    projects
    |> Enum.filter(&MapSet.member?(enabled_ids, &1.id))
    |> Enum.map(& &1.id)
    |> Enum.reduce(%{}, fn project_id, acc ->
      case Deployments.run_health_check_now(project_id) do
        {:ok, status} -> Map.put(acc, project_id, status)
        _ -> acc
      end
    end)
  end

  defp load_existing_health(projects) do
    enabled_settings = Deployments.list_enabled_health_check_settings()
    enabled_ids = MapSet.new(Enum.map(enabled_settings, & &1.project_id))

    projects
    |> Enum.filter(&MapSet.member?(enabled_ids, &1.id))
    |> Enum.map(& &1.id)
    |> Deployments.latest_health_status_by_project_ids()
    |> Enum.into(%{})
  end

  defp spawn_reload_task(pid) do
    spawn(fn ->
      Logger.info("Reload task sleeping 500ms")
      Process.sleep(500)
      Logger.info("Sending :reload_summaries message")
      send(pid, :reload_summaries)
    end)
  end

  defp fetch_linear_summary(project) do
    case issue_nodes_for_project(project.name) do
      {:ok, nodes} -> summarize_issue_nodes(nodes)
      :empty -> %{total: 0, in_progress: 0, finished: 0}
      :error -> :unavailable
    end
  end

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

  defp summarize_issue_nodes(nodes) when is_list(nodes) do
    total = length(nodes)
    {in_progress, finished} = summarize_nodes(nodes)
    %{total: total, in_progress: in_progress, finished: finished}
  end

  defp linear_enabled? do
    token = Application.get_env(:dashboard_ssd, :integrations, [])[:linear_token]
    is_binary(token) and String.trim(to_string(token)) != ""
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

  @impl true
  @doc "Handle project events (sync, filter)."
  def handle_event("sync", _params, socket) do
    case Projects.sync_from_linear() do
      {:ok, %{inserted: i, updated: u}} ->
        {:noreply,
         socket
         |> put_flash(:info, "Synced from Linear (inserted=#{i}, updated=#{u})")
         |> refresh()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Linear sync failed: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("filter", %{"client_id" => client_id}, socket) do
    client_id = if client_id in [nil, ""], do: nil, else: client_id
    path = if is_nil(client_id), do: ~p"/projects", else: ~p"/projects?client_id=#{client_id}"
    {:noreply, push_patch(socket, to: path)}
  end

  @impl true
  def handle_event("reload_summaries", _params, socket) do
    Logger.info(
      "Manually reloading Linear task summaries for #{length(socket.assigns.projects)} projects"
    )

    summaries = summarize_projects(socket.assigns.projects)
    {:noreply, assign(socket, :summaries, summaries)}
  end

  @impl true
  def handle_event("toggle_mobile_menu", _params, socket) do
    {:noreply, assign(socket, mobile_menu_open: !socket.assigns.mobile_menu_open)}
  end

  @impl true
  def handle_event("close_mobile_menu", _params, socket) do
    {:noreply, assign(socket, mobile_menu_open: false)}
  end

  defp refresh(socket) do
    client_id = socket.assigns.client_id

    projects =
      case client_id do
        nil -> Projects.list_projects()
        "" -> Projects.list_projects()
        id -> Projects.list_projects_by_client(String.to_integer(id))
      end

    spawn(fn -> run_checks_and_update(projects, self()) end)

    socket =
      assign(socket, projects: projects, summaries: %{}, health: load_existing_health(projects))

    if socket.assigns.linear_enabled do
      pid = self()
      spawn_reload_task(pid)
    end

    socket
  end

  # Function component: compact, consistent task summary with badges + progress bar
  attr :summary, :map, required: true

  defp tasks_cell(assigns) do
    summary = assigns.summary || %{}
    total = summary[:total] || summary["total"] || 0
    ip = summary[:in_progress] || summary["in_progress"] || 0
    fin = summary[:finished] || summary["finished"] || 0

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
    <div class="flex items-center gap-3">
      <div class="grid w-36 shrink-0 grid-cols-3 gap-2">
        <span class="flex items-center gap-1 text-xs text-theme-muted" title="Total">
          <span class="inline-block h-2.5 w-2.5 rounded-full bg-white/40" aria-hidden="true"></span>
          <span class="tabular-nums text-white/80">{@total}</span>
        </span>
        <span class="flex items-center gap-1 text-xs text-sky-200" title="In Progress">
          <span class="inline-block h-2.5 w-2.5 rounded-full bg-sky-400" aria-hidden="true"></span>
          <span class="tabular-nums">{@ip}</span>
        </span>
        <span class="flex items-center gap-1 text-xs text-emerald-200" title="Finished">
          <span class="inline-block h-2.5 w-2.5 rounded-full bg-emerald-400" aria-hidden="true">
          </span>
          <span class="tabular-nums">{@fin}</span>
        </span>
        <span class="hidden" data-total={@total} data-in-progress={@ip} data-finished={@fin}></span>
      </div>
      <div class="flex h-2 w-32 overflow-hidden rounded-full bg-white/10">
        <div class="h-full bg-emerald-400" style={"width: #{@done_pct}%"}></div>
        <div class="h-full bg-sky-400" style={"width: #{@ip_pct}%"}></div>
        <div class="h-full bg-transparent" style={"width: #{@rest_pct}%"}></div>
      </div>
    </div>
    """
  end

  defp percent(_n, 0), do: 0

  defp percent(n, total) when is_integer(n) and is_integer(total) and total > 0 do
    trunc(n * 100 / total)
  end

  # Function component: production status dot
  attr :status, :string, required: true

  defp health_dot(assigns) do
    status = String.downcase(to_string(assigns.status || ""))

    {color_class, label} =
      cond do
        status in ["ok", "passing", "healthy", "up"] -> {"bg-emerald-400", "Up"}
        status in ["degraded", "warn", "warning"] -> {"bg-amber-400", "Degraded"}
        status in ["fail", "failing", "down", "error"] -> {"bg-rose-400", "Down"}
        true -> {"bg-white/40", String.capitalize(status)}
      end

    assigns = assign(assigns, color: color_class, label: label)

    ~H"""
    <span class="inline-flex items-center gap-1" title={@label} aria-label={@label}>
      <span class={"inline-block h-2.5 w-2.5 rounded-full #{@color}"} aria-hidden="true"></span>
    </span>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-8">
      <div class="theme-card px-4 py-4 sm:px-6">
        <form
          id="client-filter-form"
          phx-change="filter"
          class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between"
        >
          <div class="flex flex-1 flex-col gap-2 sm:flex-row sm:items-center">
            <label
              for="client-filter"
              class="text-xs font-semibold uppercase tracking-[0.2em] text-theme-muted"
            >
              Filter by client
            </label>
            <select
              name="client_id"
              id="client-filter"
              class="w-full rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm text-white transition focus:border-white/30 focus:outline-none sm:w-64"
            >
              <option value="" selected={@client_id in [nil, ""]}>All Clients</option>
              <%= for c <- @clients do %>
                <option value={c.id} selected={to_string(c.id) == to_string(@client_id)}>
                  {c.name}
                </option>
              <% end %>
            </select>
          </div>

          <div class="flex flex-wrap items-center gap-3">
            <%= if @linear_enabled do %>
              <button
                type="button"
                phx-click="sync"
                class="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-4 py-2 text-xs font-semibold uppercase tracking-[0.16em] text-white transition hover:border-white/20 hover:bg-white/10"
              >
                Sync from Linear
              </button>
              <button
                type="button"
                phx-click="reload_summaries"
                class="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-4 py-2 text-xs font-semibold uppercase tracking-[0.16em] text-white transition hover:border-white/20 hover:bg-white/10"
              >
                Reload Tasks
              </button>
            <% else %>
              <span class="text-xs text-theme-muted">
                Linear not configured; set LINEAR_TOKEN to enable task breakdowns.
              </span>
            <% end %>
          </div>
        </form>
      </div>

      <%= if @projects == [] do %>
        <div class="theme-card px-6 py-8 text-center text-sm text-theme-muted">
          No projects found.
        </div>
      <% else %>
        <div class="theme-card overflow-x-auto">
          <table class="theme-table">
            <thead>
              <tr>
                <th class="hidden md:table-cell">ID</th>
                <th>Name</th>
                <th>Client</th>
                <th class="hidden md:table-cell whitespace-nowrap">
                  Tasks (Linear)
                  <%= if @summaries == %{} do %>
                    <span class="ml-2 inline-block h-4 w-4 animate-spin rounded-full border-2 border-white/40 border-t-transparent">
                    </span>
                  <% end %>
                </th>
                <th>Prod</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              <%= for p <- @projects do %>
                <tr>
                  <td class="hidden md:table-cell text-sm text-theme-muted">{p.id}</td>
                  <td>{p.name}</td>
                  <td>
                    <%= if is_nil(p.client) do %>
                      <.link
                        navigate={~p"/projects/#{p.id}/edit"}
                        class="text-white/80 transition hover:text-white"
                      >
                        Assign Client
                      </.link>
                    <% else %>
                      {p.client.name}
                    <% end %>
                  </td>
                  <td class="hidden md:table-cell">
                    <%= case Map.get(@summaries, to_string(p.id), :unavailable) do %>
                      <% :unavailable -> %>
                        <div class="flex items-center gap-3 text-xs text-theme-muted">
                          <div class="w-36 shrink-0">
                            <span class="inline-flex items-center rounded-full bg-white/5 px-2 py-0.5 text-white/70">
                              N/A
                            </span>
                          </div>
                          <div class="h-2 w-32 rounded-full bg-white/5"></div>
                        </div>
                      <% %{} = summary -> %>
                        <.tasks_cell summary={summary} />
                    <% end %>
                  </td>
                  <td>
                    <%= case Map.get(@health || %{}, p.id) do %>
                      <% nil -> %>
                        <span class="text-white/30">—</span>
                      <% status -> %>
                        <.health_dot status={status} />
                    <% end %>
                  </td>
                  <td>
                    <.link
                      navigate={~p"/projects/#{p.id}/edit"}
                      class="text-white/80 transition hover:text-white"
                    >
                      Edit
                    </.link>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
      <%= if @live_action in [:edit] do %>
        <.modal
          id="project-modal"
          show
          on_cancel={
            if @client_id in [nil, ""],
              do: JS.patch(~p"/projects"),
              else: JS.patch(~p"/projects?client_id=#{@client_id}")
          }
        >
          <.live_component
            module={DashboardSSDWeb.ProjectsLive.FormComponent}
            id={@params["id"]}
            action={@live_action}
            current_user={@current_user}
            patch={
              if @client_id in [nil, ""],
                do: ~p"/projects?r=1",
                else: ~p"/projects?client_id=#{@client_id}&r=1"
            }
            project_id={@params["id"]}
          />
        </.modal>
      <% end %>
    </div>
    """
  end
end
