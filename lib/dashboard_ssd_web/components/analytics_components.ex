defmodule DashboardSSDWeb.AnalyticsComponents do
  @moduledoc """
  Components for analytics visualizations using Contex.
  """
  use Phoenix.Component

  alias Contex.LinePlot
  import Phoenix.HTML

  @doc """
  Renders a line chart for metric trends.

  ## Examples

      <.line_chart data={@trends} title="Uptime Trends" />
  """
  attr :data, :list, required: true
  attr :title, :string, default: ""
  attr :width, :integer, default: 600
  attr :height, :integer, default: 400

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

      plot_svg = Contex.LinePlot.to_svg(plot, %{show_x_axis: true, show_y_axis: true})
      svg_content = IO.iodata_to_binary(plot_svg)

      full_svg =
        "<svg width=\"#{assigns.width}\" height=\"#{assigns.height}\" xmlns=\"http://www.w3.org/2000/svg\">" <>
          svg_content <> "</svg>"

      assigns = assign(assigns, :plot_svg, Phoenix.HTML.raw(full_svg))

      ~H"""
      <div class="chart-container">
        {@plot_svg}
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
          mapping: %{category_col: "date", value_cols: ["average"]},
          width: assigns.width,
          height: assigns.height
        )

      plot_svg = Contex.BarChart.to_svg(plot, %{show_x_axis: true, show_y_axis: true})
      svg_content = IO.iodata_to_binary(plot_svg)

      full_svg =
        "<svg width=\"#{assigns.width}\" height=\"#{assigns.height}\" xmlns=\"http://www.w3.org/2000/svg\">" <>
          svg_content <> "</svg>"

      assigns = assign(assigns, :plot_svg, Phoenix.HTML.raw(full_svg))

      ~H"""
      <div class="chart-container">
        {@plot_svg}
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
    data =
      Enum.map(dates, fn date ->
        # Find values for each type on this date
        values =
          Enum.map(types, fn type ->
            case Enum.find(trends, &(&1.date == date && &1.type == type)) do
              nil -> 0.0
              trend -> trend.avg_value
            end
          end)

        [Date.diff(date, ~D[2000-01-01]) | values]
      end)

    {data, headers}
  end

  defp transform_trends_for_bar(trends) do
    # For bar chart, show daily averages across all types
    data =
      trends
      |> Enum.group_by(& &1.date)
      |> Enum.map(fn {date, points} ->
        avg_value = Enum.reduce(points, 0, &(&1.avg_value + &2)) / length(points)
        [Date.diff(date, ~D[2000-01-01]), avg_value]
      end)
      |> Enum.sort_by(& &1)

    headers = ["date", "average"]
    {data, headers}
  end
end
