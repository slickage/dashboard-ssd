defmodule DashboardSSDWeb.ClientsLive.Contracts do
  @moduledoc """
  Client-facing Contracts & Docs LiveView.
  """
  use DashboardSSDWeb, :live_view

  alias DashboardSSD.Auth.Policy
  alias DashboardSSD.Documents
  alias DashboardSSD.Projects

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if Policy.can?(user, :read, :client_contracts) do
      can_manage_contracts? = Policy.can?(user, :manage, :projects_contracts)
      projects = projects_for(user, can_manage_contracts?)
      client_assignment_missing? = not can_manage_contracts? and is_nil(user && user.client_id)

      {:ok,
       socket
       |> assign(:current_path, "/clients/contracts")
       |> assign(:page_title, "Contracts & Docs")
       |> assign(:mobile_menu_open, false)
       |> assign(:project_id, nil)
       |> assign(:projects, projects)
       |> assign(:can_manage_contracts?, can_manage_contracts?)
       |> assign(:client_assignment_missing?, client_assignment_missing?)
       |> assign(:documents_error, nil)
       |> load_documents()}
    else
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to view Contracts")
       |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    project_id = params |> Map.get("project_id") |> normalize_project_id()
    {:noreply, socket |> assign(:project_id, project_id) |> load_documents()}
  end

  @impl true
  def handle_event("filter", %{"project_id" => project_id}, socket) do
    project_id = normalize_project_id(project_id)

    {:noreply,
     socket
     |> assign(:project_id, project_id)
     |> push_patch(to: current_path(project_id))
     |> load_documents()}
  end

  def handle_event("toggle_mobile_menu", _params, socket) do
    {:noreply, assign(socket, mobile_menu_open: !socket.assigns.mobile_menu_open)}
  end

  def handle_event("close_mobile_menu", _params, socket) do
    {:noreply, assign(socket, mobile_menu_open: false)}
  end

  defp load_documents(%{assigns: %{client_assignment_missing?: true}} = socket) do
    assign(socket, :documents, [])
  end

  defp load_documents(socket) do
    user = socket.assigns.current_user
    opts = [project_id: socket.assigns.project_id]

    result =
      if socket.assigns.can_manage_contracts? do
        {:ok, Documents.list_staff_documents(Keyword.merge(opts, can_manage?: true))}
      else
        Documents.list_client_documents(user, opts)
      end

    case result do
      {:ok, docs} ->
        socket
        |> assign(:documents, docs)
        |> assign(:documents_error, nil)

      {:error, reason} ->
        assign(socket, :documents_error, reason)
    end
  end

  defp projects_for(_user, true) do
    Projects.list_projects()
  end

  defp projects_for(%{client_id: client_id}, _can_manage?) when is_integer(client_id) do
    Projects.list_projects_by_client(client_id)
  end

  defp projects_for(_, _), do: []

  defp normalize_project_id(value) when value in [nil, ""], do: nil

  defp normalize_project_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp current_path(nil), do: ~p"/clients/contracts"
  defp current_path(project_id), do: ~p"/clients/contracts?project_id=#{project_id}"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-6 text-theme-text">
      <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 class="text-2xl font-semibold">Contracts & Docs</h1>
          <p class="text-sm text-theme-muted">
            Download executed contracts, SOWs, and KB links shared with your team.
          </p>
        </div>

        <%= if not Enum.empty?(@projects) do %>
          <form phx-change="filter" class="w-full sm:w-auto">
            <label class="sr-only">Project filter</label>
            <select
              name="project_id"
              value={@project_id}
              class="w-full rounded-md border border-theme-border bg-theme-surface px-3 py-2 text-sm font-semibold text-theme-text shadow-theme-soft focus:border-theme-primary focus:outline-none focus:ring-1 focus:ring-theme-primary/70"
            >
              <option value="">All projects</option>
              <%= for project <- @projects do %>
                <option value={project.id} selected={@project_id == project.id}>
                  {project.name}
                </option>
              <% end %>
            </select>
          </form>
        <% end %>
      </div>

      <%= cond do %>
        <% @client_assignment_missing? -> %>
          <div class="theme-card border-dashed border-yellow-400/60 bg-yellow-50/10 p-6 text-sm text-theme-text">
            Your account is not linked to a client. Ask your Slickage contact to complete onboarding.
          </div>
        <% @documents_error -> %>
          <div class="theme-card border border-red-400/60 bg-red-50/10 p-6 text-sm text-theme-text">
            We couldn't load your documents right now. Please refresh the page later.
          </div>
        <% Enum.empty?(@documents) -> %>
          <div class="theme-card p-8 text-center text-sm text-theme-muted">
            No documents are available yet. We'll notify you once SOWs or contracts are published.
          </div>
        <% true -> %>
          <div class="grid gap-4 md:grid-cols-2">
            <%= for doc <- @documents do %>
              <div class="rounded-lg border border-theme-border bg-theme-surface p-4 shadow-theme-soft">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-base font-medium text-theme-text">{doc.title}</p>
                    <p class="text-xs uppercase tracking-wide text-theme-muted">
                      {String.upcase(doc.doc_type || "")} · {doc.source}
                    </p>
                  </div>
                  <span class="text-xs text-theme-muted">
                    Updated {format_timestamp(doc.updated_at)}
                  </span>
                </div>

                <div class="mt-4 flex gap-2">
                  <.link
                    href={~p"/shared_documents/#{doc.id}/download"}
                    method="post"
                    class="inline-flex items-center rounded-full bg-theme-primary px-3 py-1 text-xs font-semibold text-white shadow-sm hover:bg-theme-primary/90"
                  >
                    Download
                  </.link>

                  <% view_link =
                    case doc.metadata do
                      %{"webViewLink" => link} when is_binary(link) and link != "" -> link
                      %{webViewLink: link} when is_binary(link) and link != "" -> link
                      _ -> nil
                    end %>

                  <%= if view_link do %>
                    <.link
                      href={view_link}
                      target="_blank"
                      class="inline-flex items-center rounded-full border border-theme-border bg-theme-surface px-3 py-1 text-xs font-semibold text-theme-text shadow-theme-soft transition hover:border-theme-primary"
                    >
                      View in Drive
                    </.link>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
      <% end %>
    </div>
    """
  end

  defp format_timestamp(nil), do: "n/a"

  defp format_timestamp(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y")

  defp format_timestamp(%NaiveDateTime{} = ndt) do
    ndt |> DateTime.from_naive!("Etc/UTC") |> format_timestamp()
  end
end
