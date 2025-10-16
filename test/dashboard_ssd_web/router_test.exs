defmodule DashboardSSDWeb.RouterTest do
  use DashboardSSDWeb.ConnCase, async: true

  alias DashboardSSDWeb.Router
  alias Plug.Conn

  test "build_live_session extracts user_id and current_path" do
    conn = %Conn{
      request_path: "/kb",
      query_string: "q=test",
      private: %{},
      assigns: %{}
    }

    conn = Plug.Test.init_test_session(conn, %{user_id: 123})

    session = Router.build_live_session(conn)

    assert session == %{
             "user_id" => 123,
             "current_path" => "/kb?q=test"
           }
  end

  test "build_live_session handles no query string" do
    conn = %Conn{
      request_path: "/projects",
      query_string: "",
      private: %{},
      assigns: %{}
    }

    conn = Plug.Test.init_test_session(conn, %{user_id: 456})

    session = Router.build_live_session(conn)

    assert session == %{
             "user_id" => 456,
             "current_path" => "/projects"
           }
  end

  test "build_live_session handles nil query string" do
    conn = %Conn{
      request_path: "/analytics",
      query_string: nil,
      private: %{},
      assigns: %{}
    }

    conn = Plug.Test.init_test_session(conn, %{user_id: 789})

    session = Router.build_live_session(conn)

    assert session == %{
             "user_id" => 789,
             "current_path" => "/analytics"
           }
  end

  test "protected routes are dispatched", %{conn: conn} do
    # This request will dispatch to the protected route, covering the router lines
    conn = get(conn, "/protected/projects")
    # It will be redirected or halted due to auth, but the router lines are executed
    # redirect or forbidden
    assert conn.status in [302, 403]
  end
end
