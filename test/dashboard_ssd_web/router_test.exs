defmodule DashboardSSDWeb.RouterTest do
  use ExUnit.Case, async: true

  alias DashboardSSDWeb.Router
  alias Plug.Test

  test "build_live_session/1 keeps query string when present" do
    conn =
      Test.conn("GET", "/projects?page=2")
      |> Test.init_test_session(%{user_id: 42})

    session = Router.build_live_session(conn)
    assert session["user_id"] == 42
    assert session["current_path"] == "/projects?page=2"
  end

  test "build_live_session/1 handles missing query string" do
    conn =
      Test.conn("GET", "/settings")
      |> Test.init_test_session(%{})

    session = Router.build_live_session(conn)
    assert session["current_path"] == "/settings"
  end
end
