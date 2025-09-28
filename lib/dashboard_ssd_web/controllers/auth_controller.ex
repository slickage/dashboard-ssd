defmodule DashboardSSDWeb.AuthController do
  @moduledoc """
  Handles Google OAuth sign-in/sign-out via Ueberauth and session management.
  """
  use DashboardSSDWeb, :controller
  alias DashboardSSD.Accounts
  alias Plug.Conn

  # Store optional redirect_to param before Ueberauth halts the request phase
  plug :store_redirect_to when action in [:request]

  if Mix.env() == :test do
    # In tests, run only the request phase via Ueberauth so tests can control the callback assigns.
    plug Ueberauth when action in [:request]
  else
    # In non-test environments, enable Ueberauth for request and all callback actions
    plug Ueberauth when action in [:request, :callback, :callback_get, :callback_post]
  end

  # The Ueberauth plug handles the redirect in the request phase.
  # We simply return the conn here; the plug will already have halted.
  @doc "Initiate OAuth flow via Ueberauth request phase."
  @spec request(Conn.t(), map()) :: Conn.t()
  def request(conn, _params), do: conn

  # Matches the Ueberauth failure case
  # Document callback once for all clauses
  @doc "Handle OAuth callback (success, failure, or stubbed) and manage session."
  @spec callback(Conn.t(), map()) :: Conn.t()
  def callback(conn, params)

  def callback(%{assigns: %{ueberauth_failure: _failure}} = conn, _params) do
    conn
    |> put_flash(:error, gettext("Authentication failed. Please try again."))
    |> redirect(to: ~p"/")
  end

  # Matches the Ueberauth success case
  def callback(%{assigns: %{ueberauth_auth: _auth}} = conn, _params) do
    user = handle_ueberauth(conn)
    redirect_to = get_session(conn, :redirect_to) || ~p"/"

    conn
    |> put_session(:user_id, user.id)
    |> delete_session(:redirect_to)
    |> configure_session(renew: true)
    |> handle_callback_redirect(redirect_to)
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

      redirect_to = get_session(conn, :redirect_to) || ~p"/"

      conn
      |> put_session(:user_id, user.id)
      |> delete_session(:redirect_to)
      |> configure_session(renew: true)
      |> handle_callback_redirect(redirect_to)
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
  @doc "Log the user out by clearing the session."
  @spec delete(Conn.t(), map()) :: Conn.t()
  def delete(conn, _params) do
    conn
    |> put_flash(:info, gettext("You have been logged out!"))
    |> clear_session()
    |> redirect(to: ~p"/")
  end

  # Delegating wrappers to avoid CSRF action reuse warnings without changing behavior
  @doc "Handle OAuth callback for GET requests."
  @spec callback_get(Conn.t(), map()) :: Conn.t()
  def callback_get(conn, params), do: callback(conn, params)

  @doc "Handle OAuth callback for POST requests."
  @spec callback_post(Conn.t(), map()) :: Conn.t()
  def callback_post(conn, params), do: callback(conn, params)

  @doc "Handle logout for GET requests."
  @spec delete_get(Conn.t(), map()) :: Conn.t()
  def delete_get(conn, params), do: delete(conn, params)

  # Handle callback redirect - use popup-aware logic for production, HTTP redirect for tests
  # Note: Sobelow XSS warning is a false positive - redirect_to is properly escaped with Phoenix.HTML.html_escape
  defp handle_callback_redirect(conn, redirect_to) do
    if Mix.env() == :test do
      # In tests, use HTTP redirect for easier testing
      redirect(conn, to: redirect_to)
    else
      # Escape the redirect URL to prevent XSS - escape quotes for JavaScript
      escaped_redirect_to = String.replace(redirect_to, "'", "\\'")

      # In production, render close page that handles popup detection client-side
      # Build HTML response safely using Phoenix.HTML
      html_content =
        Phoenix.HTML.raw("""
        <!DOCTYPE html>
        <html data-redirect-url="#{Phoenix.HTML.html_escape(escaped_redirect_to)}">
        <head>
          <title>Authentication Complete</title>
          <script>
            (function() {
              var redirectUrl = document.documentElement.getAttribute('data-redirect-url');

              // Check if this is a popup window
              var isPopup = window.opener && window.opener !== window;

              if (isPopup && !window.opener.closed) {
                // This is a popup - tell parent to reload and close self
                try {
                  window.opener.location.href = redirectUrl;
                  setTimeout(function() {
                    window.close();
                  }, 100);
                } catch (e) {
                  // Cross-origin error - fallback to closing popup only
                  setTimeout(function() {
                    window.close();
                  }, 100);
                }
              } else {
                // Not a popup or parent is closed - redirect this window
                window.location.href = redirectUrl;
              }
            })();
          </script>
        </head>
        <body>
          <p>Authentication successful! Redirecting...</p>
        </body>
        </html>
        """)

      conn
      |> put_resp_content_type("text/html")
      |> send_resp(200, html_content)
    end
  end

  defp store_redirect_to(conn, _opts) do
    case conn.params["redirect_to"] do
      val when is_binary(val) and val != "" -> put_session(conn, :redirect_to, val)
      _ -> conn
    end
  end
end
