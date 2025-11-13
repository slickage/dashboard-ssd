defmodule DashboardSSDWeb.InviteController do
  @moduledoc """
  Handles acceptance of invitation links.

    - Validates invite tokens, persists them in the session, or applies them to signed-in users.
  - Provides user-facing flash messaging for success, reuse, or invalid tokens.
  - Redirects visitors to the proper flows (Google auth or dashboard) after processing.
  """
  use DashboardSSDWeb, :controller

  alias DashboardSSD.Accounts
  alias DashboardSSD.Accounts.UserInvite

  @doc """
  Accepts an invite token and either stores it for later sign-in or applies it to
  the currently signed-in user, redirecting to the appropriate destination.
  """
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
