defmodule DashboardSSD.Analytics.Workload do
  @moduledoc """
  Analytics utilities for workload summarization.

    - Aggregates Linear workload summaries across project lists.
  - Provides helper math (percentages) for dashboard widgets.
  - Guards behavior when Linear integration is disabled to avoid unnecessary calls.
  """

  alias DashboardSSD.Integrations.LinearUtils

  @doc """
  Summarizes workload across all projects.
  """
  @spec summarize_all_projects(list()) :: %{
          total: integer(),
          in_progress: integer(),
          finished: integer()
        }
  def summarize_all_projects(projects) do
    if LinearUtils.linear_enabled?() do
      do_summarize_projects(projects)
    else
      %{total: 0, in_progress: 0, finished: 0}
    end
  end

  @doc """
  Performs the summarization.
  """
  @spec do_summarize_projects(list()) :: %{
          total: integer(),
          in_progress: integer(),
          finished: integer()
        }
  def do_summarize_projects(projects) do
    Enum.reduce(projects, %{total: 0, in_progress: 0, finished: 0}, fn project, acc ->
      case LinearUtils.fetch_linear_summary(project) do
        %{total: t, in_progress: ip, finished: f} ->
          %{total: acc.total + t, in_progress: acc.in_progress + ip, finished: acc.finished + f}

        _ ->
          acc
      end
    end)
  end

  @doc """
  Calculates percentage.
  """
  @spec percent(integer(), integer()) :: integer()
  def percent(_n, 0), do: 0

  def percent(n, total) when is_integer(n) and is_integer(total) and total > 0 do
    trunc(n * 100 / total)
  end
end
