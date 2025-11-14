defmodule DashboardSSDWeb.Telemetry do
  @moduledoc """
  Telemetry supervisor and metrics setup for Phoenix and Ecto.

    - Boots a telemetry poller for periodic measurements (VM + DB).
  - Defines metric summaries used by dashboards and exporters.
  - Provides extension points for reporters (Console, StatsD, etc.).
  """
  use Supervisor
  import Telemetry.Metrics
  alias Telemetry.Metrics

  @doc """
  Starts the telemetry supervisor.
  """
  @spec start_link(term()) :: Supervisor.on_start()
  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  @spec init(term()) :: {:ok, {Supervisor.sup_flags(), [Supervisor.child_spec()]}}
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Returns the list of telemetry metrics to be collected.
  """
  @spec metrics() :: [Metrics.t()]
  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      summary("dashboard_ssd.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),
      summary("dashboard_ssd.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database"
      ),
      summary("dashboard_ssd.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),
      summary("dashboard_ssd.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection"
      ),
      summary("dashboard_ssd.repo.query.idle_time",
        unit: {:native, :millisecond},
        description:
          "The time the connection spent waiting before being checked out for the query"
      ),
      summary("dashboard_ssd.knowledge_base.notion.request.stop.duration",
        tags: [:operation, :method, :http_status],
        unit: {:native, :millisecond},
        description: "Duration of Notion API requests triggered by the Knowledge Base context"
      ),
      summary("dashboard_ssd.documents.drive_sync.duration",
        event_name: [:dashboard_ssd, :documents, :drive_sync, :result],
        measurement: :duration,
        tags: [:status],
        unit: {:native, :millisecond},
        description: "Duration of Drive sync batches"
      ),
      summary("dashboard_ssd.documents.drive_sync.stale_pct",
        event_name: [:dashboard_ssd, :documents, :drive_sync, :result],
        measurement: :stale_pct,
        tags: [:status],
        description: "Percentage of stale Drive entries detected during sync"
      ),
      last_value("dashboard_ssd.documents.drive_sync.stale_pct",
        event_name: [:dashboard_ssd, :documents, :drive_sync, :result],
        measurement: :stale_pct,
        tags: [:status],
        description: "Latest Drive stale percentage for alerting"
      ),
      summary("dashboard_ssd.documents.notion_sync.duration",
        event_name: [:dashboard_ssd, :documents, :notion_sync, :result],
        measurement: :duration,
        tags: [:status],
        unit: {:native, :millisecond},
        description: "Duration of Notion sync batches"
      ),
      summary("dashboard_ssd.documents.notion_sync.stale_pct",
        event_name: [:dashboard_ssd, :documents, :notion_sync, :result],
        measurement: :stale_pct,
        tags: [:status],
        description: "Percentage of stale Notion entries detected during sync"
      ),
      last_value("dashboard_ssd.documents.notion_sync.stale_pct",
        event_name: [:dashboard_ssd, :documents, :notion_sync, :result],
        measurement: :stale_pct,
        tags: [:status],
        description: "Latest Notion stale percentage for alerting"
      ),
      summary("dashboard_ssd.documents.download.duration",
        event_name: [:dashboard_ssd, :documents, :download],
        measurement: :duration,
        tags: [:status, :source],
        unit: {:native, :millisecond},
        description: "Latency for client downloads served via the proxy"
      ),
      summary("dashboard_ssd.documents.visibility_toggle.duration",
        event_name: [:dashboard_ssd, :documents, :visibility_toggle],
        measurement: :duration,
        tags: [:status, :visibility],
        unit: {:native, :millisecond},
        description: "Time to apply staff visibility/edit toggles"
      ),
      summary("dashboard_ssd.drive_acl.sync.duration",
        event_name: [:dashboard_ssd, :drive_acl, :sync],
        measurement: :duration,
        tags: [:operation, :status],
        unit: {:native, :millisecond},
        description: "Duration of Drive permission share/unshare operations"
      ),
      counter("dashboard_ssd.drive_acl.sync.failures",
        event_name: [:dashboard_ssd, :drive_acl, :sync],
        measurement: :failure,
        tags: [:operation],
        description: "Count of Drive ACL operations that returned errors"
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {DashboardSSDWeb, :count_users, []}
    ]
  end
end
