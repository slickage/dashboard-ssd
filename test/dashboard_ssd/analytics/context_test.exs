defmodule DashboardSSD.Analytics.ContextTest do
  use DashboardSSD.DataCase, async: true

  import Ecto.Query

  alias DashboardSSD.{Analytics, Clients, Projects, Repo}
  alias DashboardSSD.Analytics.MetricSnapshot

  describe "list_metrics/2" do
    test "filters by project and honors limit" do
      {:ok, client} = Clients.create_client(%{name: "Acme"})
      {:ok, project_a} = Projects.create_project(%{name: "Project A", client_id: client.id})
      {:ok, project_b} = Projects.create_project(%{name: "Project B", client_id: client.id})

      {:ok, _} =
        Analytics.create_metric(%{project_id: project_a.id, type: "uptime", value: 95.0})

      {:ok, _} =
        Analytics.create_metric(%{project_id: project_a.id, type: "uptime", value: 96.0})

      {:ok, _} =
        Analytics.create_metric(%{project_id: project_b.id, type: "uptime", value: 97.0})

      metrics_for_a = Analytics.list_metrics(project_a.id, 1)

      assert Enum.all?(metrics_for_a, &(&1.project_id == project_a.id))
      assert length(metrics_for_a) == 1

      # Confirm default call returns all metrics ordered by recency
      all_metrics = Analytics.list_metrics()
      ids = Enum.map(all_metrics, & &1.id)
      assert ids == Enum.sort(ids, :desc)
    end
  end

  describe "metric aggregations" do
    test "calculate_* helpers average values with and without project scope" do
      {:ok, client} = Clients.create_client(%{name: "Data Co"})
      {:ok, project} = Projects.create_project(%{name: "Main", client_id: client.id})

      for {type, values} <- %{
            "uptime" => [90.0, 100.0],
            "mttr" => [60.0, 120.0],
            "linear_throughput" => [10.0, 20.0]
          } do
        Enum.each(values, fn value ->
          {:ok, _} =
            Analytics.create_metric(%{
              project_id: project.id,
              type: type,
              value: value
            })
        end)
      end

      assert Analytics.calculate_uptime(project.id) == 95.0
      assert Analytics.calculate_mttr(project.id) == 90.0
      assert Analytics.calculate_linear_throughput(project.id) == 15.0

      assert Analytics.calculate_uptime() == 95.0
      assert Analytics.calculate_mttr() == 90.0
      assert Analytics.calculate_linear_throughput() == 15.0
    end
  end

  describe "get_trends/2" do
    test "returns daily averages with types converted to floats" do
      {:ok, client} = Clients.create_client(%{name: "Trend LLC"})
      {:ok, project} = Projects.create_project(%{name: "Trend Project", client_id: client.id})

      {:ok, first_metric} =
        Analytics.create_metric(%{
          project_id: project.id,
          type: "uptime",
          value: 90.0
        })

      {:ok, _second_metric} =
        Analytics.create_metric(%{
          project_id: project.id,
          type: "uptime",
          value: 100.0
        })

      # Force metrics onto two different dates to exercise grouping logic
      yesterday = DateTime.utc_now() |> DateTime.add(-86_400, :second)

      Repo.update_all(from(m in MetricSnapshot, where: m.id == ^first_metric.id),
        set: [inserted_at: yesterday]
      )

      trends = Analytics.get_trends(project.id, 2)

      assert [%{avg_value: 90.0, type: "uptime"}, %{avg_value: 100.0, type: "uptime"}] = trends
      assert Enum.map(trends, & &1.date) |> Enum.uniq() |> length() == 2
    end
  end

  describe "export_to_csv/1" do
    test "includes header row and metric data" do
      {:ok, client} = Clients.create_client(%{name: "CSV Corp"})
      {:ok, project} = Projects.create_project(%{name: "CSV Project", client_id: client.id})

      {:ok, metric} =
        Analytics.create_metric(%{
          project_id: project.id,
          type: "uptime",
          value: 99.9
        })

      csv = Analytics.export_to_csv(project.id)

      assert String.starts_with?(csv, "project_id,type,value,inserted_at\n")
      assert String.contains?(csv, Integer.to_string(project.id))
      assert String.contains?(csv, metric.type)
      assert String.contains?(csv, to_string(metric.value))
    end
  end
end
