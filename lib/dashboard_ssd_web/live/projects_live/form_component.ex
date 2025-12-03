defmodule DashboardSSDWeb.ProjectsLive.FormComponent do
  @moduledoc """
  LiveComponent for editing a project and its health check settings.

    - Loads project data plus associated health-check settings for editing.
  - Validates and persists both project fields and health configuration changes.
  - Emits messages back to the parent LiveView so UI state stays in sync.
  """
  use DashboardSSDWeb, :live_component

  alias DashboardSSD.Auth.Policy
  alias DashboardSSD.Clients
  alias DashboardSSD.Deployments
  alias DashboardSSD.Projects

  @impl true
  @doc "Update the project form and prefill current health check settings."
  def update(assigns, socket) do
    socket = assign(socket, assigns)
    project = Projects.get_project!(String.to_integer(assigns.project_id))
    clients = Clients.list_clients()

    hc = Deployments.get_health_check_setting_by_project(project.id)

    {:ok,
     assign(socket,
       project: project,
       clients: clients,
       changeset: Projects.change_project(project),
       hc_enabled: hc && hc.enabled,
       hc_provider: hc && hc.provider,
       hc_http_url: hc && hc.endpoint_url,
       hc_aws_region: hc && hc.aws_region,
       hc_aws_target_group_arn: hc && hc.aws_target_group_arn
     )}
  end

  @impl true
  @doc "Handle form events (validate/save) for project and health settings."
  def handle_event(event, params, socket)

  def handle_event("validate", params, socket) do
    prj = Map.get(params, "project", %{})
    cs = Projects.change_project(socket.assigns.project, normalize_params(prj))
    hc = Map.get(params, "hc", %{})

    {:noreply,
     socket
     |> assign(:changeset, Map.put(cs, :action, :validate))
     |> assign(
       hc_enabled: hc["enabled"] == "on",
       hc_provider: hc["provider"],
       hc_http_url: hc["http_url"],
       hc_aws_region: hc["aws_region"],
       hc_aws_target_group_arn: hc["aws_target_group_arn"]
     )}
  end

  def handle_event("save", %{"project" => params} = all_params, socket) do
    if Policy.can?(socket.assigns.current_user, :manage, :projects) do
      hc_params = Map.get(all_params, "hc", %{})
      _ = maybe_upsert_health_check_setting(socket.assigns.project, hc_params)
      hc_flash = maybe_run_health_check_now(socket.assigns.project, hc_params)

      normalized_params = normalize_params(params)
      has_project_changes = project_changed?(socket.assigns.project, normalized_params)
      has_hc_changes = health_check_changed?(socket.assigns.project, hc_params)

      case Projects.update_project(socket.assigns.project, normalized_params) do
        {:ok, updated_project} ->
          # Send message to parent to update the project and close modal
          send(
            self(),
            {:project_updated, updated_project, hc_flash || "Project updated",
             has_project_changes or has_hc_changes}
          )

          {:noreply, socket}

        {:error, cs} ->
          {:noreply, assign(socket, :changeset, cs)}
      end
    else
      {:noreply, put_flash(socket, :error, "Forbidden")}
    end
  end

  defp maybe_upsert_health_check_setting(project, hc_params) when is_map(hc_params) do
    case Deployments.upsert_health_check_setting(project.id, build_hc_attrs(hc_params)) do
      {:ok, _} -> :ok
      {:error, _} -> :ok
    end
  end

  defp maybe_upsert_health_check_setting(_project, _), do: :ok

  defp build_hc_attrs(hc_params) do
    case Map.get(hc_params, "provider") do
      "http" -> build_http_attrs(hc_params)
      "aws_elbv2" -> build_aws_attrs(hc_params)
      _ -> %{enabled: false}
    end
  end

  defp build_http_attrs(hc_params) do
    enabled? = Map.get(hc_params, "enabled") == "on"
    url = String.trim(to_string(Map.get(hc_params, "http_url") || ""))

    %{
      enabled: enabled? and url != "",
      provider: "http",
      endpoint_url: url
    }
  end

  defp build_aws_attrs(hc_params) do
    enabled? = Map.get(hc_params, "enabled") == "on"
    region = String.trim(to_string(Map.get(hc_params, "aws_region") || ""))
    arn = String.trim(to_string(Map.get(hc_params, "aws_target_group_arn") || ""))

    %{
      enabled: enabled? and region != "" and arn != "",
      provider: "aws_elbv2",
      aws_region: region,
      aws_target_group_arn: arn
    }
  end

  defp maybe_run_health_check_now(project, hc_params) do
    enabled = Map.get(hc_params, "enabled") == "on"
    provider = Map.get(hc_params, "provider")

    if enabled and provider == "http" do
      case Deployments.run_health_check_now(project.id) do
        {:ok, status} -> "Project updated • Health: #{status}"
        _ -> "Project updated"
      end
    else
      nil
    end
  end

  defp normalize_params(params) do
    case params do
      %{"client_id" => ""} = p -> Map.put(p, "client_id", nil)
      p -> p
    end
  end

  defp project_changed?(project, params) do
    project.name != params["name"] or
      to_string(project.client_id) != params["client_id"]
  end

  defp health_check_changed?(project, hc_params) do
    hc = Deployments.get_health_check_setting_by_project(project.id)

    [
      {:enabled, Map.get(hc_params, "enabled") == "on"},
      {:provider, Map.get(hc_params, "provider")},
      {:endpoint_url, Map.get(hc_params, "http_url")},
      {:aws_region, Map.get(hc_params, "aws_region")},
      {:aws_target_group_arn, Map.get(hc_params, "aws_target_group_arn")}
    ]
    |> Enum.any?(fn {field, new_value} ->
      current_value = hc && Map.get(hc, field)
      current_value != new_value
    end)
  end

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
            <input type="checkbox" name="hc[enabled]" checked={@hc_enabled} /> Enable
          </label>
          <div class="grid grid-cols-2 gap-2">
            <div>
              <label class="block text-xs text-zinc-600">Provider</label>
              <select name="hc[provider]" class="mt-1 block w-full border rounded px-2 py-1 text-sm">
                <option value="" selected={is_nil(@hc_provider) or @hc_provider == ""}>
                  (select)
                </option>
                <option value="http" selected={@hc_provider == "http"}>HTTP GET</option>
                <option value="aws_elbv2" selected={@hc_provider == "aws_elbv2"}>
                  AWS Target Group
                </option>
              </select>
            </div>
            <div>
              <label class="block text-xs text-zinc-600">HTTP URL</label>
              <input
                name="hc[http_url]"
                value={@hc_http_url}
                placeholder="https://service/health"
                class="mt-1 block w-full border rounded px-2 py-1 text-sm"
              />
            </div>
            <div>
              <label class="block text-xs text-zinc-600">AWS Region</label>
              <input
                name="hc[aws_region]"
                value={@hc_aws_region}
                placeholder="us-east-1"
                class="mt-1 block w-full border rounded px-2 py-1 text-sm"
              />
            </div>
            <div class="col-span-2">
              <label class="block text-xs text-zinc-600">AWS Target Group ARN</label>
              <input
                name="hc[aws_target_group_arn]"
                value={@hc_aws_target_group_arn}
                placeholder="arn:aws:elasticloadbalancing:...:targetgroup/..."
                class="mt-1 block w-full border rounded px-2 py-1 text-sm"
              />
            </div>
          </div>
        </fieldset>

        <:actions class="flex justify-start">
          <.button capability={{:manage, :projects}} current_user={@current_user}>Save</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end
end
