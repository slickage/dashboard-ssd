defmodule DashboardSSD.DeploymentsTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.{Deployments, Projects}
  alias DashboardSSD.Repo

  describe "run_health_check_now/1 branches" do
    test "returns :no_setting when none exists" do
      {:ok, p} = Projects.create_project(%{name: "HC None"})
      assert {:error, :no_setting} == Deployments.run_health_check_now(p.id)
      assert Deployments.list_health_checks_by_project(p.id) == []
    end

    test "returns :invalid_config for enabled custom provider" do
      {:ok, p} = Projects.create_project(%{name: "HC Invalid"})

      {:ok, _} =
        Deployments.upsert_health_check_setting(p.id, %{enabled: true, provider: "custom"})

      assert {:error, :invalid_config} == Deployments.run_health_check_now(p.id)
      assert Deployments.list_health_checks_by_project(p.id) == []
    end

    test "returns :aws_not_configured for aws_elbv2" do
      {:ok, p} = Projects.create_project(%{name: "HC AWS"})

      {:ok, _} =
        Deployments.upsert_health_check_setting(p.id, %{
          enabled: true,
          provider: "aws_elbv2",
          aws_region: "us-east-1",
          aws_target_group_arn: "arn:aws:elasticloadbalancing:region:acct:targetgroup/x/y"
        })

      assert {:error, :aws_not_configured} == Deployments.run_health_check_now(p.id)
      assert Deployments.list_health_checks_by_project(p.id) == []
    end

    test "inserts record and returns up for http in test env" do
      {:ok, p} = Projects.create_project(%{name: "HC HTTP"})

      {:ok, _} =
        Deployments.upsert_health_check_setting(p.id, %{
          enabled: true,
          provider: "http",
          endpoint_url: "https://example/health"
        })

      assert {:ok, "up"} == Deployments.run_health_check_now(p.id)

      # Enabled settings should be listed
      assert Enum.any?(Deployments.list_enabled_health_check_settings(), &(&1.project_id == p.id))

      # Latest status mapping includes this project
      m = Deployments.latest_health_status_by_project_ids([p.id])
      assert m[p.id] == "up"
    end

    test "latest_health_status_by_project_ids returns most recent status" do
      {:ok, p} = Projects.create_project(%{name: "HC Latest"})

      # Insert an older down record
      {:ok, hc_down} = Deployments.create_health_check(%{project_id: p.id, status: "down"})
      # Force the down record to be old
      old = DateTime.add(DateTime.utc_now(), -3600, :second)

      from(h in DashboardSSD.Deployments.HealthCheck, where: h.id == ^hc_down.id)
      |> Repo.update_all(set: [inserted_at: old])

      # Configure http and run now -> inserts a newer up record
      {:ok, _} =
        Deployments.upsert_health_check_setting(p.id, %{
          enabled: true,
          provider: "http",
          endpoint_url: "https://example/health"
        })

      {:ok, "up"} = Deployments.run_health_check_now(p.id)

      m = Deployments.latest_health_status_by_project_ids([p.id])
      assert m[p.id] == "up"
    end
  end
end
