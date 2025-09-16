defmodule DashboardSSD.Deployments do
  @moduledoc """
  Deployments context: manage deployments and health checks.
  """
  import Ecto.Query, warn: false
  alias DashboardSSD.Deployments.{Deployment, HealthCheck, HealthCheckSetting}
  alias DashboardSSD.Repo

  # Deployments
  @doc "List deployments"
  @spec list_deployments() :: [Deployment.t()]
  def list_deployments, do: Repo.all(Deployment)

  @doc "List deployments by project id"
  @spec list_deployments_by_project(pos_integer()) :: [Deployment.t()]
  def list_deployments_by_project(project_id) do
    from(d in Deployment, where: d.project_id == ^project_id) |> Repo.all()
  end

  @doc "Get a deployment by id"
  @spec get_deployment!(pos_integer()) :: Deployment.t()
  def get_deployment!(id), do: Repo.get!(Deployment, id)

  @doc "Return changeset for a deployment"
  @spec change_deployment(Deployment.t(), map()) :: Ecto.Changeset.t()
  def change_deployment(%Deployment{} = d, attrs \\ %{}), do: Deployment.changeset(d, attrs)

  @doc "Create a deployment"
  @spec create_deployment(map()) :: {:ok, Deployment.t()} | {:error, Ecto.Changeset.t()}
  def create_deployment(attrs), do: %Deployment{} |> Deployment.changeset(attrs) |> Repo.insert()

  @doc "Update a deployment"
  @spec update_deployment(Deployment.t(), map()) ::
          {:ok, Deployment.t()} | {:error, Ecto.Changeset.t()}
  def update_deployment(%Deployment{} = d, attrs),
    do: d |> Deployment.changeset(attrs) |> Repo.update()

  @doc "Delete a deployment"
  @spec delete_deployment(Deployment.t()) :: {:ok, Deployment.t()} | {:error, Ecto.Changeset.t()}
  def delete_deployment(%Deployment{} = d), do: Repo.delete(d)

  # Health Checks
  @doc "List health checks"
  @spec list_health_checks() :: [HealthCheck.t()]
  def list_health_checks, do: Repo.all(HealthCheck)

  @doc "List health checks by project id"
  @spec list_health_checks_by_project(pos_integer()) :: [HealthCheck.t()]
  def list_health_checks_by_project(project_id) do
    from(h in HealthCheck, where: h.project_id == ^project_id) |> Repo.all()
  end

  @doc "Get a health check by id"
  @spec get_health_check!(pos_integer()) :: HealthCheck.t()
  def get_health_check!(id), do: Repo.get!(HealthCheck, id)

  @doc "Return changeset for a health check"
  @spec change_health_check(HealthCheck.t(), map()) :: Ecto.Changeset.t()
  def change_health_check(%HealthCheck{} = h, attrs \\ %{}), do: HealthCheck.changeset(h, attrs)

  @doc "Create a health check"
  @spec create_health_check(map()) :: {:ok, HealthCheck.t()} | {:error, Ecto.Changeset.t()}
  def create_health_check(attrs),
    do: %HealthCheck{} |> HealthCheck.changeset(attrs) |> Repo.insert()

  @doc "Update a health check"
  @spec update_health_check(HealthCheck.t(), map()) ::
          {:ok, HealthCheck.t()} | {:error, Ecto.Changeset.t()}
  def update_health_check(%HealthCheck{} = h, attrs),
    do: h |> HealthCheck.changeset(attrs) |> Repo.update()

  @doc "Delete a health check"
  @spec delete_health_check(HealthCheck.t()) ::
          {:ok, HealthCheck.t()} | {:error, Ecto.Changeset.t()}
  def delete_health_check(%HealthCheck{} = h), do: Repo.delete(h)

  @doc """
  Return a map of project_id => latest health status for the given project IDs.

  If a project has no health checks, it will be absent from the map.
  """
  @spec latest_health_status_by_project_ids([pos_integer()]) :: %{
          optional(pos_integer()) => String.t()
        }
  def latest_health_status_by_project_ids(project_ids) when is_list(project_ids) do
    from(h in HealthCheck,
      where: h.project_id in ^project_ids and not is_nil(h.status),
      order_by: [desc: h.inserted_at]
    )
    |> Repo.all()
    |> Enum.reduce(%{}, fn h, acc -> Map.put_new(acc, h.project_id, h.status) end)
  end

  @doc "List all health check settings"
  @spec list_health_check_settings() :: [HealthCheckSetting.t()]
  def list_health_check_settings do
    Repo.all(HealthCheckSetting)
  end

  @doc "List enabled health check settings"
  @spec list_enabled_health_check_settings() :: [HealthCheckSetting.t()]
  def list_enabled_health_check_settings do
    from(s in HealthCheckSetting, where: s.enabled == true) |> Repo.all()
  end

  @doc "Run a health check immediately for a project, inserting a HealthCheck row on success"
  @spec run_health_check_now(pos_integer()) :: {:ok, String.t()} | {:error, term()}
  def run_health_check_now(project_id) do
    case get_health_check_setting_by_project(project_id) do
      %HealthCheckSetting{enabled: true, provider: "http", endpoint_url: url}
      when is_binary(url) and url != "" ->
        status = classify_http_status(do_http_get(url))
        _ = create_health_check(%{project_id: project_id, status: status})
        {:ok, status}

      %HealthCheckSetting{enabled: true, provider: "aws_elbv2"} ->
        {:error, :aws_not_configured}

      %HealthCheckSetting{} ->
        {:error, :invalid_config}

      nil ->
        {:error, :no_setting}
    end
  end

  defp do_http_get(url) do
    req = Finch.build(:get, url)

    case Finch.request(req, DashboardSSD.Finch) do
      {:ok, %Finch.Response{status: status}} -> {:ok, status}
      {:error, reason} -> {:error, reason}
    end
  rescue
    _ -> {:error, :request_failed}
  end

  defp classify_http_status({:ok, 200}), do: "up"
  defp classify_http_status({:ok, status}) when status in 500..599, do: "down"
  defp classify_http_status({:ok, status}) when status in 400..499, do: "degraded"
  defp classify_http_status({:ok, _}), do: "degraded"
  defp classify_http_status({:error, _}), do: "down"

  @doc "Get health check setting for a project, if any"
  @spec get_health_check_setting_by_project(pos_integer()) :: HealthCheckSetting.t() | nil
  def get_health_check_setting_by_project(project_id) do
    Repo.get_by(HealthCheckSetting, project_id: project_id)
  end

  @doc "Create or update health check setting for a project"
  @spec upsert_health_check_setting(pos_integer(), map()) ::
          {:ok, HealthCheckSetting.t()} | {:error, Ecto.Changeset.t()}
  def upsert_health_check_setting(project_id, attrs) do
    case get_health_check_setting_by_project(project_id) do
      %HealthCheckSetting{} = s -> update_health_check_setting(s, attrs)
      nil -> create_health_check_setting(Map.put(attrs, :project_id, project_id))
    end
  end

  @doc "Create a health check setting"
  @spec create_health_check_setting(map()) ::
          {:ok, HealthCheckSetting.t()} | {:error, Ecto.Changeset.t()}
  def create_health_check_setting(attrs) do
    %HealthCheckSetting{} |> HealthCheckSetting.changeset(attrs) |> Repo.insert()
  end

  @doc "Update a health check setting"
  @spec update_health_check_setting(HealthCheckSetting.t(), map()) ::
          {:ok, HealthCheckSetting.t()} | {:error, Ecto.Changeset.t()}
  def update_health_check_setting(%HealthCheckSetting{} = s, attrs) do
    s |> HealthCheckSetting.changeset(attrs) |> Repo.update()
  end
end
