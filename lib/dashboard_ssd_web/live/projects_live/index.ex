defmodule DashboardSSDWeb.ProjectsLive.Index do
  @moduledoc "Projects hub listing with Linear task summary and health status."
  use DashboardSSDWeb, :live_view

  require Logger

  alias DashboardSSD.Auth.Policy
  alias DashboardSSD.{Clients, Projects}
  alias DashboardSSD.Deployments
  alias DashboardSSD.Integrations.LinearUtils

  @impl true
  @doc "Mount the Projects hub view and initialize state."
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if Policy.can?(user, :read, :projects) do
      {:ok,
       socket
       |> assign(:current_path, "/projects")
       |> assign(:page_title, "Projects")
       |> assign(:client_id, nil)
       |> assign(:projects, [])
       |> assign(:clients, Clients.list_clients())
       |> assign(:linear_enabled, LinearUtils.linear_enabled?())
       |> assign(:summaries, %{})
       |> assign(:loaded, false)
       |> assign(:mobile_menu_open, false)}
    else
      {:ok,
       socket
       |> assign(:current_path, "/projects")
       |> put_flash(:error, "You don't have permission to access this page")
       |> redirect(to: ~p"/")}
    end
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
    if LinearUtils.linear_enabled?() do
      Enum.into(projects, %{}, fn p -> {to_string(p.id), LinearUtils.fetch_linear_summary(p)} end)
    else
      %{}
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-8">
      <div class="card px-4 py-4 sm:px-6">
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
