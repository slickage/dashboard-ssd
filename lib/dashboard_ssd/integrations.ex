defmodule DashboardSSD.Integrations do
  @moduledoc """
  Convenience wrappers around external integrations using tokens from runtime config.

  Tokens are read from `Application.get_env(:dashboard_ssd, :integrations)` which is
  populated in `config/runtime.exs` from environment variables (see `.env.example`).
  """

  alias DashboardSSD.Accounts.ExternalIdentity
  alias DashboardSSD.Integrations.{Drive, Linear, Notion, Slack}
  alias DashboardSSD.Repo

  @type error :: {:error, term()}

  defp cfg, do: Application.get_env(:dashboard_ssd, :integrations, [])

  defp fetch!(key, env_key) do
    val = Keyword.get(cfg(), key) || System.get_env(env_key)
    if is_nil(val) or val == "", do: {:error, {:missing_env, env_key}}, else: {:ok, val}
  end

  # Linear
  @spec linear_list_issues(String.t(), map()) :: {:ok, map()} | error()
  def linear_list_issues(query, variables \\ %{}) do
    with {:ok, token} <- fetch!(:linear_token, "LINEAR_TOKEN") do
      Linear.list_issues(token, query, variables)
    end
  end

  # Slack
  @spec slack_send_message(String.t() | nil, String.t()) :: {:ok, map()} | error()
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
  def notion_search(query) do
    with {:ok, token} <- fetch!(:notion_token, "NOTION_TOKEN") do
      Notion.search(token, query)
    end
  end

  # Drive
  @spec drive_list_files_in_folder(String.t()) :: {:ok, map()} | error()
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
  List Drive files in a folder for a specific user using their stored Google token.

  Looks up `external_identities` by provider "google". Returns {:error, :no_token}
  if no token is present. Use `/auth/google` to sign in and store tokens.
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
end
