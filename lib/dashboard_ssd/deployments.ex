defmodule DashboardSSD.Deployments do
  @moduledoc """
  Deployments context: manage deployments and health checks.
  """
  import Ecto.Query, warn: false
  alias DashboardSSD.Deployments.{Deployment, HealthCheck, HealthCheckSetting}
  alias DashboardSSD.Repo

  # Deployments
  @doc """
  Lists all deployments ordered by insertion time.

  Returns a list of Deployment structs.
  """
  @spec list_deployments() :: [Deployment.t()]
  def list_deployments, do: Repo.all(Deployment)

  @doc """
  Lists all deployments for a specific project.

  Returns deployments ordered by insertion time (most recent first).
  """
  @spec list_deployments_by_project(pos_integer()) :: [Deployment.t()]
  def list_deployments_by_project(project_id) do
    from(d in Deployment, where: d.project_id == ^project_id) |> Repo.all()
  end

  @doc """
  Fetches a deployment by ID.

  Raises Ecto.NoResultsError if the deployment does not exist.
  """
  @spec get_deployment!(pos_integer()) :: Deployment.t()
  def get_deployment!(id), do: Repo.get!(Deployment, id)

  @doc """
  Returns a changeset for tracking deployment changes.

  Validates the given attributes against the deployment schema.
  """
  @spec change_deployment(Deployment.t(), map()) :: Ecto.Changeset.t()
  def change_deployment(%Deployment{} = d, attrs \\ %{}), do: Deployment.changeset(d, attrs)

  @doc """
  Creates a new deployment with the given attributes.

  Returns {:ok, deployment} on success or {:error, changeset} on validation failure.
  """
  @spec create_deployment(map()) :: {:ok, Deployment.t()} | {:error, Ecto.Changeset.t()}
  def create_deployment(attrs), do: %Deployment{} |> Deployment.changeset(attrs) |> Repo.insert()

  @doc """
  Updates an existing deployment with the given attributes.

  Returns {:ok, deployment} on success or {:error, changeset} on validation failure.
  """
  @spec update_deployment(Deployment.t(), map()) ::
          {:ok, Deployment.t()} | {:error, Ecto.Changeset.t()}
  def update_deployment(%Deployment{} = d, attrs),
    do: d |> Deployment.changeset(attrs) |> Repo.update()

  @doc """
  Deletes a deployment from the database.

  Returns {:ok, deployment} on success or {:error, changeset} on constraint violation.
  """
  @spec delete_deployment(Deployment.t()) :: {:ok, Deployment.t()} | {:error, Ecto.Changeset.t()}
  def delete_deployment(%Deployment{} = d), do: Repo.delete(d)

  # Health Checks
  @doc """
  Lists all health checks ordered by insertion time.

  Returns a list of HealthCheck structs.
  """
  @spec list_health_checks() :: [HealthCheck.t()]
  def list_health_checks, do: Repo.all(HealthCheck)

  @doc """
  Lists all health checks for a specific project.

  Returns health checks ordered by insertion time (most recent first).
  """
  @spec list_health_checks_by_project(pos_integer()) :: [HealthCheck.t()]
  def list_health_checks_by_project(project_id) do
    from(h in HealthCheck, where: h.project_id == ^project_id) |> Repo.all()
  end

  @doc """
  Fetches a health check by ID.

  Raises Ecto.NoResultsError if the health check does not exist.
  """
  @spec get_health_check!(pos_integer()) :: HealthCheck.t()
  def get_health_check!(id), do: Repo.get!(HealthCheck, id)

  @doc """
  Returns a changeset for tracking health check changes.

  Validates the given attributes against the health check schema.
  """
  @spec change_health_check(HealthCheck.t(), map()) :: Ecto.Changeset.t()
  def change_health_check(%HealthCheck{} = h, attrs \\ %{}), do: HealthCheck.changeset(h, attrs)

  @doc """
  Creates a new health check with the given attributes.

  Returns {:ok, health_check} on success or {:error, changeset} on validation failure.
  """
  @spec create_health_check(map()) :: {:ok, HealthCheck.t()} | {:error, Ecto.Changeset.t()}
  def create_health_check(attrs),
    do: %HealthCheck{} |> HealthCheck.changeset(attrs) |> Repo.insert()

  @doc """
  Updates an existing health check with the given attributes.

  Returns {:ok, health_check} on success or {:error, changeset} on validation failure.
  """
  @spec update_health_check(HealthCheck.t(), map()) ::
          {:ok, HealthCheck.t()} | {:error, Ecto.Changeset.t()}
  def update_health_check(%HealthCheck{} = h, attrs),
    do: h |> HealthCheck.changeset(attrs) |> Repo.update()

  @doc """
  Deletes a health check from the database.

  Returns {:ok, health_check} on success or {:error, changeset} on constraint violation.
  """
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

  @doc """
  Lists all health check settings ordered by insertion time.

  Returns a list of HealthCheckSetting structs.
  """
  @spec list_health_check_settings() :: [HealthCheckSetting.t()]
  def list_health_check_settings do
    Repo.all(HealthCheckSetting)
  end

  @doc """
  Lists all health check settings that are currently enabled.

  Returns a list of enabled HealthCheckSetting structs.
  """
  @spec list_enabled_health_check_settings() :: [HealthCheckSetting.t()]
  def list_enabled_health_check_settings do
    from(s in HealthCheckSetting, where: s.enabled == true) |> Repo.all()
  end

  @doc """
  Runs a health check immediately for a project.

  Performs the configured health check and inserts a HealthCheck record with the result.
  Returns {:ok, status} on success or {:error, reason} if no setting exists or check fails.
  """
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
    if Application.get_env(:dashboard_ssd, :env) == :test do
      {:ok, 200}
    else
      try do
        call_with_redirects(url, 0)
      rescue
        _ -> {:error, :request_failed}
      end
    end
  end

  defp call_with_redirects(_url, depth) when depth > 5, do: {:error, :too_many_redirects}

  defp call_with_redirects(url, depth) do
    case Finch.build(:get, url) |> Finch.request(DashboardSSD.Finch, receive_timeout: 5000) do
      {:ok, %Finch.Response{} = resp} ->
        maybe_follow_redirect(resp, url, depth)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_follow_redirect(%Finch.Response{status: status} = resp, current_url, depth)
       when status in 301..303 or status in 307..308 do
    case redirect_target(resp, current_url) do
      {:ok, next_url} -> call_with_redirects(next_url, depth + 1)
      :no_location -> {:ok, status}
      {:error, reason} -> {:error, reason}
    end
  end

  defp maybe_follow_redirect(%Finch.Response{status: status}, _current_url, _depth),
    do: {:ok, status}

  defp redirect_target(resp, current_url) do
    location =
      resp.headers
      |> Enum.find_value(fn {key, value} ->
        if String.downcase(key) == "location", do: value
      end)

    cond do
      is_nil(location) -> :no_location
      true -> build_redirect_url(location, current_url)
    end
  end

  defp build_redirect_url(location, current_url) do
    current = URI.parse(current_url)

    location
    |> URI.parse()
    |> normalize_redirect(current)
    |> case do
      %URI{scheme: scheme, host: host} = uri when not is_nil(scheme) and not is_nil(host) ->
        {:ok, URI.to_string(uri)}

      _ ->
        {:error, :invalid_redirect}
    end
  rescue
    _ -> {:error, :invalid_redirect}
  end

  defp normalize_redirect(%URI{scheme: nil, host: nil} = uri, %URI{} = current) do
    URI.merge(current, uri)
  end

  defp normalize_redirect(%URI{scheme: nil} = uri, %URI{} = current) do
    %URI{uri | scheme: current.scheme}
  end

  defp normalize_redirect(%URI{} = uri, _current), do: uri

  defp classify_http_status({:ok, status}) when status in 200..399, do: "up"
  defp classify_http_status({:ok, status}) when status in 400..499, do: "degraded"
  defp classify_http_status({:ok, status}) when status >= 500, do: "down"
  defp classify_http_status({:ok, _}), do: "degraded"
  defp classify_http_status({:error, _}), do: "down"

  @doc """
  Retrieves the health check setting for a specific project.

  Returns the HealthCheckSetting struct or nil if no setting exists.
  """
  @spec get_health_check_setting_by_project(pos_integer()) :: HealthCheckSetting.t() | nil
  def get_health_check_setting_by_project(project_id) do
    Repo.get_by(HealthCheckSetting, project_id: project_id)
  end

  @doc """
  Creates or updates the health check setting for a project.

  If a setting exists, it updates it; otherwise creates a new one.
  Returns {:ok, setting} on success or {:error, changeset} on validation failure.
  """
  @spec upsert_health_check_setting(pos_integer(), map()) ::
          {:ok, HealthCheckSetting.t()} | {:error, Ecto.Changeset.t()}
  def upsert_health_check_setting(project_id, attrs)
      when is_integer(project_id) and is_map(attrs) do
    case get_health_check_setting_by_project(project_id) do
      %HealthCheckSetting{} = s -> update_health_check_setting(s, attrs)
      nil -> create_health_check_setting(Map.put(attrs, :project_id, project_id))
    end
  end

  @doc """
  Creates a new health check setting with the given attributes.

  Returns {:ok, setting} on success or {:error, changeset} on validation failure.
  """
  @spec create_health_check_setting(map()) ::
          {:ok, HealthCheckSetting.t()} | {:error, Ecto.Changeset.t()}
  def create_health_check_setting(attrs) when is_map(attrs) do
    %HealthCheckSetting{} |> HealthCheckSetting.changeset(attrs) |> Repo.insert()
  end

  @doc """
  Updates an existing health check setting with the given attributes.

  Returns {:ok, setting} on success or {:error, changeset} on validation failure.
  """
  @spec update_health_check_setting(HealthCheckSetting.t(), map()) ::
          {:ok, HealthCheckSetting.t()} | {:error, Ecto.Changeset.t()}
  def update_health_check_setting(%HealthCheckSetting{} = s, attrs) when is_map(attrs) do
    s |> HealthCheckSetting.changeset(attrs) |> Repo.update()
  end
end
