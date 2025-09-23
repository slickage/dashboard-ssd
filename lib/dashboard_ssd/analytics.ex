defmodule DashboardSSD.Analytics do
  @moduledoc """
  Analytics context for managing metric snapshots and calculations.

  Provides functionality to store, retrieve, and calculate various metrics
  like uptime percentage, MTTR (Mean Time To Recovery), and Linear throughput.
  """

  import Ecto.Query, warn: false
  alias DashboardSSD.Analytics.MetricSnapshot
  alias DashboardSSD.Repo
  alias Ecto.Changeset

  @type trend_entry :: %{
          date: Date.t(),
          type: String.t(),
          avg_value: float()
        }

  @doc """
  Returns the list of metric snapshots ordered by most recent first.

  ## Examples

      iex> list_metrics()
      [%MetricSnapshot{}, ...]

  """
  @spec list_metrics(integer() | nil, pos_integer()) :: [MetricSnapshot.t()]
  def list_metrics(project_id \\ nil, limit \\ 50) do
    query = from m in MetricSnapshot, order_by: [desc: m.id], limit: ^limit

    query =
      if project_id do
        from m in query, where: m.project_id == ^project_id
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Creates a metric snapshot.

  ## Examples

      iex> create_metric(%{project_id: 1, type: "uptime", value: 99.5})
      {:ok, %MetricSnapshot{}}

      iex> create_metric(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_metric(map()) :: {:ok, MetricSnapshot.t()} | {:error, Changeset.t()}
  def create_metric(attrs \\ %{}) do
    %MetricSnapshot{}
    |> MetricSnapshot.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Calculates the average uptime percentage from uptime metrics.

  Returns 0.0 if no uptime metrics exist.

  ## Examples

      iex> calculate_uptime()
      97.5

  """
  @spec calculate_uptime(integer() | nil) :: float()
  def calculate_uptime(project_id \\ nil) do
    query =
      from m in MetricSnapshot,
        where: m.type == "uptime",
        select: avg(m.value)

    query =
      if project_id do
        from m in query, where: m.project_id == ^project_id
      else
        query
      end

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
  @spec calculate_mttr(integer() | nil) :: float()
  def calculate_mttr(project_id \\ nil) do
    query =
      from m in MetricSnapshot,
        where: m.type == "mttr",
        select: avg(m.value)

    query =
      if project_id do
        from m in query, where: m.project_id == ^project_id
      else
        query
      end

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
  @spec calculate_linear_throughput(integer() | nil) :: float()
  def calculate_linear_throughput(project_id \\ nil) do
    query =
      from m in MetricSnapshot,
        where: m.type == "linear_throughput",
        select: avg(m.value)

    query =
      if project_id do
        from m in query, where: m.project_id == ^project_id
      else
        query
      end

    case Repo.one(query) do
      nil -> 0.0
      value when is_float(value) -> value
      value -> Decimal.to_float(value)
    end
  end

  @doc """
  Returns trend data for charts: list of %{date: Date.t(), type: String.t(), avg_value: float}

  Groups metrics by date and type, calculating daily averages.

  ## Examples

      iex> get_trends()
      [%{date: ~D[2023-01-01], type: "uptime", avg_value: 99.5}, ...]

  """
  @spec get_trends(integer() | nil, pos_integer()) :: [trend_entry()]
  def get_trends(project_id \\ nil, days \\ 30) do
    start_datetime = DateTime.utc_now() |> DateTime.add(-days * 24 * 3600, :second)

    query =
      from m in MetricSnapshot,
        where: m.inserted_at >= ^start_datetime,
        group_by: [fragment("date(?)", m.inserted_at), m.type],
        select: %{
          date: fragment("date(?)", m.inserted_at),
          type: m.type,
          avg_value: avg(m.value)
        },
        order_by: [asc: fragment("date(?)", m.inserted_at)]

    query =
      if project_id do
        from m in query, where: m.project_id == ^project_id
      else
        query
      end

    Repo.all(query)
    |> Enum.map(fn %{date: date, type: type, avg_value: avg_value} ->
      %{
        date: date,
        type: type,
        avg_value: if(is_float(avg_value), do: avg_value, else: Decimal.to_float(avg_value))
      }
    end)
  end

  @doc """
  Exports metrics to CSV format.

  If project_id is provided, exports only for that project.

  ## Examples

      iex> export_to_csv()
      "project_id,type,value,inserted_at\\n1,uptime,99.5,2023-01-01T00:00:00Z\\n"

  """
  @spec export_to_csv(integer() | nil) :: String.t()
  def export_to_csv(project_id \\ nil) do
    metrics = list_metrics(project_id)

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
