defmodule DashboardSSDWeb.Plugs.Authorize do
  @moduledoc ""
  import Plug.Conn
  alias DashboardSSD.Auth.Policy

  def init([action, subject]), do: %{action: action, subject: subject}
  def init(opts) when is_map(opts), do: opts

  def call(conn, %{action: action, subject: subject}) do
    user = conn.assigns[:current_user]

    if Policy.can?(user, action, subject) do
      conn
    else
      conn
      |> send_resp(:forbidden, "Forbidden")
      |> halt()
    end
  end
end
