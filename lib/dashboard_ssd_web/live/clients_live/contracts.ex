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
      projects = projects_for(user)
      client_assignment_missing? = is_nil(user && user.client_id)

      {:ok,
       socket
       |> assign(:current_path, "/clients/contracts")
       |> assign(:page_title, "Contracts & Docs")
       |> assign(:mobile_menu_open, false)
       |> assign(:project_id, nil)
       |> assign(:projects, projects)
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

    case Documents.list_client_documents(user, opts) do
      {:ok, docs} ->
        socket
        |> assign(:documents, docs)
        |> assign(:documents_error, nil)

      {:error, reason} ->
        assign(socket, :documents_error, reason)
    end
  end

  defp projects_for(%{client_id: client_id}) when is_integer(client_id) do
    Projects.list_projects_by_client(client_id)
  end

  defp projects_for(_), do: []

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
    <div class="flex flex-col gap-6">
      <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 class="text-2xl font-semibold text-theme-900">Contracts & Docs</h1>
          <p class="text-sm text-theme-500">
            Download executed contracts, SOWs, and KB links shared with your team.
          </p>
        </div>

        <%= if not Enum.empty?(@projects) do %>
          <form phx-change="filter" class="w-full sm:w-auto">
            <label class="sr-only">Project filter</label>
            <select
              name="project_id"
              value={@project_id}
              class="w-full rounded-md border border-theme-200 bg-white py-2 pl-3 pr-10 text-sm shadow-sm focus:border-theme-primary focus:outline-none"
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
          <div class="rounded-md border border-dashed border-yellow-300 bg-yellow-50 p-6 text-sm text-yellow-900">
            Your account is not linked to a client. Ask your Slickage contact to complete onboarding.
          </div>
        <% @documents_error -> %>
          <div class="rounded-md border border-red-300 bg-red-50 p-6 text-sm text-red-900">
            We couldn't load your documents right now. Please refresh the page later.
          </div>
        <% Enum.empty?(@documents) -> %>
          <div class="rounded-md border border-theme-200 bg-theme-50 p-8 text-center text-sm text-theme-600">
            No documents are available yet. We'll notify you once SOWs or contracts are published.
          </div>
        <% true -> %>
          <div class="grid gap-4 md:grid-cols-2">
            <%= for doc <- @documents do %>
              <div class="rounded-lg border border-theme-200 bg-white p-4 shadow-sm">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-base font-medium text-theme-900">{doc.title}</p>
                    <p class="text-xs uppercase tracking-wide text-theme-500">
                      {String.upcase(doc.doc_type || "")} · {doc.source}
                    </p>
                  </div>
                  <span class="text-xs text-theme-500">
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
