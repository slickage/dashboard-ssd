defmodule DashboardSSDWeb.ProjectsLive.Contracts do
  @moduledoc """
  Staff-facing Contracts & Docs console.
  """
  use DashboardSSDWeb, :live_view

  alias DashboardSSD.Auth.Policy
  alias DashboardSSD.Clients
  alias DashboardSSD.Documents

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if Policy.can?(user, :read, :projects_contracts) do
      clients = Clients.list_clients()

      {:ok,
       socket
       |> assign(:page_title, "Contracts (Staff)")
       |> assign(:current_path, "/projects/contracts")
       |> assign(:mobile_menu_open, false)
       |> assign(:clients, clients)
       |> assign(:filter_client_id, nil)
       |> assign(:can_manage?, Policy.can?(user, :manage, :projects_contracts))
       |> assign(:documents, Documents.list_staff_documents())
       |> assign(:flash_error, nil)}
    else
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to view Contracts.")
       |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    client_id = params |> Map.get("client_id") |> normalize_id()
    {:noreply, socket |> assign(:filter_client_id, client_id) |> load_documents()}
  end

  @impl true
  def handle_event("filter", %{"client_id" => client_id}, socket) do
    client_id = normalize_id(client_id)

    {:noreply,
     socket
     |> assign(:filter_client_id, client_id)
     |> push_patch(to: current_path(client_id))
     |> load_documents()}
  end

  def handle_event("toggle_visibility", %{"id" => id, "visibility" => visibility}, socket) do
    if socket.assigns.can_manage? do
      attrs = %{visibility: String.to_existing_atom(visibility)}
      update_document(socket, id, attrs)
    else
      {:noreply, socket}
    end
  end

  def handle_event("toggle_edit", %{"id" => id, "value" => value}, socket) do
    if socket.assigns.can_manage? do
      attrs = %{client_edit_allowed: value in ["true", true, "on"]}
      update_document(socket, id, attrs)
    else
      {:noreply, socket}
    end
  end

  def handle_event("toggle_mobile_menu", _params, socket) do
    {:noreply, assign(socket, :mobile_menu_open, !socket.assigns.mobile_menu_open)}
  end

  def handle_event("close_mobile_menu", _params, socket) do
    {:noreply, assign(socket, :mobile_menu_open, false)}
  end

  defp update_document(socket, id, attrs) do
    case Documents.update_document_settings(id, attrs, socket.assigns.current_user) do
      {:ok, _doc} ->
        {:noreply, socket |> put_flash(:info, "Document updated.") |> load_documents()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Unable to update document: #{inspect(reason)}")}
    end
  end

  defp load_documents(socket) do
    docs = Documents.list_staff_documents(client_id: socket.assigns.filter_client_id)
    assign(socket, :documents, docs)
  end

  defp normalize_id(value) when value in [nil, ""], do: nil

  defp normalize_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp normalize_id(value) when is_integer(value), do: value

  defp current_path(nil), do: ~p"/projects/contracts"
  defp current_path(client_id), do: ~p"/projects/contracts?client_id=#{client_id}"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-6">
      <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 class="text-2xl font-semibold text-theme-900">Contracts (Staff)</h1>
          <p class="text-sm text-theme-500">Review and adjust visibility for client documents.</p>
        </div>

        <%= if not Enum.empty?(@clients) do %>
          <form phx-change="filter" class="w-full sm:w-auto">
            <label class="sr-only">Client filter</label>
            <select
              name="client_id"
              value={@filter_client_id}
              class="w-full rounded-md border border-theme-200 bg-white py-2 pl-3 pr-10 text-sm shadow-sm focus:border-theme-primary focus:outline-none"
            >
              <option value="">All clients</option>
              <%= for client <- @clients do %>
                <option value={client.id} selected={@filter_client_id == client.id}>
                  {client.name}
                </option>
              <% end %>
            </select>
          </form>
        <% end %>
      </div>

      <div class="overflow-x-auto rounded-lg border border-theme-200 bg-white shadow-sm">
        <table class="min-w-full divide-y divide-theme-100 text-sm">
          <thead>
            <tr class="bg-theme-50 text-left text-xs font-semibold uppercase tracking-wide text-theme-500">
              <th class="px-4 py-3">Title</th>
              <th class="px-4 py-3">Client</th>
              <th class="px-4 py-3">Project</th>
              <th class="px-4 py-3">Source</th>
              <th class="px-4 py-3">Visibility</th>
              <th class="px-4 py-3">Warn</th>
              <th class="px-4 py-3">Edit?</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-theme-100">
            <%= for doc <- @documents do %>
              <tr>
                <td class="px-4 py-3 font-medium text-theme-900">
                  <div>{doc.title}</div>
                  <div class="text-xs text-theme-500">Type: {doc.doc_type}</div>
                </td>
                <td class="px-4 py-3 text-theme-700">{doc.client && doc.client.name}</td>
                <td class="px-4 py-3 text-theme-700">{(doc.project && doc.project.name) || "—"}</td>
                <td class="px-4 py-3 text-theme-700">{doc.source}</td>
                <td class="px-4 py-3">
                  <%= if @can_manage? do %>
                    <select
                      name="visibility"
                      phx-change="toggle_visibility"
                      phx-value-id={doc.id}
                      class="rounded-md border border-theme-200 bg-white px-2 py-1 text-xs shadow-sm"
                    >
                      <option value="client" selected={doc.visibility == :client}>Client</option>
                      <option value="internal" selected={doc.visibility == :internal}>
                        Internal
                      </option>
                    </select>
                  <% else %>
                    <span class="text-theme-700">{doc.visibility}</span>
                  <% end %>
                </td>
                <td class="px-4 py-3 text-xs text-yellow-600">
                  {warning_badge(doc)}
                </td>
                <td class="px-4 py-3">
                  <%= if @can_manage? do %>
                    <label class="inline-flex items-center gap-2 text-xs text-theme-700">
                      <input
                        type="checkbox"
                        name="value"
                        value="true"
                        phx-change="toggle_edit"
                        phx-value-id={doc.id}
                        checked={doc.client_edit_allowed}
                      /> Client can edit
                    </label>
                  <% else %>
                    {if doc.client_edit_allowed, do: "Allowed", else: "Read-only"}
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp warning_badge(%{visibility: :internal}), do: "Internal only"

  defp warning_badge(%{project: %{drive_folder_sharing_inherited: false}}),
    do: "Drive inheritance broken"

  defp warning_badge(_), do: ""
end
