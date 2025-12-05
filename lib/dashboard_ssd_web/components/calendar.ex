defmodule DashboardSSDWeb.CalendarComponents do
  @moduledoc "Simple calendar components used across views."
  use Phoenix.Component

  @doc """
  Render a month grid for the given month (Date).

  Assigns:
    - `month`: Date representing any day in the month to render (required)
    - `today`: Date to highlight as current day (defaults to Date.utc_today())
    - `start_date`: Range start to highlight (optional)
    - `end_date`: Range end to highlight (optional)
    - `compact`: Render without outer card and tighter spacing (default: true)
  """
  attr :month, :any, required: true
  attr :today, :any, default: nil
  attr :start_date, :any, default: nil
  attr :end_date, :any, default: nil
  attr :compact, :boolean, default: true
  attr :on_day_click, :string, default: nil
  attr :has_meetings, :map, default: %{}

  def month_calendar(assigns) do
    assigns =
      assigns
      |> Map.update(:today, Date.utc_today(), fn
        nil -> Date.utc_today()
        %Date{} = d -> d
        other -> other
      end)

    ~H"""
    <%= if @compact do %>
      <div class="flex flex-col gap-1">
        <div class="text-sm font-medium text-white/80">
          {Calendar.strftime(@month, "%b %Y")}
        </div>
        <div class="grid grid-cols-7 gap-1 text-center text-xs">
          <div>Su</div>
          <div>Mo</div>
          <div>Tu</div>
          <div>We</div>
          <div>Th</div>
          <div>Fr</div>
          <div>Sa</div>
        </div>
        <div class="grid grid-cols-7 gap-1 text-center">
          <%= for _d <- leading_blanks(@month) do %>
            <div class="h-6 text-white/20">&nbsp;</div>
          <% end %>
          <%= for day <- 1..days_in_month(@month) do %>
            <% date = %Date{year: @month.year, month: @month.month, day: day} %>
            <% is_today = date == @today %>
            <% in_range = in_range?(date, @start_date, @end_date) %>
            <% busy? = Map.get(@has_meetings || %{}, date, false) %>
            <div
              phx-click={@on_day_click}
              phx-value-date={@on_day_click && Date.to_iso8601(date)}
              class={[
                "h-6 rounded text-xs leading-none flex items-center justify-center",
                (in_range and not is_today) && "bg-theme-primary text-white",
                is_today && "ring-1 ring-theme-primary ring-offset-transparent bg-transparent"
              ]}
            >
              <span class={busy? && "font-bold"}>{day}</span>
            </div>
          <% end %>
        </div>
      </div>
    <% else %>
      <div class="theme-card px-4 py-4 sm:px-6">
        <div class="text-lg font-medium text-white/80">
          {Calendar.strftime(@month, "%B %Y")}
        </div>
        <div class="mt-3 grid grid-cols-7 gap-1 text-center text-xs">
          <div>Sun</div>
          <div>Mon</div>
          <div>Tue</div>
          <div>Wed</div>
          <div>Thu</div>
          <div>Fri</div>
          <div>Sat</div>
        </div>
        <div class="mt-2 grid grid-cols-7 gap-1 text-center">
          <%= for _d <- leading_blanks(@month) do %>
            <div class="h-8 text-white/20">&nbsp;</div>
          <% end %>
          <%= for day <- 1..days_in_month(@month) do %>
            <% date = %Date{year: @month.year, month: @month.month, day: day} %>
            <% is_today = date == @today %>
            <% in_range = in_range?(date, @start_date, @end_date) %>
            <% busy? = Map.get(@has_meetings || %{}, date, false) %>
            <div
              phx-click={@on_day_click}
              phx-value-date={@on_day_click && Date.to_iso8601(date)}
              class={[
                "h-8 rounded text-xs flex items-center justify-center",
                (in_range and not is_today) && "bg-theme-primary text-white",
                is_today && "ring-1 ring-theme-primary ring-offset-transparent bg-transparent"
              ]}
            >
              <span class={busy? && "font-bold"}>{day}</span>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  defp days_in_month(%Date{year: y, month: m}), do: :calendar.last_day_of_the_month(y, m)

  # Number of blank cells before the first of the month when weeks start on Sunday
  defp leading_blanks(%Date{year: y, month: m}) do
    first = %Date{year: y, month: m, day: 1}
    # 1=Mon .. 7=Sun
    dow = Date.day_of_week(first)
    count = if dow == 7, do: 0, else: dow

    if count <= 0 do
      []
    else
      for _ <- 1..count//1, do: :blank
    end
  end

  defp in_range?(%Date{} = d, %Date{} = s, %Date{} = e),
    do: (Date.compare(d, s) in [:eq, :gt] and Date.compare(d, e) in [:eq, :lt]) or d == e

  defp in_range?(_d, _s, _e), do: false
end
