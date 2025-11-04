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

    linear_enabled = LinearUtils.linear_enabled?()
    auto_sync? = linear_enabled and auto_linear_sync_enabled?()

    if Policy.can?(user, :read, :projects) do
      accessible_scope = accessible_client_scope(user)
      clients = clients_for_scope(accessible_scope)

      socket =
        socket
        |> assign(:current_path, "/projects")
        |> assign(:page_title, "Projects")
        |> assign(:client_id, nil)
        |> assign(:projects, [])
        |> assign(:clients, clients)
        |> assign(:accessible_client_scope, accessible_scope)
        |> assign(:client_filter_enabled?, client_filter_enabled?(accessible_scope))
        |> assign(:linear_enabled, linear_enabled)
        |> assign(:summaries, %{})
        |> assign(:loaded, false)
        |> assign(:mobile_menu_open, false)
        |> assign(:collapsed_teams, MapSet.new())
        |> assign(:team_members, %{})
        |> assign(:last_linear_sync_at, nil)
        |> assign(:last_linear_sync_reason, nil)
        |> assign(:summaries_cached, %{})
        |> assign(:summaries_task_ref, nil)
        |> assign(:summaries_task_context, nil)
        |> assign(:summaries_loading, false)
        |> hydrate_from_cached_sync()

      if auto_sync?, do: send(self(), :sync_from_linear)

      {:ok, socket}
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
    {:noreply, start_linear_sync(socket, context: :auto)}
  end

  @impl true
  def handle_info(:sync_from_linear, socket) do
    {:noreply, start_linear_sync(socket, context: :auto)}
  end

  @impl true
  def handle_info({ref, result}, %{assigns: %{summaries_task_ref: ref}} = socket)
      when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    context = socket.assigns.summaries_task_context || :auto

    {socket, _status} =
      handle_sync_result(socket, result, context: context, show_flash?: false)

    {:noreply,
     socket
     |> assign(:summaries_task_ref, nil)
     |> assign(:summaries_task_context, nil)
     |> assign(:summaries_loading, false)}
  end

  @impl true
  def handle_info({ref, _msg}, socket) when is_reference(ref) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {:DOWN, ref, :process, _pid, reason},
        %{assigns: %{summaries_task_ref: ref}} = socket
      ) do
    Logger.warning("Linear sync task exited: #{inspect(reason)}")

    {:noreply,
     socket
     |> assign(:summaries_task_ref, nil)
     |> assign(:summaries_task_context, nil)
     |> assign(:summaries_loading, false)}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:project_updated, updated_project, flash_message, has_changes}, socket) do
    # Update the project in the projects list (preload client association)
    updated_project = Projects.get_project!(updated_project.id)

    updated_projects =
      Enum.map(socket.assigns.projects, fn
        p when p.id == updated_project.id -> updated_project
        p -> p
      end)

    socket =
      socket
      |> assign(:projects, updated_projects)
      |> assign(
        :collapsed_teams,
        prune_collapsed(socket.assigns.collapsed_teams, updated_projects)
      )
      |> assign(:team_members, load_team_members(updated_projects))

    # Reload health data and summaries if there were changes
    socket =
      if has_changes do
        socket
        |> assign(:health, load_existing_health(updated_projects))
        |> assign(:summaries, %{})
      else
        socket
      end

    # Close the modal and navigate back to projects index
    {:noreply,
     socket
     |> put_flash(:info, flash_message)
     |> push_patch(to: ~p"/projects")}
  end

  defp handle_params_edit(%{"id" => id}, socket) do
    _project = Projects.get_project!(String.to_integer(id))

    # Ensure projects data is loaded when in edit mode
    if socket.assigns.loaded do
      {:noreply, socket}
    else
      # If not loaded, load the data like in index mode
      scope = socket.assigns[:accessible_client_scope] || :all
      client_id = socket.assigns.client_id || nil
      projects = fetch_projects(client_id, scope)
      spawn(fn -> run_checks_and_update(projects, self()) end)

      socket =
        socket
        |> assign(:projects, projects)
        |> assign(:health, load_existing_health(projects))
        |> assign(:loaded, true)
        |> assign(:summaries, %{})
        |> assign(:collapsed_teams, prune_collapsed(socket.assigns.collapsed_teams, projects))
        |> assign(:team_members, load_team_members(projects))
        |> maybe_schedule_summary_reload()
        |> hydrate_from_cached_sync()

      {:noreply, socket}
    end
  end

  defp handle_params_index(params, socket) do
    scope = socket.assigns[:accessible_client_scope] || :all
    client_id = params["client_id"]
    normalized_id = normalize_client_id_for_scope(scope, client_id)

    if reuse_loaded?(socket, normalized_id, params["r"]) do
      {:noreply,
       socket
       |> assign(:page_title, "Projects")
       |> assign(:client_id, normalized_id)
       |> assign(:accessible_client_scope, scope)
       |> assign(:client_filter_enabled?, client_filter_enabled?(scope))
       |> assign(:clients, clients_for_scope(scope))}
    else
      projects = fetch_projects(normalized_id, scope)
      schedule_health_checks(projects, self())

      collapsed = prune_collapsed(socket.assigns.collapsed_teams, projects)

      socket =
        socket
        |> assign(:page_title, "Projects")
        |> assign(:client_id, normalized_id)
        |> assign(:accessible_client_scope, scope)
        |> assign(:client_filter_enabled?, client_filter_enabled?(scope))
        |> assign(:clients, clients_for_scope(scope))
        |> assign(:projects, projects)
        |> assign(:health, load_existing_health(projects))
        |> assign(:loaded, true)
        |> assign(:summaries, %{})
        |> assign(:collapsed_teams, collapsed)
        |> assign(:team_members, load_team_members(projects))
        |> maybe_schedule_summary_reload()
        |> hydrate_from_cached_sync()

      {:noreply, socket}
    end
  end

  defp reuse_loaded?(socket, client_id, r_param) do
    socket.assigns[:client_id] == client_id and r_param in [nil, ""] and
      socket.assigns[:loaded] == true and socket.assigns[:projects] != nil and
      socket.assigns[:summaries] != nil
  end

  defp fetch_projects(client_id, :all) do
    case client_id do
      nil -> Projects.list_projects()
      "" -> Projects.list_projects()
      id -> Projects.list_projects_by_client(String.to_integer(id))
    end
  end

  defp fetch_projects(_client_id, []), do: []

  defp fetch_projects(client_id, ids) when is_list(ids) do
    case parse_client_id(client_id) do
      {:ok, id} ->
        if Enum.member?(ids, id) do
          Projects.list_projects_by_client(id)
        else
          Projects.list_projects_for_clients(ids)
        end

      _ ->
        Projects.list_projects_for_clients(ids)
    end
  end

  defp accessible_client_scope(nil), do: :all

  defp accessible_client_scope(%{role: %{name: "client"}, client_id: client_id})
       when is_integer(client_id) do
    [client_id]
  end

  defp accessible_client_scope(%{role: %{name: "client"}}), do: []
  defp accessible_client_scope(_), do: :all

  defp clients_for_scope(:all), do: Clients.list_clients()
  defp clients_for_scope([]), do: []

  defp clients_for_scope(ids) when is_list(ids) do
    ids
    |> Clients.list_clients_by_ids()
    |> Enum.sort_by(& &1.name)
  end

  defp client_filter_enabled?(:all), do: true
  defp client_filter_enabled?([]), do: false
  defp client_filter_enabled?(ids) when is_list(ids), do: length(ids) > 1

  defp normalize_client_id_for_scope(:all, client_id) do
    if client_id in [nil, ""], do: nil, else: client_id
  end

  defp normalize_client_id_for_scope([], _client_id), do: nil

  defp normalize_client_id_for_scope(ids, client_id) when is_list(ids) do
    case parse_client_id(client_id) do
      {:ok, id} ->
        if Enum.member?(ids, id), do: Integer.to_string(id), else: nil

      _ ->
        nil
    end
  end

  defp parse_client_id(nil), do: :error
  defp parse_client_id(""), do: :error
  defp parse_client_id(id) when is_integer(id), do: {:ok, id}

  defp parse_client_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {value, ""} -> {:ok, value}
      _ -> :error
    end
  end

  defp auto_linear_sync_enabled? do
    not Application.get_env(:dashboard_ssd, :test_env?, false)
  end

  @no_team_key "__no_team__"

  defp prune_collapsed(nil, projects), do: prune_collapsed(MapSet.new(), projects)

  defp prune_collapsed(collapsed, projects) do
    valid_keys =
      projects
      |> Enum.map(&project_team_identity/1)
      |> Enum.map(&elem(&1, 0))
      |> MapSet.new()

    MapSet.intersection(collapsed, valid_keys)
  end

  defp group_projects_by_team(projects, team_members_map) do
    {groups, order, _seen} =
      Enum.reduce(projects, {%{}, [], MapSet.new()}, fn project, {map, order, seen} ->
        {team_key, team_name} = project_team_identity(project)

        map =
          Map.update(
            map,
            team_key,
            %{key: team_key, name: team_name, projects: [project]},
            fn entry ->
              %{entry | projects: entry.projects ++ [project]}
            end
          )

        if MapSet.member?(seen, team_key) do
          {map, order, seen}
        else
          {map, order ++ [team_key], MapSet.put(seen, team_key)}
        end
      end)

    Enum.map(order, fn key ->
      entry = Map.fetch!(groups, key)

      members =
        if key == @no_team_key do
          []
        else
          team_members_map
          |> Map.get(key, [])
          |> Enum.map(&format_member_name/1)
          |> Enum.reject(&is_nil/1)
        end

      Map.put(entry, :members, members)
    end)
  end

  defp project_team_identity(project) do
    name = sanitized_team_name(project.linear_team_name) || "No Linear Team"

    case project.linear_team_id do
      id when is_binary(id) ->
        trimmed = String.trim(id)

        if trimmed == "" do
          {@no_team_key, name}
        else
          {trimmed, name}
        end

      _ ->
        {@no_team_key, name}
    end
  end

  defp sanitized_team_name(nil), do: nil

  defp sanitized_team_name(name) when is_binary(name) do
    trimmed = String.trim(name)
    if trimmed == "", do: nil, else: trimmed
  end

  defp sanitized_team_name(_), do: nil

  defp load_team_members(projects) do
    projects
    |> Enum.map(& &1.linear_team_id)
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
    |> case do
      [] ->
        %{}

      ids ->
        Projects.team_members_by_team_ids(ids)
        |> Enum.into(%{}, fn {team_id, members} -> {String.trim(team_id), members} end)
    end
  end

  defp format_member_name(%{display_name: name}) when is_binary(name) do
    name |> String.trim() |> presence()
  end

  defp format_member_name(%{name: name}) when is_binary(name) do
    name |> String.trim() |> presence()
  end

  defp format_member_name(%{email: email}) when is_binary(email) do
    email |> String.trim() |> presence()
  end

  defp format_member_name(_), do: nil

  defp presence(""), do: nil
  defp presence(value), do: value

  defp run_checks_and_update(projects, pid) do
    if Application.get_env(:dashboard_ssd, :env) != :test do
      health = run_current_health_checks(projects)
      send(pid, {:health_updated, health})
    end
  end

  defp schedule_health_checks([], _pid), do: :ok

  defp schedule_health_checks(projects, pid) do
    spawn(fn -> run_checks_and_update(projects, pid) end)
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

  defp handle_sync_result(socket, result, opts) do
    context = Keyword.get(opts, :context, :manual)
    show_flash? = Keyword.get(opts, :show_flash?, false)

    do_handle_sync_result(socket, result, context, show_flash?)
  end

  defp normalize_sync_info(info) do
    info
    |> Map.put_new(:cached?, false)
    |> Map.put_new(:cached_reason, :fresh)
    |> Map.put_new(:synced_at, DateTime.utc_now())
    |> Map.put_new(:message, nil)
    |> Map.update(:summaries, %{}, fn
      nil -> %{}
      summaries -> summaries
    end)
  end

  defp do_handle_sync_result(socket, {:ok, info}, _context, show_flash?) do
    info = normalize_sync_info(info)

    socket =
      socket
      |> maybe_refresh_projects(info)
      |> assign(:summaries, info.summaries || socket.assigns.summaries || %{})
      |> assign(:summaries_cached, info.summaries || socket.assigns.summaries_cached || %{})
      |> maybe_put_sync_flash(info, show_flash?)

    {socket, :ok}
  end

  defp do_handle_sync_result(socket, {:error, {:rate_limited, message}}, context, show_flash?) do
    Logger.warning("Linear sync rate limited#{context_suffix(context)}: #{message}")

    socket = maybe_put_rate_limit_flash(socket, message, show_flash?)
    {socket, :error}
  end

  defp do_handle_sync_result(socket, {:error, reason}, context, show_flash?) do
    Logger.warning("Linear sync failed#{context_suffix(context)}: #{inspect(reason)}")

    socket = maybe_put_error_flash(socket, reason, show_flash?)
    {socket, :error}
  end

  defp maybe_refresh_projects(socket, %{cached?: true} = info) do
    socket
    |> assign(:last_linear_sync_at, info.synced_at)
    |> assign(:last_linear_sync_reason, info.cached_reason)
  end

  defp maybe_refresh_projects(socket, info) do
    socket
    |> refresh()
    |> assign(:last_linear_sync_at, info.synced_at)
    |> assign(:last_linear_sync_reason, info.cached_reason)
  end

  defp format_sync_time(nil), do: "recently"

  defp format_sync_time(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M UTC")
  end

  defp format_sync_counts(%{inserted: i, updated: u}) do
    "(inserted=#{i}, updated=#{u})"
  end

  defp format_sync_counts(_), do: ""

  defp maybe_put_sync_flash(socket, %{cached_reason: :rate_limited, message: message}, false)
       when is_binary(message) and message != "" do
    put_flash(socket, :info, "Linear rate limit: #{message}")
  end

  defp maybe_put_sync_flash(socket, _info, false), do: socket

  defp maybe_put_sync_flash(socket, %{cached?: true, cached_reason: :fresh_cache} = info, true) do
    put_flash(
      socket,
      :info,
      "Linear data already up to date (last synced #{format_sync_time(info.synced_at)})."
    )
  end

  defp maybe_put_sync_flash(socket, %{cached?: true, cached_reason: :rate_limited} = info, true) do
    message = info.message || "Temporarily exceeded"

    put_flash(
      socket,
      :info,
      "Linear rate limit: #{message}. Showing cached data from #{format_sync_time(info.synced_at)}."
    )
  end

  defp maybe_put_sync_flash(socket, info, true) do
    put_flash(socket, :info, "Synced from Linear #{format_sync_counts(info)}")
  end

  defp maybe_put_rate_limit_flash(socket, message, true) do
    put_flash(socket, :error, "Linear rate limit: #{message}")
  end

  defp maybe_put_rate_limit_flash(socket, _message, false), do: socket

  defp maybe_put_error_flash(socket, reason, true) do
    put_flash(socket, :error, "Linear sync failed: #{inspect(reason)}")
  end

  defp maybe_put_error_flash(socket, _reason, false), do: socket

  defp context_suffix(:auto), do: " during auto-sync"
  defp context_suffix(_), do: ""

  @impl true
  @doc "Handle project events (sync, filter)."
  def handle_event("sync", _params, socket) do
    result = Projects.sync_from_linear(force: true)
    {socket, _status} = handle_sync_result(socket, result, context: :manual, show_flash?: true)
    {:noreply, socket}
  end

  @impl true
  def handle_event("filter", %{"client_id" => client_id}, socket) do
    scope = socket.assigns[:accessible_client_scope] || :all
    client_id = normalize_client_id_for_scope(scope, client_id)
    path = if is_nil(client_id), do: ~p"/projects", else: ~p"/projects?client_id=#{client_id}"
    {:noreply, push_patch(socket, to: path)}
  end

  @impl true
  def handle_event("toggle_team", %{"team" => team_key}, socket) do
    collapsed = socket.assigns.collapsed_teams || MapSet.new()

    collapsed =
      if MapSet.member?(collapsed, team_key) do
        MapSet.delete(collapsed, team_key)
      else
        MapSet.put(collapsed, team_key)
      end

    {:noreply, assign(socket, :collapsed_teams, collapsed)}
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

    schedule_health_checks(projects, self())

    collapsed = prune_collapsed(socket.assigns.collapsed_teams, projects)

    socket =
      assign(socket,
        projects: projects,
        summaries: socket.assigns.summaries_cached || socket.assigns.summaries || %{},
        health: load_existing_health(projects),
        collapsed_teams: collapsed,
        team_members: load_team_members(projects)
      )

    socket
  end

  defp schedule_summary_reload(pid, delay_ms)
       when is_pid(pid) and is_integer(delay_ms) and delay_ms >= 0 do
    Process.send_after(pid, :reload_summaries, delay_ms)
  end

  defp maybe_schedule_summary_reload(socket, delay_ms \\ 600) do
    cond do
      not socket.assigns.linear_enabled ->
        Logger.info("Linear not enabled")
        socket

      not connected?(socket) ->
        socket

      true ->
        Logger.info("Linear enabled, scheduling summary reload")
        schedule_summary_reload(self(), delay_ms)
        socket
    end
  end

  defp start_linear_sync(socket, opts) do
    env =
      Application.get_env(:dashboard_ssd, :env, Application.get_env(:elixir, :config_env, :prod))

    force? = Keyword.get(opts, :force?, false)
    context = Keyword.get(opts, :context, :auto)

    cond do
      env == :test ->
        result = Projects.sync_from_linear(force: force?)

        {socket, _status} =
          handle_sync_result(socket, result, context: context, show_flash?: false)

        assign(socket, :summaries_loading, false)

      socket.assigns.summaries_task_ref ->
        socket

      true ->
        task =
          Task.Supervisor.async_nolink(DashboardSSD.TaskSupervisor, fn ->
            Projects.sync_from_linear(force: force?)
          end)

        socket
        |> assign(:summaries_task_ref, task.ref)
        |> assign(:summaries_task_context, context)
        |> assign(:summaries_loading, true)
    end
  end

  defp hydrate_from_cached_sync(socket) do
    case Projects.cached_linear_sync() do
      {:ok, info} ->
        {socket, _status} =
          handle_sync_result(socket, {:ok, info}, context: :pre_warm, show_flash?: false)

        socket

      :miss ->
        socket
    end
  end

  defp summary_assigned(:unavailable), do: :unavailable

  defp summary_assigned(%{} = summary) do
    summary[:assigned] || summary["assigned"] || []
  end

  defp summary_assigned(_), do: []

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-8">
      <%= if @client_filter_enabled? do %>
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
                <%= if @accessible_client_scope == :all do %>
                  <option value="" selected={@client_id in [nil, ""]}>All Clients</option>
                <% end %>
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
              <% else %>
                <span class="text-xs text-theme-muted">
                  Linear not configured; set LINEAR_TOKEN to enable task breakdowns.
                </span>
              <% end %>
            </div>
          </form>
        </div>
      <% end %>

      <%= if @projects == [] do %>
        <div class="theme-card px-6 py-8 text-center text-sm text-theme-muted">
          No projects found.
        </div>
      <% else %>
        <div class="theme-card overflow-x-auto">
          <% groups = group_projects_by_team(@projects, @team_members || %{}) %>
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
                <th class="hidden lg:table-cell">Assigned</th>
                <th>Prod</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              <%= for group <- groups do %>
                <% collapsed = MapSet.member?(@collapsed_teams, group.key) %>
                <% count = length(group.projects) %>
                <tr class="border-b border-white/5 bg-white/5">
                  <td colspan="6">
                    <button
                      type="button"
                      phx-click="toggle_team"
                      phx-value-team={group.key}
                      data-team-name={group.name}
                      class="w-full rounded-lg bg-white/5 px-3 py-2 text-left text-sm text-theme-text transition hover:bg-white/10"
                    >
                      <div class="flex flex-col gap-1">
                        <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                          <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:gap-3">
                            <div class="flex items-start justify-between gap-3 sm:items-center sm:gap-3">
                              <div class="flex items-center gap-3">
                                <span class="font-mono text-xs text-theme-muted">
                                  {if collapsed, do: "[+]", else: "[-]"}
                                </span>
                                <span class="flex items-center gap-2">
                                  <span class="uppercase tracking-[0.18em] text-[10px] text-theme-text-muted">
                                    Team
                                  </span>
                                  <span class="font-semibold text-theme-text">{group.name}</span>
                                </span>
                              </div>
                              <span class="text-xs text-theme-muted sm:hidden">
                                {count} {if count == 1, do: "project", else: "projects"}
                              </span>
                            </div>
                            <%= if group.members != [] do %>
                              <div class="flex flex-col gap-1 text-xs text-theme-text-muted sm:flex-row sm:items-center sm:gap-2 sm:border-l sm:border-white/15 sm:pl-3">
                                <span class="uppercase tracking-[0.18em] text-[10px] text-theme-text-muted">
                                  Members
                                </span>
                                <span class="flex flex-wrap gap-1">
                                  <%= for member <- group.members do %>
                                    <span class="rounded-full bg-white/10 px-2 py-0.5 text-theme-text">
                                      {member}
                                    </span>
                                  <% end %>
                                </span>
                              </div>
                            <% end %>
                          </div>
                          <span class="hidden text-xs text-theme-muted sm:block">
                            {count} {if count == 1, do: "project", else: "projects"}
                          </span>
                        </div>
                      </div>
                    </button>
                  </td>
                </tr>
                <%= unless collapsed do %>
                  <%= for p <- group.projects do %>
                    <tr>
                      <td class="pl-6">{p.name}</td>
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
                      <% summary = Map.get(@summaries, to_string(p.id), :unavailable) %>
                      <% assigned = summary_assigned(summary) %>
                      <td class="hidden md:table-cell">
                        <%= case summary do %>
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
                      <td class="hidden lg:table-cell">
                        <%= case assigned do %>
                          <% :unavailable -> %>
                            <span class="text-xs text-theme-muted">N/A</span>
                          <% [] -> %>
                            <span class="text-xs text-theme-muted">—</span>
                          <% _ -> %>
                            <.assigned_cell assigned={assigned} />
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
                <% end %>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
      <%= if @live_action in [:edit] do %>
        <.modal id="project-modal" show on_cancel={JS.patch(~p"/projects")}>
          <.live_component
            module={DashboardSSDWeb.ProjectsLive.FormComponent}
            id={@params["id"]}
            action={@live_action}
            current_user={@current_user}
            project_id={@params["id"]}
          />
        </.modal>
      <% end %>
    </div>
    """
  end
end
