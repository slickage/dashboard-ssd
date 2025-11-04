defmodule DashboardSSD.Integrations do
  @moduledoc """
  Convenience wrappers around external integrations using tokens from runtime config.

  Tokens are read from `Application.get_env(:dashboard_ssd, :integrations)` which is
  populated in `config/runtime.exs` from environment variables (see `.env.example`).
  """

  alias DashboardSSD.Accounts.ExternalIdentity
  alias DashboardSSD.Integrations.{Drive, Linear, Notion, Slack, GoogleCalendar}
  alias DashboardSSD.Repo

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
      Linear.list_issues(strip_bearer(token), query, variables)
    end
  end

  defp strip_bearer(token) when is_binary(token) do
    token
    |> String.trim()
    |> String.replace_prefix("Bearer ", "")
    |> String.replace_prefix("bearer ", "")
  end

  defp strip_bearer(other), do: other

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
  @spec calendar_list_upcoming_for_user(pos_integer() | %{id: pos_integer()}, DateTime.t(), DateTime.t(), keyword()) ::
          {:ok, list()} | {:error, term()}
  def calendar_list_upcoming_for_user(user_or_id, start_at, end_at, opts \\ []) do
    # Allow mock path without token
    if Keyword.get(opts, :mock) == :sample do
      GoogleCalendar.list_upcoming(start_at, end_at, opts)
    else
      token =
        case user_or_id do
          %{id: id} -> fetch_google_token_for_user(id)
          id when is_integer(id) -> fetch_google_token_for_user(id)
          _ -> nil
        end

      if is_nil(token) or token == "" do
        {:error, :no_token}
      else
        GoogleCalendar.list_upcoming(start_at, end_at, Keyword.put(opts, :token, token))
      end
    end
  end

  defp fetch_google_token_for_user(user_id) when is_integer(user_id) do
    case Repo.get_by(ExternalIdentity, user_id: user_id, provider: "google") do
      %ExternalIdentity{token: token} when is_binary(token) and byte_size(token) > 0 -> token
      _ -> nil
    end
  end
end
