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

  @doc """
  Format a DateTime in the user's local offset (in minutes).

  Example: `human_datetime_local(dt, -480)` for UTC-8.
  """
  @spec human_datetime_local(DateTime.t() | NaiveDateTime.t() | nil, integer()) :: String.t()
  def human_datetime_local(nil, _offset_minutes), do: "n/a"
  def human_datetime_local(%NaiveDateTime{} = ndt, offset_minutes) do
    ndt
    |> DateTime.from_naive!("Etc/UTC")
    |> human_datetime_local(offset_minutes)
  end

  def human_datetime_local(%DateTime{} = dt, offset_minutes) when is_integer(offset_minutes) do
    dt
    |> DateTime.add(offset_minutes * 60, :second)
    |> Calendar.strftime("%b %d, %Y · %H:%M")
  end

  @doc "Format only the time portion for a given DateTime at a local offset."
  @spec human_time_local(DateTime.t() | NaiveDateTime.t() | nil, integer()) :: String.t()
  def human_time_local(nil, _), do: "n/a"
  def human_time_local(%NaiveDateTime{} = ndt, off), do: human_datetime_local(ndt, off) |> String.split(" · ") |> List.last()
  def human_time_local(%DateTime{} = dt, off), do: human_datetime_local(dt, off) |> String.split(" · ") |> List.last()

  @doc "Returns true if the DateTime occurs today in the given local offset."
  @spec today?(DateTime.t() | NaiveDateTime.t(), integer()) :: boolean()
  def today?(%NaiveDateTime{} = ndt, off), do: today?(DateTime.from_naive!(ndt, "Etc/UTC"), off)
  def today?(%DateTime{} = dt, off) when is_integer(off) do
    d_local = dt |> DateTime.add(off * 60, :second) |> DateTime.to_date()
    now_local = DateTime.utc_now() |> DateTime.add(off * 60, :second) |> DateTime.to_date()
    d_local == now_local
  end
end
