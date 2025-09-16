defmodule DashboardSSDWeb.ProtectedController do
  @moduledoc """
  Simple endpoints behind authorization used by dev routes and smoke checks.
  """
  use DashboardSSDWeb, :controller

  plug DashboardSSDWeb.Plugs.Authorize, {:read, :projects} when action in [:projects]
  plug DashboardSSDWeb.Plugs.Authorize, {:read, :clients} when action in [:clients]

  @doc "Protected dev route: return a simple projects ok response."
  def projects(conn, _params) do
    # Dev-only smoke route for protected area
    text(conn, "projects ok")
  end

  @doc "Protected dev route: return a simple clients ok response."
  def clients(conn, _params) do
    # Dev-only smoke route for protected area
    text(conn, "clients ok")
  end
end
