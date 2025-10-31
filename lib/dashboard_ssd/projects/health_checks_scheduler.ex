defmodule DashboardSSD.Projects.HealthChecksScheduler do
  @moduledoc """
  Periodically evaluates production health checks for enabled projects and
  records status changes. Interval configured via `:dashboard_ssd, :health_checks`.
  """
  use GenServer
  require Logger

  alias DashboardSSD.Deployments
  alias Ecto.Adapters.SQL.Sandbox

  @default_interval 60_000
  @default_initial_delay 5_000
  @default_concurrency 2
  @default_task_timeout 15_000

  @doc """
  Starts the health check scheduler GenServer.

  ## Parameters
    - opts: Options passed to GenServer.start_link/3
  """
  @spec start_link(GenServer.options()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  @doc """
  Initializes the scheduler and schedules the first health check tick.
  """
  @spec init(term()) :: {:ok, map()}
  def init(opts) do
    interval = interval_ms(opts)
    schedule_tick(initial_delay_ms(opts))
    {:ok, %{interval: interval, task_ref: nil}}
  end

  @impl true
  @spec handle_info(:tick, map()) :: {:noreply, map()}
  def handle_info(:tick, %{task_ref: nil} = state) do
    task =
      Task.Supervisor.async_nolink(DashboardSSD.TaskSupervisor, fn ->
        run_checks()
      end)

    maybe_allow_sandbox(self(), task.pid)

    {:noreply, %{state | task_ref: task.ref}}
  end

  def handle_info(:tick, state), do: {:noreply, state}

  @impl true
  def handle_info(
        {:DOWN, ref, :process, _pid, _reason},
        %{task_ref: ref, interval: interval} = state
      ) do
    schedule_tick(interval)
    {:noreply, %{state | task_ref: nil}}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state), do: {:noreply, state}

  def handle_info({ref, _result}, %{task_ref: ref} = state), do: {:noreply, state}
  def handle_info({ref, _result}, state) when is_reference(ref), do: {:noreply, state}

  defp schedule_tick(ms) do
    Process.send_after(self(), :tick, ms)
  end

  defp initial_delay_ms(opts) do
    Keyword.get(opts, :initial_delay_ms) ||
      Application.get_env(:dashboard_ssd, :health_checks, [])[:initial_delay_ms] ||
      @default_initial_delay
  end

  defp interval_ms(opts) do
    Keyword.get(opts, :interval_ms) ||
      Application.get_env(:dashboard_ssd, :health_checks, [])[:interval_ms] ||
      @default_interval
  end

  defp run_checks do
    settings = Deployments.list_enabled_health_check_settings()

    Task.Supervisor.async_stream_nolink(
      DashboardSSD.TaskSupervisor,
      settings,
      &process_setting/1,
      ordered: false,
      max_concurrency: max_concurrency(),
      timeout: task_timeout(),
      on_timeout: :kill_task
    )
    |> Stream.run()
  rescue
    e -> Logger.error("health check scheduler error: #{inspect(e)}")
  end

  defp process_setting(setting) do
    maybe_allow_sandbox(self(), self())

    case perform_check(setting) do
      {:ok, status} ->
        maybe_record_status(setting.project_id, status)

      {:error, reason} ->
        Logger.debug("health check skipped for project #{setting.project_id}: #{inspect(reason)}")
    end
  end

  defp perform_check(%{provider: "http", endpoint_url: url}) when is_binary(url) and url != "" do
    req = Finch.build(:get, url)

    case Finch.request(req, DashboardSSD.Finch) do
      {:ok, %Finch.Response{status: status}} when status in 200..299 -> {:ok, "up"}
      {:ok, %Finch.Response{status: status}} when status in 300..399 -> {:ok, "up"}
      {:ok, %Finch.Response{status: status}} when status in 400..499 -> {:ok, "degraded"}
      {:ok, %Finch.Response{status: status}} when status in 500..599 -> {:ok, "down"}
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

  defp max_concurrency do
    Application.get_env(:dashboard_ssd, :health_checks, [])[:max_concurrency] ||
      @default_concurrency
  end

  defp task_timeout do
    Application.get_env(:dashboard_ssd, :health_checks, [])[:task_timeout_ms] ||
      @default_task_timeout
  end

  defp maybe_allow_sandbox(parent, child) do
    if sandbox_repo?() do
      Sandbox.allow(DashboardSSD.Repo, parent, child)
    end
  end

  defp sandbox_repo? do
    config = Application.get_env(:dashboard_ssd, DashboardSSD.Repo, [])
    Keyword.get(config, :pool) == Sandbox
  end
end
