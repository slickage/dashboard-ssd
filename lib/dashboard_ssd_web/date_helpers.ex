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

  @doc "Formats a date-only string like `Nov 03, 2025`. Accepts Date, DateTime, or NaiveDateTime."
  @spec human_date(Date.t() | DateTime.t() | NaiveDateTime.t() | nil) :: String.t()
  def human_date(nil), do: "n/a"

  def human_date(%Date{} = d), do: Calendar.strftime(d, "%b %d, %Y")

  def human_date(%DateTime{} = dt) do
    dt |> DateTime.to_date() |> human_date()
  end

  def human_date(%NaiveDateTime{} = ndt) do
    ndt |> NaiveDateTime.to_date() |> human_date()
  end
end
