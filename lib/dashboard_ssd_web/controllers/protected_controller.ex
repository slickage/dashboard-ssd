defmodule DashboardSSDWeb.ProtectedController do
  use DashboardSSDWeb, :controller

  plug DashboardSSDWeb.Plugs.Authorize, {:read, :projects} when action in [:projects]
  plug DashboardSSDWeb.Plugs.Authorize, {:read, :clients} when action in [:clients]

  def projects(conn, _params) do
    text(conn, "projects ok")
  end

  def clients(conn, _params) do
    text(conn, "clients ok")
  end
end
