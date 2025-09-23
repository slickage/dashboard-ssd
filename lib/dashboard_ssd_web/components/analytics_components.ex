defmodule DashboardSSDWeb.AnalyticsComponents do
  @moduledoc """
  Components for analytics visualizations using Contex.
  """
  use Phoenix.Component

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
    assigns = assign(assigns, :title, assigns.title || "")

    ~H"""
    <div class="chart-container">
      <h3 class="text-lg font-semibold mb-2">{assigns.title}</h3>
      <p class="text-sm text-zinc-600">Chart rendering disabled.</p>
    </div>
    """
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
    assigns = assign(assigns, :title, assigns.title || "")

    ~H"""
    <div class="chart-container">
      <h3 class="text-lg font-semibold mb-2">{assigns.title}</h3>
      <p class="text-sm text-zinc-600">Chart rendering disabled.</p>
    </div>
    """
  end
end
