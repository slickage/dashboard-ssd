defmodule DashboardSSDWeb.UserAuth do
  @moduledoc "User authentication helpers for controllers and LiveViews."
  import Plug.Conn
  alias DashboardSSD.Accounts.User
  alias DashboardSSD.Auth.Policy
  alias DashboardSSD.Repo
  alias Phoenix.LiveView
  alias Phoenix.LiveView.Socket
  alias Plug.Conn

  # Controller plug: assign current_user on conn
  @doc "Assign `:current_user` on the conn from session user_id, if present."
  @spec fetch_current_user(Conn.t(), term()) :: Conn.t()
  def fetch_current_user(conn, _opts) do
    user =
      case get_session(conn, :user_id) do
        nil ->
          nil

        id ->
          Repo.get(User, id)
          |> case do
            nil -> nil
            user -> Repo.preload(user, :role)
          end
      end

    assign(conn, :current_user, user)
  end

  # LiveView on_mount: mount_current_user
  @doc "on_mount: assign current_user, enforce authz as configured."
  @spec on_mount(term(), map(), map(), Socket.t()) :: {:cont, Socket.t()} | {:halt, Socket.t()}
  def on_mount(arg, _params, _session, _socket)

  def on_mount(:mount_current_user, _params, session, socket) do
    user =
      case Map.get(session, "user_id") do
        nil ->
          nil

        id ->
          Repo.get(User, id)
          |> case do
            nil -> nil
            user -> Repo.preload(user, :role)
          end
      end

    {:cont, Phoenix.Component.assign(socket, current_user: user)}
  end

  # LiveView on_mount: ensure_authenticated (redirects to OAuth with redirect_to)
  def on_mount(:ensure_authenticated, _params, session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      path = Map.get(session, "current_path") || "/"
      {:halt, LiveView.redirect(socket, to: "/auth/google?redirect_to=" <> path)}
    end
  end

  # LiveView on_mount: ensure_authorized with {action, subject}
  def on_mount({:ensure_authorized, action, subject}, _params, _session, socket) do
    user = socket.assigns[:current_user]

    if Policy.can?(user, action, subject) do
      {:cont, socket}
    else
      {:halt, LiveView.redirect(socket, to: "/")}
    end
  end

  # LiveView on_mount: require authenticated + authorized
  # Arg form: {:require, action, subject}
  def on_mount({:require, action, subject}, _params, session, socket) do
    case socket.assigns[:current_user] do
      nil ->
        path = Map.get(session, "current_path") || "/"
        {:halt, LiveView.redirect(socket, to: "/auth/google?redirect_to=" <> path)}

      user ->
        if Policy.can?(user, action, subject) do
          {:cont, socket}
        else
          {:halt, LiveView.redirect(socket, to: "/")}
        end
    end
  end
end
