defmodule DashboardSSD.Analytics.CollectorTest do
  use DashboardSSD.DataCase, async: true

  import ExUnit.CaptureLog

  alias DashboardSSD.Analytics.Collector
  alias DashboardSSD.Analytics.MetricSnapshot
  alias DashboardSSD.Clients
  alias DashboardSSD.Projects
  alias DashboardSSD.Repo

  describe "calculate_mttr_from_uptimes/1" do
    test "returns :no_failures when no downtime metrics present" do
      uptimes = [
        %{inserted_at: ~U[2024-05-01 10:00:00Z], value: 100},
        %{inserted_at: ~U[2024-05-01 11:00:00Z], value: 100}
      ]

      assert :no_failures = Collector.calculate_mttr_from_uptimes(uptimes)
    end

    test "calculates average minutes between failures and recoveries" do
      uptimes = [
        %{inserted_at: ~U[2024-05-01 10:00:00Z], value: 100},
        %{inserted_at: ~U[2024-05-01 10:15:00Z], value: 0},
        %{inserted_at: ~U[2024-05-01 10:45:00Z], value: 100},
        %{inserted_at: ~U[2024-05-01 11:00:00Z], value: 0},
        %{inserted_at: ~U[2024-05-01 11:20:00Z], value: 100}
      ]

      assert {:ok, mttr} = Collector.calculate_mttr_from_uptimes(uptimes)
      assert mttr == 25.0
    end

    test "returns no failures when uptimes list is empty" do
      assert :no_failures = Collector.calculate_mttr_from_uptimes([])
    end

    test "handles single failure without recovery" do
      uptimes = [
        %{inserted_at: ~U[2024-05-01 10:00:00Z], value: 100},
        %{inserted_at: ~U[2024-05-01 10:15:00Z], value: 0}
      ]

      assert :no_failures = Collector.calculate_mttr_from_uptimes(uptimes)
    end

    test "calculates mttr with multiple failures and recoveries" do
      uptimes = [
        %{inserted_at: ~U[2024-05-01 10:00:00Z], value: 100},
        %{inserted_at: ~U[2024-05-01 10:10:00Z], value: 0},
        %{inserted_at: ~U[2024-05-01 10:20:00Z], value: 100},
        %{inserted_at: ~U[2024-05-01 10:30:00Z], value: 0},
        %{inserted_at: ~U[2024-05-01 10:50:00Z], value: 100}
      ]

      assert {:ok, mttr} = Collector.calculate_mttr_from_uptimes(uptimes)
      assert mttr == 15.0
    end
  end

  describe "collect_response_time/1" do
    test "returns error tuple when request fails" do
      assert {:error, _reason} = Collector.collect_response_time("http://127.0.0.1:9")
    end

    test "rescues unexpected errors and logs message" do
      log =
        capture_log(fn ->
          assert {:error, %ArgumentError{}} = Collector.collect_response_time("not a url")
        end)

      assert log =~ "Error collecting response time for not a url"
    end

    test "returns response time for successful requests" do
      Tesla.Mock.mock(fn
        %{method: :get, url: "http://example.com/"} ->
          %Tesla.Env{status: 200, body: "OK"}
      end)

      url = "http://example.com/"
      assert {:ok, response_time} = Collector.collect_response_time(url)
      assert is_float(response_time)
      assert response_time >= 0
    end
  end

  describe "collect_mttr/1" do
    test "persists mttr metric when failures present" do
      project_id = project_id()
      now = DateTime.utc_now() |> DateTime.add(-1, :hour) |> DateTime.truncate(:second)
      later = DateTime.add(now, 20 * 60, :second)

      Repo.insert!(%MetricSnapshot{
        project_id: project_id,
        type: "uptime",
        value: 0.0,
        inserted_at: now
      })

      Repo.insert!(%MetricSnapshot{
        project_id: project_id,
        type: "uptime",
        value: 100.0,
        inserted_at: later
      })

      log =
        capture_log(fn ->
          assert :ok == Collector.collect_mttr(project_id)
        end)

      assert log =~ "Collected MTTR for project #{project_id}"
    end

    test "logs when no failures are present" do
      project_id = project_id()
      now = DateTime.utc_now() |> DateTime.add(-1, :hour) |> DateTime.truncate(:second)

      Repo.insert!(%MetricSnapshot{
        project_id: project_id,
        type: "uptime",
        value: 100.0,
        inserted_at: now
      })

      log =
        capture_log(fn ->
          assert :ok == Collector.collect_mttr(project_id)
        end)

      assert log =~ "No failures found for MTTR calculation in project #{project_id}"
    end
  end

  describe "collect_project_metrics/1" do
    test "logs debug for unsupported provider" do
      project_id = project_id()

      setting = %DashboardSSD.Deployments.HealthCheckSetting{
        project_id: project_id,
        provider: "custom"
      }

      log =
        capture_log([level: :debug], fn ->
          assert :ok == Collector.collect_project_metrics(setting)
        end)

      assert log =~
               "Custom health check metrics collection not yet implemented for project #{project_id}"
    end

    test "handles unknown providers" do
      setting = %DashboardSSD.Deployments.HealthCheckSetting{
        project_id: project_id(),
        provider: "unknown"
      }

      log =
        capture_log([level: :debug], fn ->
          assert :ok == Collector.collect_project_metrics(setting)
        end)

      assert log =~ "Unknown health check provider: unknown"
    end

    test "logs debug for aws_elbv2 provider" do
      setting = %DashboardSSD.Deployments.HealthCheckSetting{
        project_id: project_id(),
        provider: "aws_elbv2"
      }

      assert :ok == Collector.collect_project_metrics(setting)
    end

    test "collects http metrics for http provider" do
      project_id = project_id()

      Tesla.Mock.mock(fn
        %{method: :get, url: "http://example.com/"} ->
          %Tesla.Env{status: 200, body: "OK"}
      end)

      setting = %DashboardSSD.Deployments.HealthCheckSetting{
        project_id: project_id,
        provider: "http",
        endpoint_url: "http://example.com/"
      }

      assert :ok == Collector.collect_project_metrics(setting)

      # Check that metrics were created
      response_time_metric =
        Repo.get_by(MetricSnapshot, project_id: project_id, type: "response_time")

      uptime_metric = Repo.get_by(MetricSnapshot, project_id: project_id, type: "uptime")

      assert response_time_metric
      assert response_time_metric.value >= 0
      assert uptime_metric
      assert uptime_metric.value == 100.0
    end

    test "records downtime when http request fails" do
      project_id = project_id()

      setting = %DashboardSSD.Deployments.HealthCheckSetting{
        project_id: project_id,
        provider: "http",
        endpoint_url: "http://127.0.0.1:9/"
      }

      assert :ok == Collector.collect_project_metrics(setting)

      # Check that only uptime metric was created with 0.0
      uptime_metric = Repo.get_by(MetricSnapshot, project_id: project_id, type: "uptime")

      response_time_metric =
        Repo.get_by(MetricSnapshot, project_id: project_id, type: "response_time")

      assert uptime_metric
      assert uptime_metric.value == 0.0
      refute response_time_metric
    end
  end

  describe "collect_linear_throughput/1" do
    test "returns :ok and logs placeholder message" do
      assert :ok == Collector.collect_linear_throughput(123)
    end
  end

  describe "collect_all_metrics/0" do
    test "handles empty health check settings" do
      assert :ok == Collector.collect_all_metrics()
    end
  end

  describe "find_failure_periods/1" do
    test "returns failure periods in chronological order" do
      now = DateTime.utc_now()

      periods =
        Collector.find_failure_periods([
          %{value: 0.0, inserted_at: now},
          %{value: 100.0, inserted_at: DateTime.add(now, 600, :second)}
        ])

      assert [{^now, _}] = periods
    end

    test "returns empty list when no failures" do
      periods =
        Collector.find_failure_periods([
          %{value: 100.0, inserted_at: DateTime.utc_now()}
        ])

      assert periods == []
    end

    test "handles multiple failure periods" do
      now = DateTime.utc_now()

      periods =
        Collector.find_failure_periods([
          %{value: 100.0, inserted_at: now},
          %{value: 0.0, inserted_at: DateTime.add(now, 60, :second)},
          %{value: 100.0, inserted_at: DateTime.add(now, 120, :second)},
          %{value: 0.0, inserted_at: DateTime.add(now, 180, :second)},
          %{value: 100.0, inserted_at: DateTime.add(now, 240, :second)}
        ])

      assert length(periods) == 2
    end
  end

  defp project_id do
    unique = System.unique_integer([:positive])
    {:ok, client} = Clients.create_client(%{name: "Analytics Client #{unique}"})

    {:ok, project} =
      Projects.create_project(%{name: "Metrics Project #{unique}", client_id: client.id})

    project.id
  end
end
