defmodule DashboardSSDWeb.AuthController do
  use DashboardSSDWeb, :controller
  alias DashboardSSD.Accounts

  if Mix.env() != :test do
    plug Ueberauth
  end

  def request(conn, _params) do
    mode = Application.get_env(:dashboard_ssd, :oauth_mode, :real)

    case mode do
      :stub -> redirect(conn, to: ~p"/auth/google/callback?code=dev-stub")
      # Ueberauth plug handles redirect in non-test env
      _ -> conn
    end
  end

  def callback(conn, params) do
    auth = conn.assigns[:ueberauth_auth]
    mode = Application.get_env(:dashboard_ssd, :oauth_mode, :real)

    user =
      cond do
        auth ->
          handle_ueberauth(conn)

        mode == :stub ->
          code = Map.get(params, "code", "dev-stub")

          email =
            if String.contains?(code, "existing"),
              do: "existing@example.com",
              else: "new@example.com"

          Accounts.upsert_user_with_identity("google", %{
            email: email,
            name: "Stub User",
            provider_id: code
          })

        true ->
          handle_ueberauth(conn)
      end

    conn
    |> put_session(:user_id, user.id)
    |> configure_session(renew: true)
    |> redirect(to: ~p"/")
  end

  defp handle_ueberauth(conn) do
    auth = conn.assigns[:ueberauth_auth]
    info = (auth && auth.info) || %{}
    creds = (auth && auth.credentials) || %{}

    Accounts.upsert_user_with_identity("google", %{
      email: Map.get(info, :email) || Map.get(info, "email"),
      name: Map.get(info, :name) || Map.get(info, "name"),
      provider_id: (auth && auth.uid) || nil,
      token: Map.get(creds, :token),
      refresh_token: Map.get(creds, :refresh_token),
      expires_at: Map.get(creds, :expires_at)
    })
  end
end
