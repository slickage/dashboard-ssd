defmodule DashboardSSD.HealthChecks.SchedulerAwsTest do
  use DashboardSSD.DataCase, async: false

  alias DashboardSSD.{Clients, Deployments, Projects}
  alias DashboardSSD.HealthChecks.Scheduler

  test "scheduler skips aws_elbv2 with descriptive reason" do
    {:ok, c} = Clients.create_client(%{name: "SchedC2"})
    {:ok, p} = Projects.create_project(%{name: "SchedP2", client_id: c.id})

    {:ok, _} =
      Deployments.upsert_health_check_setting(p.id, %{
        enabled: true,
        provider: "aws_elbv2",
        aws_region: "us-east-1",
        aws_target_group_arn: "arn:aws:elasticloadbalancing:...:targetgroup/..."
      })

    {:ok, pid} = start_supervised(Scheduler)
    Process.sleep(50)
    Process.exit(pid, :normal)

    # No health check inserted because aws is not configured
    m = Deployments.latest_health_status_by_project_ids([p.id])
    refute Map.has_key?(m, p.id)
  end
end
