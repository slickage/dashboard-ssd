defmodule DashboardSSD.HealthChecks.Scheduler do
  @moduledoc """
  Periodically evaluates production health checks for enabled projects and
  records status changes. Interval configured via `:dashboard_ssd, :health_checks`.
  """
  use GenServer
  require Logger

  alias DashboardSSD.Deployments

  @default_interval 60_000

  @doc """
  Starts the health check scheduler GenServer.

  ## Parameters
    - opts: Options passed to GenServer.start_link/3
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  @doc """
  Initializes the scheduler and schedules the first health check tick.
  """
  def init(_opts) do
    schedule_tick(0)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:tick, state) do
    run_checks()
    schedule_tick(interval_ms())
    {:noreply, state}
  end

  defp schedule_tick(ms) do
    Process.send_after(self(), :tick, ms)
  end

  defp interval_ms do
    Application.get_env(:dashboard_ssd, :health_checks, [])[:interval_ms] || @default_interval
  end

  defp run_checks do
    for s <- Deployments.list_enabled_health_check_settings() do
      case perform_check(s) do
        {:ok, status} ->
          maybe_record_status(s.project_id, status)

        {:error, reason} ->
          Logger.debug("health check skipped for project #{s.project_id}: #{inspect(reason)}")
      end
    end
  rescue
    e -> Logger.error("health check scheduler error: #{inspect(e)}")
  end

  defp perform_check(%{provider: "http", endpoint_url: url}) when is_binary(url) and url != "" do
    req = Finch.build(:get, url)

    case Finch.request(req, DashboardSSD.Finch) do
      {:ok, %Finch.Response{status: 200}} -> {:ok, "up"}
      {:ok, %Finch.Response{status: status}} when status in 500..599 -> {:ok, "down"}
      {:ok, %Finch.Response{status: status}} when status in 400..499 -> {:ok, "degraded"}
      {:ok, _} -> {:ok, "degraded"}
      {:error, _} -> {:ok, "down"}
    end
  rescue
    _ -> {:ok, "down"}
  end

  defp perform_check(%{provider: "aws_elbv2"} = _s) do
    # AWS ELBv2 target health integration can be added via ExAws.
    # For now, skip with a descriptive reason.
    {:error, :aws_not_configured}
  end

  defp perform_check(_), do: {:error, :invalid_config}

  defp maybe_record_status(project_id, new_status) do
    prev = Deployments.latest_health_status_by_project_ids([project_id]) |> Map.get(project_id)

    if prev != new_status do
      _ = Deployments.create_health_check(%{project_id: project_id, status: new_status})
    else
      :ok
    end
  end
end
