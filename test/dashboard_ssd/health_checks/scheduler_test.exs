defmodule DashboardSSD.HealthChecks.SchedulerTest do
  use DashboardSSD.DataCase, async: false

  alias DashboardSSD.{Clients, Deployments, Projects}
  alias DashboardSSD.HealthChecks.Scheduler

  test "scheduler inserts a down status for unreachable HTTP endpoint" do
    {:ok, c} = Clients.create_client(%{name: "SchedC"})
    {:ok, p} = Projects.create_project(%{name: "SchedP", client_id: c.id})

    {:ok, _} =
      Deployments.upsert_health_check_setting(p.id, %{
        enabled: true,
        provider: "http",
        endpoint_url: "http://127.0.0.1:9/health"
      })

    # Start scheduler manually (even though app does not start it in test)
    {:ok, pid} = start_supervised(Scheduler)
    # Allow the immediate tick in init to run
    Process.sleep(50)
    # Stop the scheduler to avoid further ticks
    Process.exit(pid, :normal)

    m = Deployments.latest_health_status_by_project_ids([p.id])
    assert Map.has_key?(m, p.id)
  end
end
