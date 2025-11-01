defmodule DashboardSSDWeb.PageControllerTest do
  use DashboardSSDWeb.ConnCase, async: true

  alias DashboardSSDWeb.PageController

  test "home renders without layout" do
    conn =
      build_conn()
      |> Phoenix.Controller.put_view(DashboardSSDWeb.PageHTML)
      |> Phoenix.Controller.put_format("html")
      |> then(&%Plug.Conn{&1 | params: %{"_format" => "html"}})
      |> Plug.Conn.assign(:flash, %{})

    conn = PageController.home(conn, %{})

    assert html_response(conn, 200) =~ "Phoenix Framework"
    refute conn.private[:phoenix_layout]
  end
end
