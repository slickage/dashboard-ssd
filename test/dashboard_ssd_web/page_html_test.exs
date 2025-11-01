defmodule DashboardSSDWeb.PageHTMLTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias DashboardSSDWeb.PageHTML

  test "home component renders hero section" do
    rendered = render_component(&PageHTML.home/1, flash: %{})
    html = rendered_to_string(rendered)

    assert html =~ "Deploy your application"
    assert html =~ "Follow on Twitter"
  end
end
