defmodule DashboardSSDWeb.PageControllerTest do
  use DashboardSSDWeb.ConnCase, async: true

  import Phoenix.Controller

  alias DashboardSSDWeb.PageController
  alias DashboardSSDWeb.PageHTML

  test "home renders the static home page" do
    conn =
      build_conn()
      |> Plug.Conn.fetch_query_params()
      |> Map.put(:params, %{"_format" => "html"})
      |> Plug.Conn.assign(:flash, %{})
      |> put_view(PageHTML)
      |> put_layout(false)
      |> put_root_layout(false)

    conn = PageController.home(conn, %{})

    assert conn.status == 200
    assert conn.resp_body =~ "Guides &amp; Docs"
  end
end
