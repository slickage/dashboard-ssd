defmodule DashboardSSDWeb.AnalyticsComponents do
  @moduledoc """
  Components for analytics visualizations using Contex.
  """
  use Phoenix.Component

  alias Contex.LinePlot
  alias Phoenix.LiveView.Rendered

  @doc """
  Renders a line chart for metric trends.

  ## Examples

      <.line_chart data={@trends} title="Uptime Trends" />
  """
  attr :data, :list, required: true
  attr :title, :string, default: ""
  attr :width, :integer, default: 600
  attr :height, :integer, default: 400

  @spec line_chart(map()) :: Rendered.t()
  def line_chart(assigns) do
    # Transform data for Contex
    {data, headers} = transform_trends_for_line(assigns.data)

    # Get types for y_cols
    types = headers -- ["date"]

    if types == [] do
      ~H"""
      <div class="chart-container">
        <p class="text-zinc-600 text-center py-8">No data to display</p>
      </div>
      """
    else
      dataset = %Contex.Dataset{data: data, headers: headers}

      plot =
        LinePlot.new(dataset,
          title: assigns.title,
          mapping: %{x_col: "date", y_cols: types},
          width: assigns.width,
          height: assigns.height
        )

      plot_svg =
        Contex.LinePlot.to_svg(plot, %{
          show_x_axis: true,
          show_y_axis: true,
          x_axis_label: "Date",
          y_axis_label: "Value",
          legend_setting: :legend_right
        })

      svg_content = IO.iodata_to_binary(plot_svg)

      base_svg = "<svg width=\"WIDTH\" height=\"HEIGHT\" xmlns=\"http://www.w3.org/2000/svg\">"

      full_svg =
        String.replace(base_svg, "WIDTH", to_string(assigns.width))
        |> String.replace("HEIGHT", to_string(assigns.height))
        |> Kernel.<>(svg_content <> "</svg>")

      assigns = assign(assigns, :plot_svg, Phoenix.HTML.raw(full_svg))

      ~H"""
      <div class="chart-container">
        <h3 class="text-lg font-semibold mb-2">{assigns.title}</h3>
        {@plot_svg}
        <div class="mt-2 text-sm text-zinc-600">
          <strong>Legend:</strong> Uptime (%), MTTR (min), Linear Throughput
        </div>
      </div>
      """
    end
  end

  @doc """
  Renders a bar chart for daily averages.

  ## Examples

      <.bar_chart data={@daily_averages} title="Daily Metrics" />
  """
  attr :data, :list, required: true
  attr :title, :string, default: ""
  attr :width, :integer, default: 600
  attr :height, :integer, default: 400

  @spec bar_chart(map()) :: Rendered.t()
  def bar_chart(assigns) do
    # Transform data for bar chart
    {data, headers} = transform_trends_for_bar(assigns.data)

    if data == [] do
      ~H"""
      <div class="chart-container">
        <p class="text-zinc-600 text-center py-8">No data to display</p>
      </div>
      """
    else
      dataset = %Contex.Dataset{data: data, headers: headers}

      plot =
        Contex.BarChart.new(dataset,
          title: assigns.title,
          mapping: %{category_col: "date", value_cols: ["count"]},
          width: assigns.width,
          height: assigns.height
        )

      plot_svg =
        Contex.BarChart.to_svg(plot, %{
          show_x_axis: true,
          show_y_axis: true,
          x_axis_label: "Date",
          y_axis_label: "Average Value"
        })

      svg_content = IO.iodata_to_binary(plot_svg)

      base_svg = "<svg width=\"WIDTH\" height=\"HEIGHT\" xmlns=\"http://www.w3.org/2000/svg\">"

      full_svg =
        String.replace(base_svg, "WIDTH", to_string(assigns.width))
        |> String.replace("HEIGHT", to_string(assigns.height))
        |> Kernel.<>(svg_content <> "</svg>")

      assigns = assign(assigns, :plot_svg, Phoenix.HTML.raw(full_svg))

      ~H"""
      <div class="chart-container">
        <h3 class="text-lg font-semibold mb-2">{assigns.title}</h3>
        {@plot_svg}
        <div class="mt-2 text-sm text-zinc-600">
          Number of metrics recorded each day
        </div>
      </div>
      """
    end
  end

  # Helper functions

  defp transform_trends_for_line(trends) do
    # Transform to tabular format for multi-series line chart
    # Get all unique dates and types
    dates = trends |> Enum.map(& &1.date) |> Enum.uniq() |> Enum.sort()
    types = trends |> Enum.map(& &1.type) |> Enum.uniq() |> Enum.sort()

    # Create headers: ["date" | types]
    headers = ["date" | types]

    # Create data rows
    data = Enum.map(dates, &build_data_row(&1, types, trends))

    {data, headers}
  end

  defp build_data_row(date, types, trends) do
    values = Enum.map(types, &find_value_for_type(date, &1, trends))
    [Date.diff(date, ~D[2000-01-01]) | values]
  end

  defp find_value_for_type(date, type, trends) do
    case Enum.find(trends, &(&1.date == date && &1.type == type)) do
      nil -> 0.0
      trend -> trend.avg_value
    end
  end

  defp transform_trends_for_bar(trends) do
    # For bar chart, show daily count of metrics
    data =
      trends
      |> Enum.group_by(& &1.date)
      |> Enum.map(fn {date, points} ->
        count = length(points)
        [Date.diff(date, ~D[2000-01-01]), count]
      end)
      |> Enum.sort_by(& &1)

    headers = ["date", "count"]
    {data, headers}
  end
end
