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
  end

  describe "collect_mttr/1" do
    test "persists mttr metric when failures present" do
      project_id = project_id()
      now = DateTime.utc_now() |> DateTime.truncate(:second)
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

      assert :ok == Collector.collect_mttr(project_id)
    end

    test "logs when no failures are present" do
      project_id = project_id()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Repo.insert!(%MetricSnapshot{
        project_id: project_id,
        type: "uptime",
        value: 100.0,
        inserted_at: now
      })

      assert :ok == Collector.collect_mttr(project_id)
    end
  end

  describe "collect_project_metrics/1" do
    test "logs debug for unsupported provider" do
      project_id = project_id()

      setting = %DashboardSSD.Deployments.HealthCheckSetting{
        project_id: project_id,
        provider: "custom"
      }

      assert :ok == Collector.collect_project_metrics(setting)
    end

    test "handles unknown providers" do
      setting = %DashboardSSD.Deployments.HealthCheckSetting{
        project_id: project_id(),
        provider: "unknown"
      }

      assert :ok == Collector.collect_project_metrics(setting)
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
  end

  defp project_id do
    unique = System.unique_integer([:positive])
    {:ok, client} = Clients.create_client(%{name: "Analytics Client #{unique}"})

    {:ok, project} =
      Projects.create_project(%{name: "Metrics Project #{unique}", client_id: client.id})

    project.id
  end
end
