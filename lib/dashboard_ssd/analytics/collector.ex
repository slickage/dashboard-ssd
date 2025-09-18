defmodule DashboardSSD.Analytics.Collector do
  @moduledoc """
  Automated metrics collection system.

  Collects various system metrics automatically:
  - Uptime from health checks
  - Response times for configured endpoints
  - Error rates and other performance indicators
  """

  require Logger
  alias DashboardSSD.{Analytics, Deployments}

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

      "aws_elbv2" ->
        Logger.debug("AWS ELBv2 metrics collection not yet implemented for project #{project_id}")

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

    case Finch.build(:get, url) |> Finch.request(DashboardSSD.Finch) do
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
    # TODO: Implement Linear throughput collection
    # This would:
    # 1. Query Linear API for issues in the project
    # 2. Count completed issues in the last period
    # 3. Calculate throughput rate

    Logger.debug("Linear throughput collection not yet implemented for project #{project_id}")
  end

  @doc """
  Collects MTTR (Mean Time To Recovery) metrics.

  This would analyze health check status changes to calculate
  average time between failures and recoveries.
  """
  @spec collect_mttr(integer()) :: :ok
  def collect_mttr(project_id) do
    # TODO: Implement MTTR collection
    # This would:
    # 1. Analyze health check history
    # 2. Find failure periods
    # 3. Calculate average recovery time

    Logger.debug("MTTR collection not yet implemented for project #{project_id}")
  end
end
