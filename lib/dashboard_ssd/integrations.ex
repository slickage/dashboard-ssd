defmodule DashboardSSD.Integrations do
  @moduledoc """
  Convenience wrappers around external integrations using tokens from runtime config.

  Tokens are read from `Application.get_env(:dashboard_ssd, :integrations)` which is
  populated in `config/runtime.exs` from environment variables (see `.env.example`).

    - Normalizes interaction with Linear (GraphQL), Slack, Notion, and Google Drive.
  - Pulls credentials from config/env with helpful error tuples when missing.
  - Provides helper routines for per-user OAuth tokens (Drive) and rate-limit aware calls (Linear).
  """

  alias DashboardSSD.Accounts.ExternalIdentity
  alias DashboardSSD.Integrations.{Drive, GoogleCalendar, Linear, Notion, Slack}
  alias DashboardSSD.Integrations.GoogleToken
  alias DashboardSSD.Meetings.CacheStore, as: MeetingsCache
  alias DashboardSSD.Repo
  require Logger

  @type error :: {:error, term()}

  defp cfg, do: Application.get_env(:dashboard_ssd, :integrations, [])

  defp fetch!(key, env_key) do
    conf = Keyword.get(cfg(), key)

    val =
      case conf do
        nil -> System.get_env(env_key)
        "" -> System.get_env(env_key)
        other -> other
      end

    if is_nil(val) or val == "", do: {:error, {:missing_env, env_key}}, else: {:ok, val}
  end

  # Linear
  @spec linear_list_issues(String.t(), map()) :: {:ok, map()} | error()
  @doc """
  List Linear issues via GraphQL using the configured token.

  Accepts a GraphQL `query` and optional `variables` map. Returns `{:ok, map}`
  with response data or `{:error, reason}` when missing configuration or request fails.
  """
  def linear_list_issues(query, variables \\ %{}) do
    with {:ok, token} <- fetch!(:linear_token, "LINEAR_TOKEN") do
      Linear.list_issues(strip_bearer(token), query, variables)
    end
  end

  # Slack
  @spec slack_send_message(String.t() | nil, String.t()) :: {:ok, map()} | error()
  @doc """
  Send a message to Slack using the bot token and optional channel override.

  If `channel` is nil, falls back to configured `SLACK_CHANNEL`. Returns
  `{:ok, map}` on success or `{:error, reason}` when configuration is missing.
  """
  def slack_send_message(channel, text) do
    with {:ok, token} <- fetch!(:slack_bot_token, "SLACK_BOT_TOKEN") do
      channel = channel || Keyword.get(cfg(), :slack_channel) || System.get_env("SLACK_CHANNEL")

      if is_nil(channel) or channel == "" do
        {:error, {:missing_env, "SLACK_CHANNEL"}}
      else
        Slack.send_message(token, channel, text)
      end
    end
  end

  # Notion
  @spec notion_search(String.t()) :: {:ok, map()} | error()
  @spec notion_search(String.t(), keyword()) :: {:ok, map()} | error()
  @doc """
  Search Notion for the given query string using the configured integration token.
  Returns `{:ok, map}` on success or `{:error, reason}` when configuration is missing.

  Options:
    * `:body` - additional body parameters for the search request
  """
  def notion_search(query, opts \\ []) do
    with {:ok, token} <- fetch!(:notion_token, "NOTION_TOKEN") do
      Notion.search(token, query, opts)
    end
  end

  # Drive
  @spec drive_list_files_in_folder(String.t()) :: {:ok, map()} | error()
  @doc """
  List Google Drive files in the specified `folder_id` using a configured access token.

  Uses `GOOGLE_DRIVE_TOKEN` or `GOOGLE_OAUTH_TOKEN` when present. For per-user access,
  prefer `drive_list_files_for_user/2`.
  """
  def drive_list_files_in_folder(folder_id) do
    # Accept either GOOGLE_DRIVE_TOKEN or GOOGLE_OAUTH_TOKEN
    token =
      Keyword.get(cfg(), :drive_token) || System.get_env("GOOGLE_DRIVE_TOKEN") ||
        System.get_env("GOOGLE_OAUTH_TOKEN")

    if is_nil(token) or token == "" do
      {:error, {:missing_env, "GOOGLE_DRIVE_TOKEN/GOOGLE_OAUTH_TOKEN"}}
    else
      Drive.list_files_in_folder(token, folder_id)
    end
  end

  @doc """
  Download a Drive file using the configured service account token.
  """
  @spec drive_download_file(String.t()) :: {:ok, Tesla.Env.t()} | error()
  def drive_download_file(file_id) do
    token =
      Keyword.get(cfg(), :drive_token) || System.get_env("GOOGLE_DRIVE_TOKEN") ||
        System.get_env("GOOGLE_OAUTH_TOKEN")

    if is_nil(token) or token == "" do
      {:error, {:missing_env, "GOOGLE_DRIVE_TOKEN/GOOGLE_OAUTH_TOKEN"}}
    else
      Drive.download_file(token, file_id)
    end
  end

  @doc """
  Shares a Drive folder using the configured service account.
  """
  @spec drive_share_folder(String.t(), map()) :: {:ok, map()} | error()
  def drive_share_folder(folder_id, params) do
    with {:ok, token} <- drive_service_token() do
      Drive.share_folder(token, folder_id, params)
    end
  end

  @doc """
  Removes a Drive permission entry from the folder using the service account.
  """
  @spec drive_unshare_folder(String.t(), String.t()) :: :ok | error()
  def drive_unshare_folder(folder_id, permission_id) do
    with {:ok, token} <- drive_service_token() do
      Drive.unshare_folder(token, folder_id, permission_id)
    end
  end

  @doc """
  Lists Drive permissions for the given folder using the service account.
  """
  @spec drive_list_permissions(String.t()) :: {:ok, [map()]} | error()
  def drive_list_permissions(folder_id) do
    with {:ok, token} <- drive_service_token(),
         {:ok, %{"permissions" => permissions}} <- Drive.list_permissions(token, folder_id) do
      {:ok, permissions}
    end
  end

  @doc """
  Returns a Drive service token, preferring `GOOGLE_DRIVE_TOKEN/GOOGLE_OAUTH_TOKEN`.
  If missing, attempts to mint a token from a service account JSON pointed to by
  `DRIVE_SERVICE_ACCOUNT_JSON` (or `GOOGLE_APPLICATION_CREDENTIALS`).

  In test mode, falls back to a fixed token when no credentials are provided to
  avoid external network calls.
  """
  def drive_service_token do
    case env_drive_token() do
      {:ok, token} ->
        Logger.debug("Drive token: using provided env token")
        {:ok, token}

      {:error, _} ->
        mint_drive_token()
    end
  end

  @doc false
  def env_drive_token do
    token =
      Keyword.get(cfg(), :drive_token) || System.get_env("GOOGLE_DRIVE_TOKEN") ||
        System.get_env("GOOGLE_OAUTH_TOKEN")

    if is_nil(token) or token == "" do
      {:error, {:missing_env, "GOOGLE_DRIVE_TOKEN/GOOGLE_OAUTH_TOKEN"}}
    else
      {:ok, token}
    end
  end

  defp mint_drive_token do
    if Application.get_env(:dashboard_ssd, :test_env?, false) do
      # Avoid real HTTP calls in test; token value is irrelevant in mocks.
      {:ok, "drive-test-token"}
    else
      with {:ok, %{client_email: email, private_key: key, path: path}} <-
             service_account_credentials(),
           {:ok, jwt} <- sign_jwt(email, key),
           {:ok, token} <- exchange_jwt_for_token(jwt) do
        Logger.debug("Drive token: minted from service account JSON at #{path}")
        {:ok, token}
      else
        {:error, reason} ->
          Logger.error("Drive service token mint failed: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  defp service_account_credentials do
    with {:ok, path} <- service_account_path(),
         {:ok, creds} <- parse_service_account_json(path) do
      {:ok, Map.put(creds, :path, path)}
    end
  end

  defp service_account_path do
    path =
      System.get_env("DRIVE_SERVICE_ACCOUNT_JSON") ||
        System.get_env("GOOGLE_APPLICATION_CREDENTIALS") ||
        drive_service_account_json_path()

    if present_path?(path) do
      {:ok, path}
    else
      {:error, :missing_service_account_json}
    end
  end

  # sobelow_skip ["Traversal.FileModule"]
  defp parse_service_account_json(path) do
    # sobelow_skip ["Traversal.FileModule"]
    case File.read(path) do
      {:ok, raw} ->
        decode_service_account_json(raw)

      {:error, reason} ->
        {:error, {:unreadable_service_account, reason}}
    end
  end

  defp decode_service_account_json(raw) do
    case Jason.decode(raw) do
      {:ok, %{"client_email" => email, "private_key" => key}}
      when is_binary(email) and is_binary(key) and email != "" and key != "" ->
        {:ok, %{client_email: email, private_key: key}}

      {:ok, _} ->
        {:error, :invalid_service_account_json}

      {:error, reason} ->
        {:error, {:invalid_json, reason}}
    end
  end

  defp present_path?(path), do: is_binary(path) and path != ""

  defp drive_service_account_json_path do
    Application.get_env(:dashboard_ssd, :shared_documents_integrations)
    |> drive_config()
    |> extract_service_account_path()
  end

  defp drive_config(nil), do: nil
  defp drive_config(config) when is_list(config), do: Keyword.get(config, :drive)
  defp drive_config(config) when is_map(config), do: Map.get(config, :drive)
  defp drive_config(_), do: nil

  defp extract_service_account_path(nil), do: nil

  defp extract_service_account_path(cfg) when is_list(cfg) do
    Keyword.get(cfg, :service_account_json_path)
  end

  defp extract_service_account_path(cfg) when is_map(cfg) do
    Map.get(cfg, :service_account_json_path)
  end

  defp extract_service_account_path(_), do: nil

  defp sign_jwt(email, private_key) do
    iat = System.system_time(:second)
    exp = iat + 3600

    claims = %{
      "iss" => email,
      "scope" => "https://www.googleapis.com/auth/drive",
      "aud" => "https://oauth2.googleapis.com/token",
      "exp" => exp,
      "iat" => iat
    }

    jwk = JOSE.JWK.from_pem(private_key)
    jws = %{"alg" => "RS256", "typ" => "JWT"}

    case JOSE.JWT.sign(jwk, jws, claims) |> JOSE.JWS.compact() do
      {:error, reason} -> {:error, {:jwt_sign_failed, reason}}
      {_, jwt} -> {:ok, jwt}
    end
  rescue
    e -> {:error, {:jwt_sign_exception, e}}
  end

  defp exchange_jwt_for_token(jwt) do
    body =
      URI.encode_query(%{
        "grant_type" => "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion" => jwt
      })

    headers = [{"content-type", "application/x-www-form-urlencoded"}]

    case Tesla.post("https://oauth2.googleapis.com/token", body, headers: headers) do
      {:ok, %Tesla.Env{status: 200, body: %{"access_token" => token}}} ->
        {:ok, token}

      {:ok, %Tesla.Env{status: 200, body: body}} when is_binary(body) ->
        case Jason.decode(body) do
          {:ok, %{"access_token" => token}} -> {:ok, token}
          {:ok, other} -> {:error, {:token_exchange_failed, 200, other}}
          {:error, reason} -> {:error, {:token_exchange_failed, 200, {:invalid_json, reason}}}
        end

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, {:token_exchange_failed, status, body}}

      {:error, reason} ->
        Logger.error("Drive token exchange error: #{inspect(reason)}")
        {:error, {:token_exchange_error, reason}}
    end
  end

  @doc """
  List Google Drive files in `folder_id` using the stored OAuth token for the given user.

  Accepts either a user ID (integer) or a user struct/map with an `:id` key.
  Looks up the user's `external_identities` with provider "google" and uses that token.
  Returns `{:error, :no_token}` if no identity is stored.
  """
  @spec drive_list_files_for_user(pos_integer() | %{id: pos_integer()}, String.t()) ::
          {:ok, map()} | error()
  def drive_list_files_for_user(%{id: user_id}, folder_id),
    do: drive_list_files_for_user(user_id, folder_id)

  def drive_list_files_for_user(user_id, folder_id) when is_integer(user_id) do
    case Repo.get_by(ExternalIdentity, user_id: user_id, provider: "google") do
      %ExternalIdentity{token: token} when is_binary(token) and byte_size(token) > 0 ->
        Drive.list_files_in_folder(token, folder_id)

      _ ->
        {:error, :no_token}
    end
  end

  # Generic Linear GraphQL call using configured token
  @spec linear_graphql(String.t(), map()) :: {:ok, map()} | error()
  @doc """
  Make a raw Linear GraphQL request with the configured token.
  Convenience used by `sync_from_linear/0` and other helpers.
  """
  def linear_graphql(query, variables \\ %{}) do
    with {:ok, token} <- fetch!(:linear_token, "LINEAR_TOKEN") do
      case Linear.list_issues(strip_bearer(token), query, variables) do
        {:error, {:http_error, 429, body}} ->
          {:error, {:rate_limited, rate_limit_message(body)}}

        other ->
          other
      end
    end
  end

  defp strip_bearer(token) when is_binary(token) do
    token
    |> String.trim()
    |> String.replace_prefix("Bearer ", "")
    |> String.replace_prefix("bearer ", "")
  end

  defp strip_bearer(other), do: other

  defp rate_limit_message(%{"errors" => errors}) when is_list(errors) do
    errors
    |> Enum.find(&matches_rate_limit?/1)
    |> case do
      nil -> default_rate_limit_message()
      error -> extract_rate_limit_message(error)
    end
  end

  defp rate_limit_message(%{errors: errors}) when is_list(errors) do
    rate_limit_message(%{"errors" => errors})
  end

  defp rate_limit_message(_), do: default_rate_limit_message()

  defp matches_rate_limit?(error) do
    case get_in(error, ["extensions", "code"]) || get_in(error, [:extensions, :code]) do
      nil ->
        String.contains?(
          String.downcase(to_string(error["message"] || error[:message] || "")),
          "ratelimit"
        )

      code ->
        String.upcase(to_string(code)) == "RATELIMITED"
    end
  end

  defp extract_rate_limit_message(error) do
    get_in(error, ["extensions", "userPresentableMessage"]) ||
      get_in(error, [:extensions, :userPresentableMessage]) ||
      error["message"] ||
      error[:message] ||
      default_rate_limit_message()
  end

  defp default_rate_limit_message,
    do: "Linear API rate limit exceeded. Please wait before retrying."

  # Google Calendar (user/env token helper)
  @doc """
  List upcoming calendar events for a user between `start_at` and `end_at`.

  Token precedence:
    1. User's ExternalIdentity with provider "google" (uses its `token`)
    2. Env var `GOOGLE_OAUTH_TOKEN`

  Options are forwarded to the GoogleCalendar client (e.g., `mock: :sample`).
  Returns `{:error, :no_token}` when no usable token is available and `:mock`
  is not set.
  """
  @spec calendar_list_upcoming_for_user(
          pos_integer() | %{id: pos_integer()},
          DateTime.t(),
          DateTime.t(),
          keyword()
        ) ::
          {:ok, list()} | {:error, term()}
  def calendar_list_upcoming_for_user(user_or_id, start_at, end_at, opts \\ []) do
    # Allow mock path without token and without caching (deterministic QA)
    if Keyword.get(opts, :mock) == :sample do
      GoogleCalendar.list_upcoming(start_at, end_at, opts)
    else
      user_id =
        case user_or_id do
          %{id: id} -> id
          id when is_integer(id) -> id
          _ -> nil
        end

      key =
        {:gcal, user_id,
         {Date.to_iso8601(DateTime.to_date(start_at)), Date.to_iso8601(DateTime.to_date(end_at))}}

      ttl = Keyword.get(opts, :ttl, :timer.minutes(5))

      MeetingsCache.fetch(
        key,
        fn -> fetch_calendar_list_for_user(user_id, start_at, end_at, opts) end,
        ttl: ttl
      )
    end
  end

  defp fetch_calendar_list_for_user(user_id, start_at, end_at, opts) when is_integer(user_id) do
    case GoogleToken.get_access_token_for_user(user_id) do
      {:ok, token} ->
        GoogleCalendar.list_upcoming(start_at, end_at, Keyword.put(opts, :token, token))

      {:error, _} = err ->
        err
    end
  end

  defp fetch_calendar_list_for_user(_user_id, _start_at, _end_at, _opts), do: {:error, :no_token}

  # Deprecated: fetching tokens without refresh moved to GoogleToken helper.
end
