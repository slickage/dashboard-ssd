defmodule DashboardSSDWeb.Plugs.Authorize do
  @moduledoc """
  Authorization plug enforcing `Policy.can?/3` on a route.

    - Initializes action/subject pairs for capability checks in controllers.
  - Halts the connection with a 403 when the current user lacks access.
  - Keeps RBAC enforcement close to router/controller pipelines.
  """
  import Plug.Conn
  alias DashboardSSD.Auth.Policy

  @doc false
  @spec init({atom, atom} | %{action: atom, subject: atom}) :: %{action: atom, subject: atom}
  def init({action, subject}), do: %{action: action, subject: subject}
  def init(%{action: _action, subject: _subject} = opts), do: opts

  @doc false
  @spec call(Plug.Conn.t(), %{action: atom, subject: atom}) :: Plug.Conn.t()
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
