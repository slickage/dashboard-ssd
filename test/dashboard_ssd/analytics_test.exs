defmodule DashboardSSD.AnalyticsTest do
  use DashboardSSD.DataCase, async: true

  import Ecto.Query

  alias DashboardSSD.{Analytics, Clients, Projects, Repo}
  alias DashboardSSD.Analytics.MetricSnapshot

  describe "MetricSnapshot schema" do
    test "changeset with valid attributes" do
      {:ok, client} = Clients.create_client(%{name: "Test Client"})
      {:ok, project} = Projects.create_project(%{name: "Test Project", client_id: client.id})

      attrs = %{
        project_id: project.id,
        type: "uptime",
        value: 99.5
      }

      changeset = MetricSnapshot.changeset(%MetricSnapshot{}, attrs)
      assert changeset.valid?
      assert changeset.changes.project_id == project.id
      assert changeset.changes.type == "uptime"
      assert changeset.changes.value == 99.5
    end

    test "changeset with invalid attributes" do
      changeset = MetricSnapshot.changeset(%MetricSnapshot{}, %{})
      refute changeset.valid?

      assert %{
               project_id: ["can't be blank"],
               type: ["can't be blank"],
               value: ["can't be blank"]
             } = errors_on(changeset)
    end
  end

  describe "list_metrics/0" do
    test "returns empty list when no metrics exist" do
      assert Analytics.list_metrics() == []
    end

    test "returns metrics ordered by id desc (most recent first)" do
      {:ok, client} = Clients.create_client(%{name: "Test Client"})
      {:ok, project} = Projects.create_project(%{name: "Test Project", client_id: client.id})

      {:ok, metric1} =
        Analytics.create_metric(%{project_id: project.id, type: "uptime", value: 95.0})

      {:ok, metric2} =
        Analytics.create_metric(%{project_id: project.id, type: "mttr", value: 120.0})

      metrics = Analytics.list_metrics()
      assert length(metrics) == 2

      # Most recent first (higher ID)
      [first, second] = metrics
      assert first.id > second.id
      assert first.id == metric2.id
      assert second.id == metric1.id
    end
  end

  describe "create_metric/1" do
    test "creates metric with valid data" do
      {:ok, client} = Clients.create_client(%{name: "Test Client"})
      {:ok, project} = Projects.create_project(%{name: "Test Project", client_id: client.id})

      attrs = %{
        project_id: project.id,
        type: "uptime",
        value: 99.9
      }

      assert {:ok, metric} = Analytics.create_metric(attrs)
      assert metric.project_id == project.id
      assert metric.type == "uptime"
      assert metric.value == 99.9
    end

    test "returns error with invalid data" do
      assert {:error, changeset} = Analytics.create_metric(%{})
      refute changeset.valid?
    end
  end

  describe "calculate_uptime/0" do
    test "returns 0 when no uptime metrics exist" do
      assert Analytics.calculate_uptime() == 0.0
    end

    test "calculates average uptime from metrics" do
      {:ok, client} = Clients.create_client(%{name: "Test Client"})
      {:ok, project} = Projects.create_project(%{name: "Test Project", client_id: client.id})

      Analytics.create_metric(%{project_id: project.id, type: "uptime", value: 95.0})
      Analytics.create_metric(%{project_id: project.id, type: "uptime", value: 99.0})

      assert Analytics.calculate_uptime() == 97.0
    end
  end

  describe "calculate_mttr/0" do
    test "returns 0 when no mttr metrics exist" do
      assert Analytics.calculate_mttr() == 0.0
    end

    test "calculates average mttr from metrics" do
      {:ok, client} = Clients.create_client(%{name: "Test Client"})
      {:ok, project} = Projects.create_project(%{name: "Test Project", client_id: client.id})

      Analytics.create_metric(%{project_id: project.id, type: "mttr", value: 60.0})
      Analytics.create_metric(%{project_id: project.id, type: "mttr", value: 120.0})

      assert Analytics.calculate_mttr() == 90.0
    end
  end

  describe "calculate_linear_throughput/0" do
    test "returns 0 when no linear_throughput metrics exist" do
      assert Analytics.calculate_linear_throughput() == 0.0
    end

    test "calculates average linear throughput from metrics" do
      {:ok, client} = Clients.create_client(%{name: "Test Client"})
      {:ok, project} = Projects.create_project(%{name: "Test Project", client_id: client.id})

      Analytics.create_metric(%{project_id: project.id, type: "linear_throughput", value: 10.0})
      Analytics.create_metric(%{project_id: project.id, type: "linear_throughput", value: 15.0})

      assert Analytics.calculate_linear_throughput() == 12.5
    end
  end

  describe "export_to_csv/0" do
    test "returns CSV header when no metrics exist" do
      csv = Analytics.export_to_csv()
      assert csv == "project_id,type,value,inserted_at\n"
    end

    test "returns CSV with metrics data" do
      {:ok, client} = Clients.create_client(%{name: "Test Client"})
      {:ok, project} = Projects.create_project(%{name: "Test Project", client_id: client.id})

      {:ok, _metric} =
        Analytics.create_metric(%{project_id: project.id, type: "uptime", value: 95.0})

      csv = Analytics.export_to_csv()
      lines = String.split(String.trim(csv), "\n")

      # header + data
      assert length(lines) == 2
      assert hd(lines) == "project_id,type,value,inserted_at"
      assert String.contains?(Enum.at(lines, 1), "#{project.id},uptime,95.0,")
    end
  end

  describe "get_trends/2" do
    setup do
      {:ok, client} = Clients.create_client(%{name: "Trend Client"})
      {:ok, project} = Projects.create_project(%{name: "Trend Project", client_id: client.id})
      {:ok, project: project}
    end

    test "returns empty list when no metrics fall in range" do
      assert Analytics.get_trends(nil, 7) == []
    end

    test "aggregates metrics by date and type", %{project: project} do
      {:ok, m1} =
        Analytics.create_metric(%{project_id: project.id, type: "uptime", value: 90.0})

      {:ok, m2} =
        Analytics.create_metric(%{project_id: project.id, type: "uptime", value: 100.0})

      {:ok, m3} =
        Analytics.create_metric(%{project_id: project.id, type: "mttr", value: 30.0})

      yesterday = DateTime.add(DateTime.utc_now(), -86_400, :second)

      Repo.update_all(from(m in MetricSnapshot, where: m.id == ^m1.id),
        set: [inserted_at: yesterday]
      )

      Repo.update_all(from(m in MetricSnapshot, where: m.id == ^m2.id),
        set: [inserted_at: yesterday]
      )

      Repo.update_all(from(m in MetricSnapshot, where: m.id == ^m3.id),
        set: [inserted_at: yesterday]
      )

      trends = Analytics.get_trends(project.id, 2)

      assert length(trends) == 2

      assert Enum.any?(trends, fn
               %{type: "uptime", avg_value: 95.0} -> true
               _ -> false
             end)

      assert Enum.any?(trends, fn
               %{type: "mttr", avg_value: 30.0} -> true
               _ -> false
             end)
    end
  end
end
