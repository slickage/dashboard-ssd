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

      projects =
        Projects.list_projects()

      {:ok,
       socket
       |> assign(:page_title, "Contracts (Staff)")
       |> assign(:current_path, "/projects/contracts")
       |> assign(:mobile_menu_open, false)
       |> assign(:clients, clients)
       |> assign(:projects_for_bootstrap, projects)
       |> assign(:filter_client_id, nil)
       |> assign(:can_manage?, Policy.can?(user, :manage, :projects_contracts))
       |> assign(
         :documents,
         Documents.list_staff_documents(
           can_manage?: Policy.can?(user, :manage, :projects_contracts)
         )
       )
       |> assign(:syncing_drive_docs?, false)
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

  def handle_event("toggle_edit", %{"doc_id" => id} = params, socket) do
    if socket.assigns.can_manage? do
      value = Map.get(params, "value")
      attrs = %{client_edit_allowed: value in ["true", true, "on"]}
      update_document(socket, id, attrs)
    else
      {:noreply, socket}
    end
  end

  def handle_event("show_bootstrap_form", %{"id" => id} = params, socket) do
    if socket.assigns.can_manage? do
      project = Projects.get_project!(String.to_integer(id))
      section_id = params["section"] && to_section_atom(params["section"])

      if Projects.drive_folder_configured?(project) do
        {:noreply, open_bootstrap_form(socket, project, only_section: section_id)}
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

  def handle_event("show_bootstrap_form_from_picker", %{"project_id" => project_id}, socket) do
    if socket.assigns.can_manage? do
      case Integer.parse(project_id || "") do
        {id, ""} ->
          project = Projects.get_project!(id)

          case Projects.ensure_drive_folder(project) do
            {:ok, updated} ->
              {:noreply,
               socket |> refresh_projects_for_bootstrap() |> open_bootstrap_form(updated)}

            {:error, reason} ->
              {:noreply,
               put_flash(socket, :error, "Unable to prepare Drive folder: #{inspect(reason)}")}
          end

        _ ->
          {:noreply, put_flash(socket, :error, "Select a project to regenerate.")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("cancel_bootstrap_form", _params, socket) do
    {:noreply, reset_bootstrap_form(socket)}
  end

  def handle_event(
        "submit_bootstrap_form",
        %{"project_id" => project_id} = params,
        %{assigns: %{can_manage?: true}} = socket
      ) do
    project = Projects.get_project!(String.to_integer(project_id))
    {:noreply, process_bootstrap_form(socket, project, params)}
  end

  def handle_event("submit_bootstrap_form", _params, socket), do: {:noreply, socket}

  def handle_event("sync_drive_docs", _params, %{assigns: %{can_manage?: true}} = socket) do
    caller = self()

    Task.start(fn ->
      result = Documents.sync_drive_documents(prune_missing?: true)
      send(caller, {:drive_sync_done, result})
    end)

    {:noreply, assign(socket, :syncing_drive_docs?, true)}
  end

  def handle_event("sync_drive_docs", _params, socket), do: {:noreply, socket}

  def handle_event("close_mobile_menu", _params, socket) do
    {:noreply, assign(socket, :mobile_menu_open, false)}
  end

  def handle_event("toggle_mobile_menu", _params, socket) do
    {:noreply, assign(socket, :mobile_menu_open, !socket.assigns.mobile_menu_open)}
  end

  @impl true
  def handle_info({:drive_sync_done, result}, socket) do
    socket =
      case result do
        :ok ->
          socket
          |> put_flash(:info, "Drive documents synced.")
          |> load_documents()

        {:ok, _counts} ->
          socket
          |> put_flash(:info, "Drive documents synced.")
          |> load_documents()

        {:error, reason} ->
          put_flash(socket, :error, "Drive sync failed: #{inspect(reason)}")
      end

    {:noreply, assign(socket, :syncing_drive_docs?, false)}
  end

  def handle_info(:refresh_docs_after_bootstrap, socket) do
    {:noreply, load_documents(socket)}
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

  defp refresh_projects_for_bootstrap(socket) do
    projects =
      Projects.list_projects()
      |> Enum.filter(&Projects.drive_folder_configured?/1)

    assign(socket, :projects_for_bootstrap, projects)
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
    <div class="flex flex-col gap-6 text-theme-900 dark:text-slate-100">
      <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 class="text-2xl font-semibold">Contracts (Staff)</h1>
          <p class="text-sm text-theme-muted">
            Review and adjust visibility for client documents.
          </p>
        </div>

        <div class="flex flex-wrap items-center gap-3">
          <.link
            navigate={~p"/projects"}
            class="inline-flex items-center gap-2 rounded-md border border-theme-border bg-theme-surface px-3 py-2 text-sm font-semibold text-theme-text shadow-theme-soft transition hover:border-theme-primary hover:text-theme-text"
          >
            <span aria-hidden="true">←</span> Back to Projects
          </.link>

          <%= if not Enum.empty?(@clients) do %>
            <form phx-change="filter" class="w-full sm:w-auto">
              <label class="sr-only">Client filter</label>
              <select
                name="client_id"
                value={@filter_client_id}
                class="w-full rounded-md border border-theme-border bg-theme-surface px-3 py-2 text-sm font-semibold text-theme-text shadow-theme-soft transition focus:border-theme-primary focus:outline-none focus:ring-1 focus:ring-theme-primary/70"
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
      </div>

      <%= if @can_manage? do %>
        <form
          phx-submit="show_bootstrap_form_from_picker"
          class="flex flex-col gap-3 rounded-md border border-theme-border bg-theme-surface p-4 shadow-theme-soft sm:flex-row sm:items-center sm:justify-between"
        >
          <div>
            <p class="text-sm font-semibold text-theme-text">Regenerate a workspace</p>
            <p class="text-xs text-theme-muted">
              Uses Drive/Notion templates to recreate sections for a project.
              <%= if Enum.empty?(@projects_for_bootstrap) do %>
                Configure a Drive folder on a project first.
              <% end %>
            </p>
          </div>

          <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:gap-3">
            <label class="sr-only" for="bootstrap-project-id">Project</label>
            <select
              id="bootstrap-project-id"
              name="project_id"
              class="rounded-md border border-theme-border bg-theme-surface px-3 py-2 text-sm font-semibold text-theme-text shadow-theme-soft focus:border-theme-primary focus:outline-none focus:ring-1 focus:ring-theme-primary/70"
              disabled={Enum.empty?(@projects_for_bootstrap)}
            >
              <option value="">Select a project</option>
              <%= if Enum.empty?(@projects_for_bootstrap) do %>
                <option value="" disabled>No projects with Drive folders</option>
              <% else %>
                <%= for project <- @projects_for_bootstrap do %>
                  <option value={project.id}>{display_project_name(project)}</option>
                <% end %>
              <% end %>
            </select>

            <button
              type="submit"
              class="inline-flex items-center rounded-md bg-theme-primary px-3 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-theme-primary/90 focus:outline-none focus:ring-2 focus:ring-theme-primary focus:ring-offset-2 focus:ring-offset-theme-surface"
              disabled={Enum.empty?(@projects_for_bootstrap)}
            >
              Regenerate
            </button>

            <button
              type="button"
              class="inline-flex items-center rounded-md bg-theme-surface-muted px-3 py-2 text-sm font-semibold text-theme-text shadow-sm transition hover:bg-theme-surface focus:outline-none focus:ring-2 focus:ring-theme-primary focus:ring-offset-2 focus:ring-offset-theme-surface disabled:opacity-50"
              phx-click="sync_drive_docs"
              disabled={@syncing_drive_docs?}
            >
              <%= if @syncing_drive_docs? do %>
                <span class="flex items-center gap-2">
                  <.icon name="hero-arrow-path" class="h-4 w-4 animate-spin" /> Syncing…
                </span>
              <% else %>
                Sync Drive docs
              <% end %>
            </button>
          </div>
        </form>
      <% end %>

      <div class="overflow-x-auto rounded-xl theme-card">
        <table class="min-w-full divide-y divide-theme-border text-sm">
          <thead>
            <tr class="bg-theme-surface-muted text-left text-xs font-semibold uppercase tracking-wide text-theme-text">
              <th class="px-4 py-3">Title</th>
              <th class="px-4 py-3">Client</th>
              <th class="px-4 py-3">Project</th>
              <th class="px-4 py-3">Source</th>
              <th class="px-4 py-3">Visibility</th>
              <th class="px-4 py-3">Warn</th>
              <th class="px-4 py-3">Edit?</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-theme-border">
            <%= for doc <- @documents do %>
              <tr class="bg-theme-surface transition hover:bg-theme-surface-muted">
                <td class="px-4 py-3 font-semibold text-theme-text">
                  <div>{doc.title}</div>
                  <div class="text-xs text-theme-muted">
                    Type: {doc.doc_type}
                  </div>
                </td>
                <td class="px-4 py-3 text-theme-text">
                  {doc.client && doc.client.name}
                </td>
                <td class="px-4 py-3 text-theme-text">
                  <div class="flex items-center gap-2">
                    <span>{(doc.project && doc.project.name) || "—"}</span>
                    <%= if @can_manage? and doc.project do %>
                      <button
                        type="button"
                        class="text-xs font-semibold rounded bg-theme-primary px-2 py-1 text-white shadow-theme-soft transition hover:bg-theme-primary/90"
                        phx-click="show_bootstrap_form"
                        phx-value-id={doc.project.id}
                        phx-value-section={doc_section(doc)}
                      >
                        Regenerate
                      </button>
                    <% end %>
                  </div>
                </td>
                <td class="px-4 py-3 text-theme-text">{doc.source}</td>
                <td class="px-4 py-3 text-theme-text">
                  <%= if @can_manage? do %>
                    <form phx-change="toggle_visibility" class="inline">
                      <input type="hidden" name="doc_id" value={doc.id} />
                      <select
                        name="visibility"
                        class={
                          "rounded-md border border-theme-border bg-theme-surface px-3 py-2 pr-9 text-xs font-semibold text-theme-text shadow-theme-soft leading-snug " <>
                            "focus:border-theme-primary focus:outline-none focus:ring-1 focus:ring-theme-primary/70 appearance-none bg-no-repeat bg-[right_0.75rem_center] " <>
                            "bg-[url('data:image/svg+xml;utf8,<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 20 20\" fill=\"%23A0AEC0\"><path fill-rule=\"evenodd\" d=\"M5.23 7.21a.75.75 0 011.06.02L10 10.94l3.71-3.71a.75.75 0 111.06 1.06l-4.24 4.25a.75.75 0 01-1.06 0L5.21 8.29a.75.75 0 01.02-1.08z\" clip-rule=\"evenodd\"/></svg>')]"
                        }
                      >
                        <option value="client" selected={doc.visibility == :client}>Client</option>
                        <option value="internal" selected={doc.visibility == :internal}>
                          Internal
                        </option>
                      </select>
                    </form>
                  <% else %>
                    <span class="rounded-md bg-theme-surface-muted px-2 py-1 text-xs font-semibold text-theme-text">
                      {doc.visibility}
                    </span>
                  <% end %>
                </td>
                <td class="px-4 py-3 text-theme-text">
                  <%= case warning_badge(doc) do %>
                    <% "" -> %>
                      <span class="text-theme-muted">—</span>
                    <% badge -> %>
                      <span class="rounded-md bg-orange-100 px-2 py-1 text-xs font-semibold text-orange-900">
                        {badge}
                      </span>
                  <% end %>
                </td>
                <td class="px-4 py-3 text-theme-text">
                  <%= if @can_manage? do %>
                    <form
                      phx-change="toggle_edit"
                      class="inline-flex items-center gap-2 text-xs font-semibold text-theme-text"
                    >
                      <input type="hidden" name="doc_id" value={doc.id} />
                      <input
                        type="checkbox"
                        name="value"
                        value="true"
                        checked={doc.client_edit_allowed}
                        class="rounded border-theme-border text-theme-primary focus:ring-theme-primary"
                      />
                      <span>Client can edit</span>
                    </form>
                  <% else %>
                    <span class="text-theme-muted">
                      {if doc.client_edit_allowed, do: "Allowed", else: "Read-only"}
                    </span>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <%= if @bootstrap_form.open? do %>
        <div class="mt-6 rounded-xl theme-card p-6">
          <div class="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
            <div>
              <p class="text-base font-semibold text-theme-text">
                Regenerate workspace for {@bootstrap_form.project_name}
              </p>
              <p class="text-sm text-theme-muted">
                Choose which Drive or Notion sections to recreate for this project.
              </p>
            </div>

            <button
              type="button"
              class="inline-flex items-center gap-2 rounded-md border border-theme-border bg-theme-surface px-3 py-1.5 text-sm font-semibold text-theme-text shadow-theme-soft transition hover:border-theme-primary hover:text-theme-primary focus:outline-none focus:ring-2 focus:ring-theme-primary focus:ring-offset-2 focus:ring-offset-theme-surface"
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
            <p class="mt-4 text-sm text-theme-muted">
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
                  <label class="flex cursor-pointer items-center gap-3 rounded-md border border-theme-border bg-theme-surface-muted px-3 py-2 shadow-theme-soft hover:border-theme-primary">
                    <input
                      type="checkbox"
                      class="h-4 w-4 rounded border-theme-border text-theme-primary focus:ring-theme-primary"
                      name="sections[]"
                      value={section_value(section)}
                      checked={section.id in @bootstrap_form.selected_sections}
                    />

                    <div class="text-left">
                      <p class="text-sm font-semibold text-theme-text">
                        {section_label(section)}
                      </p>
                      <p class="text-xs text-theme-muted">
                        {section_type_text(section)}
                      </p>
                    </div>
                  </label>
                <% end %>
              </div>

              <div class="flex items-center gap-3">
                <button
                  type="submit"
                  class="inline-flex items-center rounded-md bg-theme-primary px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-theme-primary/90 focus:outline-none focus:ring-2 focus:ring-theme-primary focus:ring-offset-2 focus:ring-offset-theme-surface"
                >
                  Start regeneration
                </button>

                <button
                  type="button"
                  class="inline-flex items-center gap-2 rounded-md border border-theme-border bg-theme-surface px-3 py-1.5 text-sm font-semibold text-theme-text shadow-theme-soft transition hover:border-theme-primary hover:text-theme-primary focus:outline-none focus:ring-2 focus:ring-theme-primary focus:ring-offset-2 focus:ring-offset-theme-surface"
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

  defp open_bootstrap_form(socket, project, opts \\ []) do
    selected =
      case Keyword.get(opts, :only_section) do
        nil -> default_selected_sections(socket.assigns.available_sections)
        section when is_atom(section) -> [section]
        _ -> default_selected_sections(socket.assigns.available_sections)
      end

    assign(socket, :bootstrap_form, %{
      open?: true,
      project_id: project.id,
      project_name: display_project_name(project),
      selected_sections: selected,
      error: nil
    })
  end

  defp doc_section(%{doc_type: "contract"}), do: :drive_contracts
  defp doc_section(%{doc_type: "sow"}), do: :drive_sow
  defp doc_section(%{doc_type: "change_order"}), do: :drive_change_orders
  defp doc_section(_), do: nil

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

  defp process_bootstrap_form(socket, project, params) do
    if Projects.drive_folder_configured?(project) do
      sections = sanitize_sections(Map.get(params, "sections"), socket.assigns.available_sections)

      case sections do
        [] ->
          assign_bootstrap_error(socket, project, sections, "Select at least one section.")

        _ ->
          case Documents.bootstrap_workspace_sync(project, sections: sections) do
            {:ok, _result} ->
              socket
              |> put_flash(
                :info,
                bootstrap_flash(project, sections, socket.assigns.available_sections)
              )
              |> reset_bootstrap_form()
              |> load_documents()

            {:error, reason} ->
              socket
              |> put_flash(:error, "Workspace bootstrap failed: #{inspect(reason)}")
              |> reset_bootstrap_form()
          end
      end
    else
      socket
      |> put_flash(:error, "Project is missing a Drive folder.")
      |> reset_bootstrap_form()
    end
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
    |> String.split(" ", trim: true)
    |> Enum.map_join(" ", &String.capitalize/1)
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
