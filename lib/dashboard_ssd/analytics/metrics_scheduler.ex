defmodule DashboardSSD.Analytics.MetricsScheduler do
  @moduledoc """
  Periodic scheduler for automated metrics collection.

  Runs metrics collection at configured intervals to populate
  the analytics dashboard with fresh data.
  """
  use GenServer
  require Logger

  alias DashboardSSD.Analytics.Collector

  # 5 minutes
  @default_interval 300_000
  @default_initial_delay 5_000

  @doc """
  Starts the metrics collection scheduler GenServer.
  """
  @spec start_link(GenServer.options()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    Logger.info("Starting analytics metrics scheduler")
    interval = interval_ms(opts)
    collector = Keyword.get(opts, :collector, Collector)
    schedule_collection(initial_delay_ms(opts))
    {:ok, %{interval: interval, task_ref: nil, collector: collector}}
  end

  @impl true
  def handle_info(:collect, %{task_ref: nil} = state) do
    ref =
      Task.Supervisor.async_nolink(DashboardSSD.TaskSupervisor, fn ->
        state.collector.collect_all_metrics()
      end).ref

    {:noreply, %{state | task_ref: ref}}
  end

  def handle_info(:collect, state), do: {:noreply, state}

  def handle_info(
        {:DOWN, ref, :process, _pid, _reason},
        %{task_ref: ref, interval: interval} = state
      ) do
    schedule_collection(interval)
    {:noreply, %{state | task_ref: nil}}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state), do: {:noreply, state}

  def handle_info({ref, _result}, %{task_ref: ref} = state), do: {:noreply, state}
  def handle_info({ref, _result}, state) when is_reference(ref), do: {:noreply, state}

  defp schedule_collection(ms) do
    Process.send_after(self(), :collect, ms)
  end

  defp initial_delay_ms(opts) do
    Keyword.get(opts, :initial_delay_ms) ||
      Application.get_env(:dashboard_ssd, :analytics, [])[:initial_delay_ms] ||
      @default_initial_delay
  end

  defp interval_ms(opts) do
    Keyword.get(opts, :interval_ms) ||
      Application.get_env(:dashboard_ssd, :analytics, [])[:collection_interval_ms] ||
      @default_interval
  end
end
