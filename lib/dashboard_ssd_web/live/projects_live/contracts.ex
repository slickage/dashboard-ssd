defmodule DashboardSSDWeb.ProjectsLive.Contracts do
  @moduledoc """
  Staff-facing Contracts & Docs console.
  """
  use DashboardSSDWeb, :live_view

  alias DashboardSSD.Auth.Policy
  alias DashboardSSD.Clients
  alias DashboardSSD.Documents
  alias DashboardSSD.Projects

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if Policy.can?(user, :read, :projects_contracts) do
      clients = Clients.list_clients()
      sections = Documents.workspace_section_options()

      {:ok,
       socket
       |> assign(:page_title, "Contracts (Staff)")
       |> assign(:current_path, "/projects/contracts")
       |> assign(:mobile_menu_open, false)
       |> assign(:clients, clients)
       |> assign(:filter_client_id, nil)
       |> assign(:can_manage?, Policy.can?(user, :manage, :projects_contracts))
       |> assign(:documents, Documents.list_staff_documents())
       |> assign(:flash_error, nil)
       |> assign(:available_sections, sections)
       |> assign(:bootstrap_form, bootstrap_form_defaults(sections))}
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

  def handle_event("toggle_visibility", %{"doc_id" => id, "visibility" => visibility}, socket) do
    if socket.assigns.can_manage? do
      attrs = %{visibility: String.to_existing_atom(visibility)}
      update_document(socket, id, attrs)
    else
      {:noreply, socket}
    end
  end

  def handle_event("toggle_edit", %{"doc_id" => id, "value" => value}, socket) do
    if socket.assigns.can_manage? do
      attrs = %{client_edit_allowed: value in ["true", true, "on"]}
      update_document(socket, id, attrs)
    else
      {:noreply, socket}
    end
  end

  def handle_event("show_bootstrap_form", %{"id" => id}, socket) do
    if socket.assigns.can_manage? do
      project = Projects.get_project!(String.to_integer(id))

      if Projects.drive_folder_configured?(project) do
        {:noreply, open_bootstrap_form(socket, project)}
      else
        {:noreply,
         socket
         |> put_flash(:error, "Project is missing a Drive folder.")
         |> load_documents()}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("cancel_bootstrap_form", _params, socket) do
    {:noreply, reset_bootstrap_form(socket)}
  end

  def handle_event("submit_bootstrap_form", %{"project_id" => project_id} = params, socket) do
    if socket.assigns.can_manage? do
      project = Projects.get_project!(String.to_integer(project_id))

      if Projects.drive_folder_configured?(project) do
        sections = sanitize_sections(params["sections"], socket.assigns.available_sections)

        if sections == [] do
          {:noreply,
           assign_bootstrap_error(socket, project, sections, "Select at least one section.")}
        else
          Documents.bootstrap_workspace(project, sections: sections)

          {:noreply,
           socket
           |> put_flash(
             :info,
             bootstrap_flash(project, sections, socket.assigns.available_sections)
           )
           |> reset_bootstrap_form()}
        end
      else
        {:noreply,
         socket
         |> put_flash(:error, "Project is missing a Drive folder.")
         |> reset_bootstrap_form()}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("submit_bootstrap_form", _params, socket) do
    {:noreply, socket}
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
                <td class="px-4 py-3 text-theme-700">
                  <div class="flex items-center gap-2">
                    <span>{(doc.project && doc.project.name) || "—"}</span>
                    <%= if @can_manage? and doc.project do %>
                      <button
                        type="button"
                        class="text-xs font-medium text-theme-primary underline"
                        phx-click="show_bootstrap_form"
                        phx-value-id={doc.project.id}
                      >
                        Regenerate
                      </button>
                    <% end %>
                  </div>
                </td>
                <td class="px-4 py-3 text-theme-700">{doc.source}</td>
                <td class="px-4 py-3">
                  <%= if @can_manage? do %>
                    <form phx-change="toggle_visibility" class="inline">
                      <input type="hidden" name="doc_id" value={doc.id} />
                      <select
                        name="visibility"
                        class="rounded-md border border-theme-200 bg-white px-2 py-1 text-xs shadow-sm"
                      >
                        <option value="client" selected={doc.visibility == :client}>Client</option>
                        <option value="internal" selected={doc.visibility == :internal}>
                          Internal
                        </option>
                      </select>
                    </form>
                  <% else %>
                    <span class="text-theme-700">{doc.visibility}</span>
                  <% end %>
                </td>
                <td class="px-4 py-3 text-xs text-yellow-600">
                  {warning_badge(doc)}
                </td>
                <td class="px-4 py-3">
                  <%= if @can_manage? do %>
                    <form
                      phx-change="toggle_edit"
                      class="inline-flex items-center gap-2 text-xs text-theme-700"
                    >
                      <input type="hidden" name="doc_id" value={doc.id} />
                      <input
                        type="checkbox"
                        name="value"
                        value="true"
                        checked={doc.client_edit_allowed}
                      />
                      <span>Client can edit</span>
                    </form>
                  <% else %>
                    {if doc.client_edit_allowed, do: "Allowed", else: "Read-only"}
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <%= if @bootstrap_form.open? do %>
        <div class="mt-6 rounded-lg border border-theme-200 bg-white p-6 shadow-sm">
          <div class="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
            <div>
              <p class="text-base font-semibold text-theme-900">
                Regenerate workspace for {@bootstrap_form.project_name}
              </p>
              <p class="text-sm text-theme-500">
                Choose which Drive or Notion sections to recreate for this project.
              </p>
            </div>

            <button
              type="button"
              class="text-sm font-medium text-theme-600 hover:text-theme-800"
              phx-click="cancel_bootstrap_form"
            >
              Close
            </button>
          </div>

          <%= if @bootstrap_form.error do %>
            <div
              class="mt-3 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700"
              data-test="bootstrap-error"
            >
              {@bootstrap_form.error}
            </div>
          <% end %>

          <%= if Enum.empty?(@available_sections) do %>
            <p class="mt-4 text-sm text-theme-500">
              No workspace sections are configured. Update the workspace blueprint to enable manual regeneration.
            </p>
          <% else %>
            <form
              id="workspace-bootstrap-form"
              class="mt-4 space-y-4"
              phx-submit="submit_bootstrap_form"
            >
              <input type="hidden" name="project_id" value={@bootstrap_form.project_id} />

              <div class="grid gap-3 md:grid-cols-2">
                <%= for section <- @available_sections do %>
                  <label class="flex cursor-pointer items-center gap-3 rounded-md border border-theme-200 bg-white px-3 py-2 shadow-sm">
                    <input
                      type="checkbox"
                      class="h-4 w-4 rounded border-theme-300 text-theme-primary focus:ring-theme-primary"
                      name="sections[]"
                      value={section_value(section)}
                      checked={section.id in @bootstrap_form.selected_sections}
                    />

                    <div class="text-left">
                      <p class="text-sm font-medium text-theme-900">{section_label(section)}</p>
                      <p class="text-xs text-theme-500">{section_type_text(section)}</p>
                    </div>
                  </label>
                <% end %>
              </div>

              <div class="flex items-center gap-3">
                <button
                  type="submit"
                  class="inline-flex items-center rounded-md bg-theme-primary px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-theme-primary/90"
                >
                  Start regeneration
                </button>

                <button
                  type="button"
                  class="text-sm font-medium text-theme-600 hover:text-theme-800"
                  phx-click="cancel_bootstrap_form"
                >
                  Cancel
                </button>
              </div>
            </form>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp warning_badge(%{visibility: :internal}), do: "Internal only"

  defp warning_badge(%{project: %{drive_folder_sharing_inherited: false}}),
    do: "Drive inheritance broken"

  defp warning_badge(_), do: ""

  defp bootstrap_form_defaults(sections) do
    %{
      open?: false,
      project_id: nil,
      project_name: nil,
      selected_sections: default_selected_sections(sections),
      error: nil
    }
  end

  defp open_bootstrap_form(socket, project) do
    assign(socket, :bootstrap_form, %{
      open?: true,
      project_id: project.id,
      project_name: display_project_name(project),
      selected_sections: default_selected_sections(socket.assigns.available_sections),
      error: nil
    })
  end

  defp reset_bootstrap_form(socket) do
    assign(socket, :bootstrap_form, bootstrap_form_defaults(socket.assigns.available_sections))
  end

  defp assign_bootstrap_error(socket, project, sections, message) do
    assign(socket, :bootstrap_form, %{
      open?: true,
      project_id: project.id,
      project_name: display_project_name(project),
      selected_sections: sections,
      error: message
    })
  end

  defp default_selected_sections(sections) do
    allowed_ids =
      sections
      |> Enum.map(& &1.id)
      |> MapSet.new()

    Projects.workspace_sections()
    |> Enum.filter(&MapSet.member?(allowed_ids, &1))
  end

  defp sanitize_sections(values, sections) do
    allowed =
      sections
      |> Enum.map(& &1.id)
      |> MapSet.new()

    values
    |> List.wrap()
    |> Enum.map(&to_section_atom/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(&MapSet.member?(allowed, &1))
    |> Enum.uniq()
  end

  defp to_section_atom(value) when is_atom(value), do: value

  defp to_section_atom(value) when is_binary(value) do
    try do
      String.to_existing_atom(value)
    rescue
      ArgumentError -> nil
    end
  end

  defp to_section_atom(_), do: nil

  defp section_value(%{id: id}) when is_atom(id), do: Atom.to_string(id)
  defp section_value(%{id: id}) when is_binary(id), do: id
  defp section_value(_), do: ""

  defp section_label(%{label: label}) when is_binary(label) and label != "", do: label
  defp section_label(%{id: id}) when is_atom(id), do: humanize_atom(id)
  defp section_label(_), do: "Workspace section"

  defp section_type_text(%{type: type}) when is_atom(type) do
    "#{humanize_atom(type)} section"
  end

  defp section_type_text(_), do: "Workspace section"

  defp humanize_atom(atom) do
    atom
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp bootstrap_flash(project, sections, available_sections) do
    labels = sections |> section_labels(available_sections) |> Enum.join(", ")
    "Regenerating #{labels} for #{display_project_name(project)}."
  end

  defp section_labels(section_ids, available_sections) do
    label_map =
      available_sections
      |> Enum.into(%{}, fn section -> {section.id, section_label(section)} end)

    Enum.map(section_ids, fn id ->
      Map.get(label_map, id, humanize_atom(id))
    end)
  end

  defp display_project_name(%{client: %{name: client_name}, name: name})
       when is_binary(client_name) and client_name != "" and is_binary(name) and name != "" do
    "#{client_name} · #{name}"
  end

  defp display_project_name(%{name: name}) when is_binary(name) and name != "", do: name
  defp display_project_name(_), do: "project"
end
