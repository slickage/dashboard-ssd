defmodule DashboardSSD.DeploymentsHealthChecksTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.{Clients, Deployments, Projects, Repo}
  alias DashboardSSD.Deployments.HealthCheckSetting
  import Ecto.Query

  describe "health checks" do
    setup do
      {:ok, client} = Clients.create_client(%{name: "Deployments Client"})

      {:ok, project} =
        Projects.create_project(%{name: "Deployments Project", client_id: client.id})

      {:ok, project: project}
    end

    test "run_health_check_now records an up status", %{project: project} do
      {:ok, _setting} =
        Deployments.upsert_health_check_setting(project.id, %{
          enabled: true,
          provider: "http",
          endpoint_url: "http://example.com/health"
        })

      assert {:ok, "up"} = Deployments.run_health_check_now(project.id)

      health_statuses = Deployments.list_health_checks_by_project(project.id)
      assert Enum.any?(health_statuses, &(&1.status == "up"))
    end

    test "list_enabled_health_check_settings only returns enabled settings", %{project: project} do
      {:ok, _} =
        Deployments.upsert_health_check_setting(project.id, %{
          enabled: true,
          provider: "http",
          endpoint_url: "http://enabled.example"
        })

      {:ok, disabled_project} =
        Projects.create_project(%{name: "Disabled", client_id: project.client_id})

      {:ok, _} =
        Deployments.upsert_health_check_setting(disabled_project.id, %{
          enabled: false,
          provider: "http",
          endpoint_url: "http://disabled.example"
        })

      enabled_ids =
        Deployments.list_enabled_health_check_settings()
        |> Enum.map(& &1.project_id)

      assert project.id in enabled_ids
      refute disabled_project.id in enabled_ids
    end

    test "latest_health_status_by_project_ids returns the newest record", %{project: project} do
      {:ok, first} = Deployments.create_health_check(%{project_id: project.id, status: "down"})
      {:ok, _second} = Deployments.create_health_check(%{project_id: project.id, status: "up"})

      {:ok, other_client} = Clients.create_client(%{name: "Second"})
      {:ok, other_project} = Projects.create_project(%{name: "Other", client_id: other_client.id})

      {:ok, _} =
        Deployments.create_health_check(%{project_id: other_project.id, status: "degraded"})

      # ensure the first record is older than the second to exercise ordering
      Repo.update_all(
        from(h in DashboardSSD.Deployments.HealthCheck, where: h.id == ^first.id),
        set: [inserted_at: DateTime.add(DateTime.utc_now(), -3600, :second)]
      )

      statuses = Deployments.latest_health_status_by_project_ids([project.id, other_project.id])

      assert statuses[project.id] == "up"
      assert statuses[other_project.id] == "degraded"
    end

    test "run_health_check_now handles missing settings", %{project: project} do
      assert {:error, :no_setting} = Deployments.run_health_check_now(project.id)
    end

    test "run_health_check_now handles aws provider", %{project: project} do
      {:ok, _} =
        Deployments.upsert_health_check_setting(project.id, %{
          enabled: true,
          provider: "aws_elbv2",
          aws_region: "us-east-1",
          aws_target_group_arn: "arn:aws:elasticloadbalancing:region:acct:targetgroup/name/123"
        })

      assert {:error, :aws_not_configured} = Deployments.run_health_check_now(project.id)
    end

    test "run_health_check_now returns invalid_config without endpoint", %{project: project} do
      {:ok, setting} =
        Deployments.upsert_health_check_setting(project.id, %{
          enabled: false,
          provider: "http"
        })

      Repo.update_all(
        from(s in HealthCheckSetting, where: s.id == ^setting.id),
        set: [enabled: true, endpoint_url: nil]
      )

      assert {:error, :invalid_config} = Deployments.run_health_check_now(project.id)
    end

    test "upsert_health_check_setting creates and updates records", %{project: project} do
      {:ok, setting} =
        Deployments.upsert_health_check_setting(project.id, %{
          enabled: true,
          provider: "http",
          endpoint_url: "http://initial.example"
        })

      assert setting.endpoint_url == "http://initial.example"

      {:ok, updated} =
        Deployments.upsert_health_check_setting(project.id, %{
          enabled: false,
          provider: "http",
          endpoint_url: "http://updated.example"
        })

      assert %HealthCheckSetting{enabled: false, endpoint_url: "http://updated.example"} = updated
    end
  end
end
