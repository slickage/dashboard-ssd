defmodule DashboardSSDWeb.InviteController do
  @moduledoc "Handles acceptance of invitation links."
  use DashboardSSDWeb, :controller

  alias DashboardSSD.Accounts
  alias DashboardSSD.Accounts.UserInvite

  @spec accept(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def accept(conn, %{"token" => token}) do
    case Accounts.get_invite_by_token(token) do
      %UserInvite{used_at: nil} = invite ->
        conn =
          conn
          |> put_session(:invite_token, invite.token)

        conn =
          if current_user_id(conn) do
            {:ok, _user} =
              Accounts.apply_invite(Accounts.get_user!(current_user_id(conn)), invite.token)

            conn
            |> delete_session(:invite_token)
            |> put_flash(:info, gettext("Invitation accepted."))
          else
            conn
            |> put_flash(
              :info,
              gettext("Invitation saved. Sign in with Google to finish.")
            )
          end

        if current_user_id(conn) do
          redirect(conn, to: ~p"/")
        else
          redirect(conn, to: ~p"/auth/google")
        end

      %UserInvite{} ->
        conn
        |> put_flash(:error, gettext("This invitation has already been used."))
        |> redirect(to: ~p"/login")

      nil ->
        conn
        |> put_flash(:error, gettext("Invalid invitation token."))
        |> redirect(to: ~p"/login")
    end
  end

  defp current_user_id(conn), do: get_session(conn, :user_id)
end
