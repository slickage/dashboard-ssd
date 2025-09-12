defmodule DashboardSSD.Deployments do
  @moduledoc """
  Deployments context: manage deployments and health checks.
  """
  import Ecto.Query, warn: false
  alias DashboardSSD.Deployments.{Deployment, HealthCheck}
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
end
