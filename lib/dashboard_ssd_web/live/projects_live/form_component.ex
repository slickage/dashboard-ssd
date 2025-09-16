defmodule DashboardSSDWeb.ProjectsLive.FormComponent do
  use DashboardSSDWeb, :live_component

  alias DashboardSSD.{Clients, Projects}

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)
    project = Projects.get_project!(String.to_integer(assigns.project_id))
    clients = Clients.list_clients()

    {:ok,
     assign(socket,
       project: project,
       clients: clients,
       changeset: Projects.change_project(project)
     )}
  end

  @impl true
  def handle_event("validate", %{"project" => params}, socket) do
    cs = Projects.change_project(socket.assigns.project, normalize_params(params))
    {:noreply, assign(socket, :changeset, Map.put(cs, :action, :validate))}
  end

  def handle_event("save", %{"project" => params}, socket) do
    if admin?(socket.assigns.current_user) do
      case Projects.update_project(socket.assigns.project, normalize_params(params)) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Project updated")
           |> push_patch(to: socket.assigns.patch)}

        {:error, cs} ->
          {:noreply, assign(socket, :changeset, cs)}
      end
    else
      {:noreply, put_flash(socket, :error, "Forbidden")}
    end
  end

  defp normalize_params(params) do
    case params do
      %{"client_id" => ""} = p -> Map.put(p, "client_id", nil)
      p -> p
    end
  end

  defp admin?(user), do: user && user.role && user.role.name == "admin"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <h2 class="text-lg font-medium">Edit Project</h2>
      <.simple_form
        :let={f}
        for={@changeset}
        id="project-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={f[:name]} label="Name" />
        <.input
          type="select"
          field={f[:client_id]}
          label="Client"
          prompt="— Unassigned —"
          options={Enum.map(@clients, &{&1.name, &1.id})}
        />
        <:actions>
          <.button>Save</.button>
          <.link patch={@patch} class="ml-2 text-zinc-700">Cancel</.link>
        </:actions>
      </.simple_form>
    </div>
    """
  end
end
