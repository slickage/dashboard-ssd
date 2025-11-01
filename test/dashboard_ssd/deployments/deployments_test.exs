defmodule DashboardSSD.DeploymentsTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Clients
  alias DashboardSSD.Deployments
  alias DashboardSSD.Deployments.{HealthCheck, HealthCheckSetting}
  alias DashboardSSD.Projects
  alias DashboardSSD.Repo

  setup do
    {:ok, client} = Clients.create_client(%{name: "C"})
    {:ok, project} = Projects.create_project(%{name: "P", client_id: client.id})
    %{project: project}
  end

  describe "deployments" do
    test "create/list/get/update/delete & by-project", %{project: project} do
      # validations
      assert {:error, cs} = Deployments.create_deployment(%{})
      assert %{project_id: ["can't be blank"], status: ["can't be blank"]} = errors_on(cs)

      {:ok, dep} =
        Deployments.create_deployment(%{project_id: project.id, status: "ok", commit_sha: "abc"})

      assert Enum.any?(Deployments.list_deployments(), &(&1.id == dep.id))
      assert Deployments.get_deployment!(dep.id).status == "ok"

      {:ok, dep} = Deployments.update_deployment(dep, %{status: "bad"})
      assert dep.status == "bad"
      assert {:error, cs} = Deployments.update_deployment(dep, %{status: nil})
      assert %{status: ["can't be blank"]} = errors_on(cs)

      ids = Deployments.list_deployments_by_project(project.id) |> Enum.map(& &1.id)
      assert ids == [dep.id]

      assert {:ok, _} = Deployments.delete_deployment(dep)
    end
  end

  describe "health checks" do
    test "create/list/get/update/delete & by-project", %{project: project} do
      assert {:error, cs} = Deployments.create_health_check(%{})
      assert %{project_id: ["can't be blank"], status: ["can't be blank"]} = errors_on(cs)

      {:ok, hc} = Deployments.create_health_check(%{project_id: project.id, status: "passing"})
      assert Enum.any?(Deployments.list_health_checks(), &(&1.id == hc.id))
      assert Deployments.get_health_check!(hc.id).status == "passing"

      {:ok, hc} = Deployments.update_health_check(hc, %{status: "failing"})
      assert hc.status == "failing"
      assert {:error, cs} = Deployments.update_health_check(hc, %{status: nil})
      assert %{status: ["can't be blank"]} = errors_on(cs)

      ids = Deployments.list_health_checks_by_project(project.id) |> Enum.map(& &1.id)
      assert ids == [hc.id]

      assert {:ok, _} = Deployments.delete_health_check(hc)
    end
  end

  describe "health check utilities" do
    test "latest_health_status_by_project_ids returns most recent status", %{project: project} do
      older = DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.truncate(:second)
      newer = DateTime.utc_now() |> DateTime.truncate(:second)

      Repo.insert!(%HealthCheck{
        project_id: project.id,
        status: "degraded",
        inserted_at: older,
        updated_at: older
      })

      Repo.insert!(%HealthCheck{
        project_id: project.id,
        status: "up",
        inserted_at: newer,
        updated_at: newer
      })

      assert Deployments.latest_health_status_by_project_ids([project.id, 999]) == %{
               project.id => "up"
             }
    end

    test "run_health_check_now executes http checks", %{project: project} do
      {:ok, _} =
        Deployments.upsert_health_check_setting(project.id, %{
          provider: "http",
          endpoint_url: "https://example.com/status",
          enabled: true
        })

      assert {:ok, "up"} = Deployments.run_health_check_now(project.id)

      assert [%HealthCheck{status: "up"}] = Repo.all(HealthCheck)
    end

    test "run_health_check_now handles aws_elbv2 configuration", %{project: project} do
      {:ok, _} =
        Deployments.upsert_health_check_setting(project.id, %{
          provider: "aws_elbv2",
          aws_region: "us-east-1",
          aws_target_group_arn: "arn:aws:elasticloadbalancing:demo",
          enabled: true
        })

      assert {:error, :aws_not_configured} = Deployments.run_health_check_now(project.id)
    end

    test "upsert_health_check_setting inserts and updates settings", %{project: project} do
      assert {:ok, %HealthCheckSetting{provider: "custom"}} =
               Deployments.upsert_health_check_setting(project.id, %{
                 provider: "custom",
                 enabled: false
               })

      assert {:ok, %HealthCheckSetting{provider: "http", endpoint_url: "https://status"}} =
               Deployments.upsert_health_check_setting(project.id, %{
                 provider: "http",
                 endpoint_url: "https://status",
                 enabled: true
               })
    end

    test "list health check settings and enabled subset", %{project: project} do
      {:ok, setting} =
        Deployments.create_health_check_setting(%{
          project_id: project.id,
          provider: "http",
          endpoint_url: "https://status",
          enabled: true
        })

      assert Enum.map(Deployments.list_health_check_settings(), & &1.id) == [setting.id]
      assert Enum.map(Deployments.list_enabled_health_check_settings(), & &1.id) == [setting.id]
    end

    test "run_health_check_now returns clear errors when misconfigured", %{project: project} do
      assert {:error, :no_setting} = Deployments.run_health_check_now(project.id)

      {:ok, _} =
        Deployments.upsert_health_check_setting(project.id, %{
          provider: "custom",
          enabled: true
        })

      assert {:error, :invalid_config} = Deployments.run_health_check_now(project.id)
    end
  end
end
