defmodule DashboardSSD.Integrations.GoogleToken do
  @moduledoc """
  Helper for retrieving a usable Google OAuth access token for a user, with
  transparent refresh using the stored `refresh_token` when needed.

  Persists updated tokens and expiry to `Accounts.ExternalIdentity`.
  """

  use Tesla
  alias DashboardSSD.Accounts.ExternalIdentity
  alias DashboardSSD.Repo

  @token_url "https://oauth2.googleapis.com/token"

  plug Tesla.Middleware.BaseUrl, @token_url |> URI.parse() |> Map.put(:path, "") |> URI.to_string()
  plug Tesla.Middleware.FormUrlencoded
  plug Tesla.Middleware.JSON

  @type token_result :: {:ok, String.t()} | {:error, term()}

  @doc """
  Returns a valid access token for the given user id, refreshing if expired.
  """
  @spec get_access_token_for_user(pos_integer()) :: token_result
  def get_access_token_for_user(user_id) when is_integer(user_id) do
    case Repo.get_by(ExternalIdentity, user_id: user_id, provider: "google") do
      %ExternalIdentity{} = idn -> ensure_fresh_token(idn)
      _ -> {:error, :no_token}
    end
  end

  defp ensure_fresh_token(%ExternalIdentity{token: token, expires_at: nil} = _idn) when is_binary(token) and byte_size(token) > 0 do
    {:ok, token}
  end

  defp ensure_fresh_token(%ExternalIdentity{token: token, expires_at: expires_at} = idn)
       when is_binary(token) and byte_size(token) > 0 and is_struct(expires_at, DateTime) do
    case DateTime.compare(expires_at, DateTime.utc_now()) do
      :gt -> {:ok, token}
      _ -> refresh_and_update(idn)
    end
  end

  defp ensure_fresh_token(%ExternalIdentity{} = idn) do
    refresh_and_update(idn)
  end

  defp refresh_and_update(%ExternalIdentity{refresh_token: nil}), do: {:error, :no_token}
  defp refresh_and_update(%ExternalIdentity{refresh_token: <<>>}), do: {:error, :no_token}

  defp refresh_and_update(%ExternalIdentity{} = idn) do
    with {:ok, client_id} <- fetch_env("GOOGLE_CLIENT_ID"),
         {:ok, client_secret} <- fetch_env("GOOGLE_CLIENT_SECRET"),
         {:ok, resp} <- request_refresh(client_id, client_secret, idn.refresh_token),
         {:ok, token, expires_at} <- parse_refresh(resp) do
      {:ok, _} =
        idn
        |> ExternalIdentity.changeset(%{token: token, expires_at: expires_at})
        |> Repo.update()

      {:ok, token}
    else
      {:error, _} = err -> err
      _ -> {:error, :refresh_failed}
    end
  end

  defp request_refresh(client_id, client_secret, refresh_token) do
    body = [
      grant_type: "refresh_token",
      client_id: client_id,
      client_secret: client_secret,
      refresh_token: refresh_token
    ]

    case post("/token", body) do
      {:ok, %Tesla.Env{status: 200, body: body}} -> {:ok, body}
      {:ok, %Tesla.Env{status: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_refresh(%{"access_token" => token, "expires_in" => secs}) when is_binary(token) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    expires_at = DateTime.add(now, to_int(secs), :second)
    {:ok, token, expires_at}
  end

  defp parse_refresh(%{"access_token" => token}) when is_binary(token) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    {:ok, token, DateTime.add(now, 3600, :second)}
  end

  defp parse_refresh(_), do: {:error, :invalid_response}

  defp fetch_env(key) do
    case System.get_env(key) do
      nil -> {:error, {:missing_env, key}}
      "" -> {:error, {:missing_env, key}}
      v -> {:ok, v}
    end
  end

  defp to_int(v) when is_integer(v), do: v
  defp to_int(v) when is_binary(v), do: String.to_integer(v)
end
