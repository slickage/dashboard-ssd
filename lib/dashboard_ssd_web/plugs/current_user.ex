defmodule DashboardSSDWeb.Plugs.CurrentUser do
  @moduledoc "Assigns the current user (with role) from the session, if present."
  import Plug.Conn
  alias DashboardSSD.Accounts.User
  alias DashboardSSD.Repo

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :user_id) do
      nil ->
        assign(conn, :current_user, nil)

      user_id ->
        case Repo.get(User, user_id) do
          nil -> assign(conn, :current_user, nil)
          user -> assign(conn, :current_user, Repo.preload(user, :role))
        end
    end
  end
end
