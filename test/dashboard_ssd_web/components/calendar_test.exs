defmodule DashboardSSDWeb.CalendarComponentsHarnessTest do
  use DashboardSSDWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  defmodule CalHarness do
    use Phoenix.LiveView
    import DashboardSSDWeb.CalendarComponents

    @impl true
    def mount(_p, _s, socket) do
      {:ok, assign(socket, assigns_from_env())}
    end

    defp assigns_from_env do
      %{
        month: ~D[2025-01-15],
        today: nil,
        start_date: nil,
        end_date: nil,
        compact: true,
        has_meetings: %{}
      }
    end

    @impl true
    def render(assigns) do
      ~H"""
      <.month_calendar
        month={@month}
        today={@today}
        start_date={@start_date}
        end_date={@end_date}
        compact={@compact}
        has_meetings={@has_meetings}
      />
      """
    end

    @impl true
    def handle_info({:assigns, map}, socket) when is_map(map) do
      {:noreply, assign(socket, map)}
    end
  end

  test "month_calendar sets default today when nil and shows header", %{conn: conn} do
    {:ok, _view, html} = live_isolated(conn, CalHarness)
    assert html =~ "Jan 2025"
  end

  test "month_calendar respects Date today and marks it with ring class", %{conn: conn} do
    {:ok, view, _} = live_isolated(conn, CalHarness)
    # Update today to an in-month date (15th)
    send(view.pid, {:assigns, %{today: ~D[2025-01-15]}})
    html = render(view)
    assert html =~ "ring-theme-primary"
  end

  test "in_range? false branch when no start/end and highlights busy days with font-bold", %{
    conn: conn
  } do
    {:ok, view, _} = live_isolated(conn, CalHarness)
    # Provide a has_meetings map to set font-bold on specific date
    send(view.pid, {:assigns, %{has_meetings: %{~D[2025-01-10] => true}}})
    html = render(view)
    assert html =~ "font-bold"
    # No bg-theme-primary when no range is provided
    refute html =~ "bg-theme-primary"
  end
end
