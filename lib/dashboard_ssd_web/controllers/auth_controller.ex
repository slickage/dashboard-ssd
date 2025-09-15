defmodule DashboardSSDWeb.AuthController do
  use DashboardSSDWeb, :controller
  alias DashboardSSD.Accounts

  if Mix.env() == :test do
    # In tests, run the request phase via Ueberauth, but skip the callback
    # so tests can control assigns without invoking real strategies.
    plug Ueberauth when action in [:request]
  else
    # In non-test environments, enable Ueberauth for both request and callback
    # actions, matching the typical example setup.
    plug Ueberauth when action in [:request, :callback]
  end

  # The Ueberauth plug handles the redirect in the request phase.
  # We simply return the conn here; the plug will already have halted.
  def request(conn, _params), do: conn

  # Matches the Ueberauth failure case
  def callback(%{assigns: %{ueberauth_failure: _failure}} = conn, _params) do
    conn
    |> put_flash(:error, gettext("Authentication failed. Please try again."))
    |> redirect(to: ~p"/")
  end

  # Matches the Ueberauth success case
  def callback(%{assigns: %{ueberauth_auth: _auth}} = conn, _params) do
    user = handle_ueberauth(conn)

    conn
    |> put_session(:user_id, user.id)
    |> configure_session(renew: true)
    |> redirect(to: ~p"/")
  end

  # Test/stub path (no auth assigns present). Enables deterministic tests.
  def callback(conn, params) do
    mode = Application.get_env(:dashboard_ssd, :oauth_mode, :real)

    if mode == :stub do
      code = Map.get(params, "code", "dev-stub")

      email =
        if String.contains?(code, "existing"),
          do: "existing@example.com",
          else: "new@example.com"

      user =
        Accounts.upsert_user_with_identity("google", %{
          email: email,
          name: "Stub User",
          provider_id: code
        })

      conn
      |> put_session(:user_id, user.id)
      |> configure_session(renew: true)
      |> redirect(to: ~p"/")
    else
      # No assigns and not in stub mode – treat like failure
      conn
      |> put_flash(:error, gettext("Authentication failed. Please try again."))
      |> redirect(to: ~p"/")
    end
  end

  defp handle_ueberauth(conn) do
    auth = conn.assigns[:ueberauth_auth]
    info = (auth && auth.info) || %{}
    creds = (auth && auth.credentials) || %{}

    attrs = %{
      email: Map.get(info, :email) || Map.get(info, "email"),
      name: Map.get(info, :name) || Map.get(info, "name"),
      provider_id: (auth && auth.uid) || nil,
      token: Map.get(creds, :token),
      refresh_token: Map.get(creds, :refresh_token),
      expires_at: normalize_expires(Map.get(creds, :expires_at))
    }

    Accounts.upsert_user_with_identity("google", attrs)
  end

  defp normalize_expires(%DateTime{} = dt), do: dt
  defp normalize_expires(nil), do: nil
  defp normalize_expires(int) when is_integer(int), do: DateTime.from_unix!(int)
  defp normalize_expires(other), do: other

  # Log out: clear all session data and redirect home
  def delete(conn, _params) do
    conn
    |> put_flash(:info, gettext("You have been logged out!"))
    |> clear_session()
    |> redirect(to: ~p"/")
  end

  # Delegating wrappers to avoid CSRF action reuse warnings without changing behavior
  def callback_get(conn, params), do: callback(conn, params)
  def callback_post(conn, params), do: callback(conn, params)
  def delete_get(conn, params), do: delete(conn, params)
end
