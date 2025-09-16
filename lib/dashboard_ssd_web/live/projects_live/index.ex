defmodule DashboardSSDWeb.ProjectsLive.Index do
  use DashboardSSDWeb, :live_view

  alias DashboardSSD.{Clients, Projects}
  alias DashboardSSD.Integrations

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Projects")
     |> assign(:client_id, nil)
     |> assign(:projects, [])
     |> assign(:clients, Clients.list_clients())
     |> assign(:linear_enabled, linear_enabled?())
     |> assign(:summaries, %{})
     |> assign(:loaded, false)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket = assign(socket, :params, params)

    case socket.assigns.live_action do
      :edit -> handle_params_edit(params, socket)
      _ -> handle_params_index(params, socket)
    end
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
      summaries = summarize_projects(projects)

      {:noreply,
       socket
       |> assign(:page_title, "Projects")
       |> assign(:client_id, client_id)
       |> assign(:clients, Clients.list_clients())
       |> assign(:projects, projects)
       |> assign(:summaries, summaries)
       |> assign(:loaded, true)}
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
      Enum.into(projects, %{}, fn p -> {p.id, fetch_linear_summary(p)} end)
    else
      %{}
    end
  end

  defp fetch_linear_summary(project) do
    # Heuristic search by project name. In future, map to Linear team/project ID.
    query = """
    query IssueSearch($q: String!) {
      issueSearch(query: $q, first: 50) {
        nodes { id state { name } }
      }
    }
    """

    case Integrations.linear_list_issues(query, %{"q" => project.name}) do
      {:ok, %{"data" => %{"issueSearch" => %{"nodes" => nodes}}}} when is_list(nodes) ->
        total = length(nodes)

        {in_progress, finished} = summarize_nodes(nodes)

        %{total: total, in_progress: in_progress, finished: finished}

      _ ->
        :unavailable
    end
  end

  defp linear_enabled? do
    !!Application.get_env(:dashboard_ssd, :integrations, [])[:linear_token]
  end

  defp summarize_nodes(nodes) do
    Enum.reduce(nodes, {0, 0}, fn n, {ip, fin} ->
      s = String.downcase(get_in(n, ["state", "name"]) || "")

      cond do
        String.contains?(s, "done") or String.contains?(s, "complete") or
            String.contains?(s, "closed") ->
          {ip, fin + 1}

        String.contains?(s, "progress") or String.contains?(s, "doing") or
            String.contains?(s, "started") ->
          {ip + 1, fin}

        true ->
          {ip, fin}
      end
    end)
  end

  @impl true
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

  defp refresh(socket) do
    client_id = socket.assigns.client_id

    projects =
      case client_id do
        nil -> Projects.list_projects()
        "" -> Projects.list_projects()
        id -> Projects.list_projects_by_client(String.to_integer(id))
      end

    assign(socket, projects: projects, summaries: summarize_projects(projects))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center justify-between">
        <h1 class="text-xl font-semibold">{@page_title}</h1>
      </div>

      <div class="flex items-center gap-2">
        <form id="client-filter-form" phx-change="filter" class="flex items-center gap-2">
          <select name="client_id" id="client-filter" class="border rounded px-2 py-1 text-sm w-56">
            <option value="" selected={@client_id in [nil, ""]}>All Clients</option>
            <%= for c <- @clients do %>
              <option value={c.id} selected={to_string(c.id) == to_string(@client_id)}>
                {c.name}
              </option>
            <% end %>
          </select>
        </form>
        <%= if @linear_enabled do %>
          <button phx-click="sync" class="px-2 py-1 border rounded text-sm">Sync from Linear</button>
        <% else %>
          <span class="text-xs text-zinc-600">
            Linear not configured; set LINEAR_TOKEN to see task breakdowns.
          </span>
        <% end %>
      </div>

      <%= if @projects == [] do %>
        <p class="text-zinc-600">No projects found.</p>
      <% else %>
        <div class="overflow-hidden rounded border">
          <table class="w-full text-left text-sm">
            <thead class="bg-zinc-50">
              <tr>
                <th class="px-3 py-2">ID</th>
                <th class="px-3 py-2">Name</th>
                <th class="px-3 py-2">Client</th>
                <th class="px-3 py-2">Tasks (Linear)</th>
                <th class="px-3 py-2">Actions</th>
              </tr>
            </thead>
            <tbody>
              <%= for p <- @projects do %>
                <tr class="border-t">
                  <td class="px-3 py-2">{p.id}</td>
                  <td class="px-3 py-2">{p.name}</td>
                  <td class="px-3 py-2">
                    <%= if is_nil(p.client) do %>
                      <.link
                        navigate={~p"/projects/#{p.id}/edit"}
                        class="text-zinc-700 hover:underline"
                      >
                        Assign Client
                      </.link>
                    <% else %>
                      {p.client.name}
                    <% end %>
                  </td>
                  <td class="px-3 py-2">
                    <%= case Map.get(@summaries, p.id, :unavailable) do %>
                      <% :unavailable -> %>
                        <span class="text-zinc-500">N/A</span>
                      <% %{total: t, in_progress: ip, finished: fin} -> %>
                        <span class="inline-block mr-2">Total: <strong>{t}</strong></span>
                        <span class="inline-block mr-2">In Progress: <strong>{ip}</strong></span>
                        <span class="inline-block mr-2">Finished: <strong>{fin}</strong></span>
                      <% _ -> %>
                        <span class="text-zinc-500">No tasks</span>
                    <% end %>
                  </td>
                  <td class="px-3 py-2">
                    <.link navigate={~p"/projects/#{p.id}/edit"} class="text-zinc-700 hover:underline">
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
