defmodule DashboardSSDWeb.ProjectsLive.FormComponent do
  use DashboardSSDWeb, :live_component

  alias DashboardSSD.{Clients, Projects}
  alias DashboardSSD.Deployments

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

  def handle_event("save", %{"project" => params} = all_params, socket) do
    if admin?(socket.assigns.current_user) do
      _ =
        maybe_upsert_health_check_setting(socket.assigns.project, Map.get(all_params, "hc", %{}))

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

  defp maybe_upsert_health_check_setting(project, hc_params) when is_map(hc_params) do
    enabled = Map.get(hc_params, "enabled") == "on"
    provider = Map.get(hc_params, "provider")

    attrs =
      case provider do
        "http" ->
          %{
            enabled: enabled,
            provider: provider,
            endpoint_url: Map.get(hc_params, "http_url")
          }

        "aws_elbv2" ->
          %{
            enabled: enabled,
            provider: provider,
            aws_region: Map.get(hc_params, "aws_region"),
            aws_target_group_arn: Map.get(hc_params, "aws_target_group_arn")
          }

        _ ->
          %{enabled: enabled}
      end

    case Deployments.upsert_health_check_setting(project.id, attrs) do
      {:ok, _} -> :ok
      {:error, _} -> :ok
    end
  end

  defp maybe_upsert_health_check_setting(_project, _), do: :ok

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

        <fieldset class="mt-2 space-y-2">
          <legend class="block text-sm font-medium text-zinc-700">
            Production Health Check (optional)
          </legend>
          <label class="inline-flex items-center gap-2 text-sm">
            <input type="checkbox" name="hc[enabled]" /> Enable
          </label>
          <div class="grid grid-cols-2 gap-2">
            <div>
              <label class="block text-xs text-zinc-600">Provider</label>
              <select name="hc[provider]" class="mt-1 block w-full border rounded px-2 py-1 text-sm">
                <option value="">(select)</option>
                <option value="http">HTTP GET</option>
                <option value="aws_elbv2">AWS Target Group</option>
              </select>
            </div>
            <div>
              <label class="block text-xs text-zinc-600">HTTP URL</label>
              <input
                name="hc[http_url]"
                placeholder="https://service/health"
                class="mt-1 block w-full border rounded px-2 py-1 text-sm"
              />
            </div>
            <div>
              <label class="block text-xs text-zinc-600">AWS Region</label>
              <input
                name="hc[aws_region]"
                placeholder="us-east-1"
                class="mt-1 block w-full border rounded px-2 py-1 text-sm"
              />
            </div>
            <div class="col-span-2">
              <label class="block text-xs text-zinc-600">AWS Target Group ARN</label>
              <input
                name="hc[aws_target_group_arn]"
                placeholder="arn:aws:elasticloadbalancing:...:targetgroup/..."
                class="mt-1 block w-full border rounded px-2 py-1 text-sm"
              />
            </div>
          </div>
        </fieldset>

        <:actions>
          <.button>Save</.button>
          <.link patch={@patch} class="ml-2 text-zinc-700">Cancel</.link>
        </:actions>
      </.simple_form>
    </div>
    """
  end
end
