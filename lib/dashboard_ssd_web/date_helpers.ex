defmodule DashboardSSDWeb.DateHelpers do
  @moduledoc """
  Human-readable date/time formatting helpers for web views.

  Note: Currently formats in UTC. If/when user timezone handling is added to
  session/assigns, convert before formatting.
  """

  @spec human_datetime(DateTime.t() | NaiveDateTime.t() | nil) :: String.t()
  def human_datetime(nil), do: "n/a"

  def human_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %d, %Y · %H:%M UTC")
  end

  def human_datetime(%NaiveDateTime{} = ndt) do
    Calendar.strftime(ndt, "%b %d, %Y · %H:%M")
  end
end

