defmodule DashboardSSDWeb.PageController do
  @moduledoc """
  Static pages controller. Renders the home page and other static content.
  """
  use DashboardSSDWeb, :controller
  alias Plug.Conn

  @doc "Render the application home page."
  @spec home(Conn.t(), map()) :: Conn.t()
  def home(conn, _params) do
    # Render simple home page without the app layout
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end
end
