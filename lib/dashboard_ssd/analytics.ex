defmodule DashboardSSD.Analytics do
  @moduledoc """
  Analytics context for managing metric snapshots and calculations.

  Provides functionality to store, retrieve, and calculate various metrics
  like uptime percentage, MTTR (Mean Time To Recovery), and Linear throughput.
  """

  import Ecto.Query, warn: false
  alias DashboardSSD.Analytics.MetricSnapshot
  alias DashboardSSD.Repo

  @doc """
  Returns the list of metric snapshots ordered by most recent first.

  ## Examples

      iex> list_metrics()
      [%MetricSnapshot{}, ...]

  """
  def list_metrics do
    Repo.all(from m in MetricSnapshot, order_by: [desc: m.id])
  end

  @doc """
  Creates a metric snapshot.

  ## Examples

      iex> create_metric(%{project_id: 1, type: "uptime", value: 99.5})
      {:ok, %MetricSnapshot{}}

      iex> create_metric(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_metric(attrs \\ %{}) do
    %MetricSnapshot{}
    |> MetricSnapshot.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Calculates the average uptime percentage from all uptime metrics.

  Returns 0.0 if no uptime metrics exist.

  ## Examples

      iex> calculate_uptime()
      97.5

  """
  def calculate_uptime do
    query =
      from m in MetricSnapshot,
        where: m.type == "uptime",
        select: avg(m.value)

    case Repo.one(query) do
      nil -> 0.0
      value when is_float(value) -> value
      value -> Decimal.to_float(value)
    end
  end

  @doc """
  Calculates the average MTTR (Mean Time To Recovery) in minutes.

  Returns 0.0 if no MTTR metrics exist.

  ## Examples

      iex> calculate_mttr()
      90.5

  """
  def calculate_mttr do
    query =
      from m in MetricSnapshot,
        where: m.type == "mttr",
        select: avg(m.value)

    case Repo.one(query) do
      nil -> 0.0
      value when is_float(value) -> value
      value -> Decimal.to_float(value)
    end
  end

  @doc """
  Calculates the average Linear throughput (issues per time period).

  Returns 0.0 if no linear_throughput metrics exist.

  ## Examples

      iex> calculate_linear_throughput()
      12.3

  """
  def calculate_linear_throughput do
    query =
      from m in MetricSnapshot,
        where: m.type == "linear_throughput",
        select: avg(m.value)

    case Repo.one(query) do
      nil -> 0.0
      value when is_float(value) -> value
      value -> Decimal.to_float(value)
    end
  end

  @doc """
  Exports all metrics to CSV format.

  Returns a string containing CSV data with headers.

  ## Examples

      iex> export_to_csv()
      "project_id,type,value,inserted_at\\n1,uptime,99.5,2023-01-01T00:00:00Z\\n"

  """
  def export_to_csv do
    metrics = list_metrics()

    headers = ["project_id", "type", "value", "inserted_at"]
    header_row = Enum.join(headers, ",") <> "\n"

    data_rows =
      Enum.map(metrics, fn metric ->
        [
          to_string(metric.project_id),
          metric.type,
          to_string(metric.value),
          DateTime.to_iso8601(metric.inserted_at)
        ]
        |> Enum.join(",")
      end)

    header_row <> Enum.join(data_rows, "\n")
  end
end
