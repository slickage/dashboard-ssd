defmodule DashboardSSDWeb.PageController do
  @moduledoc """
  Static pages controller. Renders the home page and other static content.
  """
  use DashboardSSDWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end
end
