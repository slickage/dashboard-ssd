defmodule DashboardSSD.Analytics.Collector do
  @moduledoc """
  Automated metrics collection system.

  Collects various system metrics automatically:
  - Uptime from health checks
  - Response times for configured endpoints
  - Error rates and other performance indicators

  Supported health check providers: http, aws_elbv2, custom

    - Orchestrates scheduled metric collection across all projects and health providers.
  - Persists derived metrics (uptime, MTTR, response times) via the Analytics context.
  - Logs provider-specific warnings for unimplemented collectors to aid future work.
  """

  require Logger
  import Ecto.Query, warn: false
  alias DashboardSSD.{Analytics, Deployments, Repo}

  @doc """
  Collects all available metrics for all projects.

  This function:
  1. Gets all projects with health check settings
  2. Collects uptime metrics from health checks
  3. Collects response time metrics for HTTP endpoints
  4. Stores all metrics with timestamps
  """
  @spec collect_all_metrics() :: :ok
  def collect_all_metrics do
    Logger.info("Starting automated metrics collection")

    # Get all projects with health check settings
    health_settings = Deployments.list_enabled_health_check_settings()

    Enum.each(health_settings, fn setting ->
      collect_project_metrics(setting)
    end)

    Logger.info("Completed automated metrics collection")
  end

  @doc """
  Collects metrics for a specific project based on its health check settings.
  """
  @spec collect_project_metrics(Deployments.HealthCheckSetting.t()) :: :ok
  def collect_project_metrics(%{project_id: project_id} = setting) do
    case setting.provider do
      "http" ->
        collect_http_metrics(project_id, setting)
        # Calculate MTTR after collecting current metrics
        collect_mttr(project_id)

      "aws_elbv2" ->
        Logger.warning(
          "AWS ELBv2 metrics collection not yet implemented for project #{project_id}"
        )

      "custom" ->
        Logger.warning(
          "Custom health check metrics collection not yet implemented for project #{project_id}"
        )

      _ ->
        Logger.warning("Unknown health check provider: #{setting.provider}")
    end
  end

  @doc """
  Collects HTTP-based metrics for a project.

  Metrics collected:
  - Uptime (from health check status)
  - Response time
  """
  @spec collect_http_metrics(integer(), Deployments.HealthCheckSetting.t()) :: :ok
  def collect_http_metrics(project_id, %{endpoint_url: url} = _setting) when is_binary(url) do
    Logger.debug("Collecting HTTP metrics for project #{project_id}: #{url}")

    _start_time = System.monotonic_time(:millisecond)

    case collect_response_time(url) do
      {:ok, response_time_ms} ->
        # Record response time metric
        {:ok, _} =
          Analytics.create_metric(%{
            project_id: project_id,
            type: "response_time",
            value: response_time_ms
          })

        # Also record uptime as 100% (since we got a response)
        {:ok, _} =
          Analytics.create_metric(%{
            project_id: project_id,
            type: "uptime",
            value: 100.0
          })

        Logger.debug(
          "Collected metrics for project #{project_id}: response_time=#{response_time_ms}ms, uptime=100%"
        )

      {:error, reason} ->
        # Record downtime
        {:ok, _} =
          Analytics.create_metric(%{
            project_id: project_id,
            type: "uptime",
            value: 0.0
          })

        Logger.debug("Failed to collect metrics for project #{project_id}: #{inspect(reason)}")
    end
  end

  @doc """
  Measures response time for an HTTP endpoint.
  """
  @spec collect_response_time(String.t()) :: {:ok, float()} | {:error, term()}
  def collect_response_time(url) do
    start_time = System.monotonic_time(:millisecond)

    case Finch.build(:get, url) |> Finch.request(DashboardSSD.Finch, receive_timeout: 5000) do
      {:ok, %Finch.Response{}} ->
        end_time = System.monotonic_time(:millisecond)
        response_time = end_time - start_time
        # Convert to float
        {:ok, response_time * 1.0}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("Error collecting response time for #{url}: #{inspect(e)}")
      {:error, e}
  end

  @doc """
  Collects Linear throughput metrics by analyzing recent Linear issues.

  This would integrate with the existing Linear integration to count
  issues completed in the last time period.
  """
  @spec collect_linear_throughput(integer()) :: :ok
  def collect_linear_throughput(project_id) do
    # This would:
    # 1. Query Linear API for issues in the project
    # 2. Count completed issues in the last period
    # 3. Calculate throughput rate

    Logger.debug("Linear throughput collection not yet implemented for project #{project_id}")
  end

  @doc """
  Collects MTTR (Mean Time To Recovery) metrics.

  Analyzes recent uptime metrics to calculate average recovery time
  from failures. MTTR is calculated as the average time between
  a failure (uptime = 0) and the next success (uptime = 100).
  """
  @spec collect_mttr(integer()) :: :ok
  def collect_mttr(project_id) do
    # Get recent uptime metrics (last 24 hours)
    end_time = DateTime.utc_now()
    start_time = DateTime.add(end_time, -24 * 60 * 60, :second)

    uptimes =
      Repo.all(
        from m in DashboardSSD.Analytics.MetricSnapshot,
          where: m.project_id == ^project_id,
          where: m.type == "uptime",
          where: m.inserted_at >= ^start_time,
          where: m.inserted_at <= ^end_time,
          order_by: [asc: m.inserted_at]
      )

    case calculate_mttr_from_uptimes(uptimes) do
      {:ok, mttr_minutes} ->
        {:ok, _} =
          Analytics.create_metric(%{
            project_id: project_id,
            type: "mttr",
            value: mttr_minutes
          })

        Logger.warning("Collected MTTR for project #{project_id}: #{mttr_minutes} minutes")

      :no_failures ->
        Logger.warning("No failures found for MTTR calculation in project #{project_id}")
    end
  end

  @doc """
  Calculates MTTR from a list of uptime metrics.

  Returns the average time in minutes between failures and recoveries.
  """
  @spec calculate_mttr_from_uptimes([map()]) :: {:ok, float()} | :no_failures
  def calculate_mttr_from_uptimes(uptimes) do
    # Sort by timestamp
    sorted_uptimes = Enum.sort_by(uptimes, & &1.inserted_at)

    # Find failure periods
    failure_periods = find_failure_periods(sorted_uptimes)

    if failure_periods == [] do
      :no_failures
    else
      # Calculate average recovery time in minutes
      total_recovery_time =
        Enum.reduce(failure_periods, 0, fn {failure_time, recovery_time}, acc ->
          recovery_minutes = DateTime.diff(recovery_time, failure_time) / 60
          acc + recovery_minutes
        end)

      average_mttr = total_recovery_time / length(failure_periods)
      {:ok, average_mttr}
    end
  end

  @doc """
  Finds failure periods from uptime metrics.

  Returns list of {failure_datetime, recovery_datetime} tuples.
  """
  @spec find_failure_periods([map()]) :: [{DateTime.t(), DateTime.t()}]
  def find_failure_periods(uptimes) do
    uptimes
    |> Enum.reduce({[], nil}, fn
      %{value: value, inserted_at: failure_time}, {periods, nil}
      when value == 0.0 ->
        {periods, failure_time}

      %{value: value, inserted_at: recovery_time}, {periods, failure_time}
      when value == 100.0 and not is_nil(failure_time) ->
        {[{failure_time, recovery_time} | periods], nil}

      _metric, {periods, failure_time} ->
        {periods, failure_time}
    end)
    |> elem(0)
    |> Enum.reverse()
  end
end
