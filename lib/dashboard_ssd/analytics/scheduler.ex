defmodule DashboardSSD.Analytics.Scheduler do
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

  @doc """
  Starts the metrics collection scheduler GenServer.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting analytics metrics scheduler")
    # Run immediately on startup
    schedule_collection(0)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:collect, state) do
    Collector.collect_all_metrics()
    schedule_collection(interval_ms())
    {:noreply, state}
  end

  defp schedule_collection(ms) do
    Process.send_after(self(), :collect, ms)
  end

  defp interval_ms do
    Application.get_env(:dashboard_ssd, :analytics, [])[:collection_interval_ms] ||
      @default_interval
  end
end
