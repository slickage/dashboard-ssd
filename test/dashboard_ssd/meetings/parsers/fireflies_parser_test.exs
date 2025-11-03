defmodule DashboardSSD.Meetings.Parsers.FirefliesParserTest do
  use ExUnit.Case, async: true

  alias DashboardSSD.Meetings.Parsers.FirefliesParser

  test "splits summary at 'Action Items' (case-insensitive)" do
    summary = """
    We discussed Q3 roadmap and delivery timelines.\n\nACTION ITEMS:\n- Prepare budget sheet\n- Email client on Friday
    """

    assert {:ok, %{accomplished: acc, action_items: items}} =
             FirefliesParser.split_summary(summary)

    assert acc =~ "Q3 roadmap"
    assert items == ["- Prepare budget sheet", "- Email client on Friday"]
  end

  test "no action items section returns accomplished only" do
    summary = "General updates and housekeeping."
    assert {:ok, %{accomplished: acc, action_items: items}} =
             FirefliesParser.split_summary(summary)

    assert acc == summary
    assert items == []
  end

  test "nil summary returns empty artifacts" do
    assert {:ok, %{accomplished: nil, action_items: []}} = FirefliesParser.split_summary(nil)
  end
end

