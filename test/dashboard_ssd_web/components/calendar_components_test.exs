defmodule DashboardSSDWeb.CalendarComponentsTest do
  use ExUnit.Case, async: true
  import Phoenix.Component
  import Phoenix.LiveViewTest
  import DashboardSSDWeb.CalendarComponents

  test "compact weekday labels are same color as dates (no muted class)" do
    assigns = %{
      month: ~D[2025-11-01],
      today: ~D[2025-11-04],
      start_date: ~D[2025-11-01],
      end_date: ~D[2025-11-07]
    }

    html =
      rendered_to_string(~H"""
      <.month_calendar month={@month} today={@today} start_date={@start_date} end_date={@end_date} />
      """)

    assert html =~ ">Su<"
    refute html =~ "text-white/60"
  end

  test "full calendar weekday labels are same color as dates (no muted class)" do
    assigns = %{
      month: ~D[2025-11-01],
      today: ~D[2025-11-04],
      start_date: ~D[2025-11-01],
      end_date: ~D[2025-11-07]
    }

    html =
      rendered_to_string(~H"""
      <.month_calendar
        month={@month}
        today={@today}
        start_date={@start_date}
        end_date={@end_date}
        compact={false}
      />
      """)

    assert html =~ ">Sun<"
    refute html =~ "text-white/60"
  end

  test "today gets a ring highlight and range uses primary bg" do
    assigns = %{
      month: ~D[2025-11-01],
      today: ~D[2025-11-04],
      start_date: ~D[2025-11-02],
      end_date: ~D[2025-11-06]
    }

    html =
      rendered_to_string(~H"""
      <.month_calendar month={@month} today={@today} start_date={@start_date} end_date={@end_date} />
      """)

    # At least one primary bg for range
    assert html =~ "bg-theme-primary"
    # Today ring present
    assert html =~ "ring-theme-primary"
  end
end
