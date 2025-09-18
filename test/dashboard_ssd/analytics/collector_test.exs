defmodule DashboardSSD.Analytics.CollectorTest do
  use DashboardSSD.DataCase, async: false

  alias DashboardSSD.{Analytics, Clients, Deployments, Projects}
  alias DashboardSSD.Analytics.Collector

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
      # 2 response_time + 2 uptime per project
      assert length(metrics) >= 4

      # Check that we have metrics for both projects
      project_ids = Enum.map(metrics, & &1.project_id) |> Enum.uniq()
      assert project1.id in project_ids
      assert project2.id in project_ids
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
      assert length(metrics) == 2

      # Should have both response_time and uptime metrics
      types = Enum.map(metrics, & &1.type)
      assert "response_time" in types
      assert "uptime" in types

      # All metrics should be for the correct project
      assert Enum.all?(metrics, &(&1.project_id == project.id))

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
