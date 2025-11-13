defmodule DashboardSSDWeb.ProtectedController do
  @moduledoc """
  Simple endpoints behind authorization used by dev routes and smoke checks.

    - Demonstrates plug-based capability checks for controller actions.
  - Provides lightweight smoke-test endpoints for internal monitoring.
  - Serves as scaffolding for future diagnostic routes if needed.
  """
  use DashboardSSDWeb, :controller
  alias Plug.Conn

  plug DashboardSSDWeb.Plugs.Authorize, {:read, :projects} when action in [:projects]
  plug DashboardSSDWeb.Plugs.Authorize, {:read, :clients} when action in [:clients]

  @doc "Protected dev route: return a simple projects ok response."
  @spec projects(Conn.t(), map()) :: Conn.t()
  def projects(conn, _params) do
    # Dev-only smoke route for protected area
    text(conn, "projects ok")
  end

  @doc "Protected dev route: return a simple clients ok response."
  @spec clients(Conn.t(), map()) :: Conn.t()
  def clients(conn, _params) do
    # Dev-only smoke route for protected area
    text(conn, "clients ok")
  end
end
