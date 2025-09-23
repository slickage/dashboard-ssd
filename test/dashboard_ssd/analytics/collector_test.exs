defmodule DashboardSSD.Analytics.CollectorTest do
  use DashboardSSD.DataCase, async: false

  import Ecto.Query

  alias DashboardSSD.{Analytics, Clients, Deployments, Projects, Repo}
  alias DashboardSSD.Analytics.{Collector, MetricSnapshot}

  describe "collect_all_metrics/0" do
    test "collects metrics for all projects with health check settings" do
      # Create test data
      {:ok, client} = Clients.create_client(%{name: "Test Client"})
      {:ok, project1} = Projects.create_project(%{name: "Project 1", client_id: client.id})
      {:ok, project2} = Projects.create_project(%{name: "Project 2", client_id: client.id})

      # Set up health check settings
      {:ok, _} =
        Deployments.upsert_health_check_setting(project1.id, %{
          enabled: true,
          provider: "http",
          endpoint_url: "http://httpbin.org/status/200"
        })

      {:ok, _} =
        Deployments.upsert_health_check_setting(project2.id, %{
          enabled: true,
          provider: "http",
          endpoint_url: "http://httpbin.org/status/200"
        })

      # Run collection
      Collector.collect_all_metrics()

      # Check that metrics were collected
      metrics = Analytics.list_metrics()

      # Check that we have metrics for both projects
      project1_metrics = Enum.filter(metrics, &(&1.project_id == project1.id))
      project2_metrics = Enum.filter(metrics, &(&1.project_id == project2.id))

      # Each project should have at least response_time and uptime metrics
      assert length(project1_metrics) >= 2
      assert length(project2_metrics) >= 2

      # Check metric types
      project1_types = Enum.map(project1_metrics, & &1.type) |> Enum.uniq()
      project2_types = Enum.map(project2_metrics, & &1.type) |> Enum.uniq()

      assert "response_time" in project1_types
      assert "uptime" in project1_types
      assert "response_time" in project2_types
      assert "uptime" in project2_types
    end
  end

  describe "collect_project_metrics/1" do
    test "handles provider that is not yet implemented" do
      setting = struct(Deployments.HealthCheckSetting, %{project_id: 1, provider: "aws_elbv2"})

      assert :ok = Collector.collect_project_metrics(setting)
    end

    test "warns for unknown provider" do
      setting = %{project_id: 1, provider: "custom"}

      assert :ok = Collector.collect_project_metrics(setting)
    end
  end

  describe "collect_linear_throughput/1" do
    test "returns :ok and logs placeholder message" do
      assert :ok = Collector.collect_linear_throughput(42)
    end
  end

  describe "MTTR helpers" do
    test "calculate_mttr_from_uptimes returns :no_failures when no downtime" do
      uptimes = [%{value: 100.0, inserted_at: DateTime.utc_now()}]

      assert :no_failures = Collector.calculate_mttr_from_uptimes(uptimes)
    end

    test "calculate_mttr_from_uptimes averages recovery periods" do
      now = DateTime.utc_now()
      failure_a = DateTime.add(now, -3_600, :second)
      recovery_a = DateTime.add(failure_a, 600, :second)
      failure_b = DateTime.add(now, -1_800, :second)
      recovery_b = DateTime.add(failure_b, 300, :second)

      uptimes = [
        %{value: 0.0, inserted_at: failure_a},
        %{value: 100.0, inserted_at: recovery_a},
        %{value: 0.0, inserted_at: failure_b},
        %{value: 100.0, inserted_at: recovery_b}
      ]

      assert {:ok, mttr} = Collector.calculate_mttr_from_uptimes(uptimes)
      assert Float.round(mttr, 1) == 7.5
    end

    test "find_failure_periods pairs failures with recoveries" do
      now = DateTime.utc_now()
      failure = DateTime.add(now, -600, :second)
      recovery = DateTime.add(failure, 120, :second)

      uptimes = [
        %{value: 0.0, inserted_at: failure},
        %{value: 100.0, inserted_at: recovery}
      ]

      assert [{^failure, ^recovery}] = Collector.find_failure_periods(uptimes)
    end

    test "collect_mttr persists mttr metric when failure periods exist" do
      {:ok, client} = Clients.create_client(%{name: "MTTR Corp"})
      {:ok, project} = Projects.create_project(%{name: "MTTR", client_id: client.id})

      {:ok, failure_metric} =
        Analytics.create_metric(%{project_id: project.id, type: "uptime", value: 0.0})

      {:ok, recovery_metric} =
        Analytics.create_metric(%{project_id: project.id, type: "uptime", value: 100.0})

      failure_time = DateTime.add(DateTime.utc_now(), -600, :second)
      recovery_time = DateTime.add(DateTime.utc_now(), -300, :second)

      Repo.update_all(from(m in MetricSnapshot, where: m.id == ^failure_metric.id),
        set: [inserted_at: failure_time]
      )

      Repo.update_all(from(m in MetricSnapshot, where: m.id == ^recovery_metric.id),
        set: [inserted_at: recovery_time]
      )

      assert :ok = Collector.collect_mttr(project.id)

      mttr_values =
        Analytics.list_metrics(project.id)
        |> Enum.filter(&(&1.type == "mttr"))
        |> Enum.map(& &1.value)

      assert Enum.any?(mttr_values, fn value -> Float.round(value, 1) == 5.0 end)
    end
  end

  describe "collect_response_time/1" do
    test "successfully measures response time for valid HTTP endpoint" do
      url = "http://httpbin.org/status/200"

      assert {:ok, response_time} = Collector.collect_response_time(url)
      assert is_float(response_time)
      assert response_time > 0
    end

    test "returns error for invalid URL" do
      url = "http://invalid-domain-that-does-not-exist.com"

      assert {:error, _reason} = Collector.collect_response_time(url)
    end

    test "returns error for unreachable endpoint" do
      url = "http://127.0.0.1:9999/unreachable"

      assert {:error, _reason} = Collector.collect_response_time(url)
    end
  end

  describe "collect_http_metrics/2" do
    test "collects response time and uptime metrics for successful HTTP request" do
      {:ok, client} = Clients.create_client(%{name: "Test Client"})
      {:ok, project} = Projects.create_project(%{name: "Test Project", client_id: client.id})

      setting = %Deployments.HealthCheckSetting{
        project_id: project.id,
        provider: "http",
        endpoint_url: "http://httpbin.org/status/200"
      }

      # Run collection
      Collector.collect_http_metrics(project.id, setting)

      # Check metrics were created
      metrics = Analytics.list_metrics()

      # Should have both response_time and uptime metrics for the project
      project_metrics = Enum.filter(metrics, &(&1.project_id == project.id))
      assert length(project_metrics) == 2

      types = Enum.map(project_metrics, & &1.type)
      assert "response_time" in types
      assert "uptime" in types

      # Uptime should be 100%
      uptime_metric = Enum.find(metrics, &(&1.type == "uptime"))
      assert uptime_metric.value == 100.0
    end

    test "records downtime for failed HTTP requests" do
      {:ok, client} = Clients.create_client(%{name: "Test Client"})
      {:ok, project} = Projects.create_project(%{name: "Test Project", client_id: client.id})

      setting = %Deployments.HealthCheckSetting{
        project_id: project.id,
        provider: "http",
        endpoint_url: "http://127.0.0.1:9999/unreachable"
      }

      # Run collection
      Collector.collect_http_metrics(project.id, setting)

      # Check metrics were created
      metrics = Analytics.list_metrics()
      assert length(metrics) == 1

      # Should only have uptime metric (0% for failure)
      metric = hd(metrics)
      assert metric.type == "uptime"
      assert metric.value == 0.0
      assert metric.project_id == project.id
    end
  end
end
