defmodule DashboardSSD.IntegrationsTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Integrations

  setup do
    prev = Application.get_env(:dashboard_ssd, :integrations)
    System.delete_env("LINEAR_TOKEN")
    System.delete_env("NOTION_TOKEN")
    System.delete_env("SLACK_BOT_TOKEN")
    System.delete_env("SLACK_CHANNEL")
    System.delete_env("GOOGLE_DRIVE_TOKEN")
    System.delete_env("GOOGLE_OAUTH_TOKEN")
    Application.put_env(:dashboard_ssd, :integrations, [])

    on_exit(fn ->
      case prev do
        nil -> Application.delete_env(:dashboard_ssd, :integrations)
        v -> Application.put_env(:dashboard_ssd, :integrations, v)
      end
    end)

    :ok
  end

  test "linear endpoints error when token missing" do
    assert {:error, {:missing_env, "LINEAR_TOKEN"}} = Integrations.linear_graphql("query {}", %{})

    assert {:error, {:missing_env, "LINEAR_TOKEN"}} =
             Integrations.linear_list_issues("query {}", %{})
  end

  test "notion search errors when token missing" do
    assert {:error, {:missing_env, "NOTION_TOKEN"}} = Integrations.notion_search("hello")
  end

  test "slack requires token and channel" do
    assert {:error, {:missing_env, "SLACK_BOT_TOKEN"}} =
             Integrations.slack_send_message(nil, "hi")

    Application.put_env(:dashboard_ssd, :integrations, slack_bot_token: "tok")
    assert {:error, {:missing_env, "SLACK_CHANNEL"}} = Integrations.slack_send_message(nil, "hi")
  end

  test "drive requires token" do
    assert {:error, {:missing_env, "GOOGLE_DRIVE_TOKEN/GOOGLE_OAUTH_TOKEN"}} =
             Integrations.drive_list_files_in_folder("folder")
  end

  test "drive_list_files_for_user returns :no_token without identity" do
    # Just check error path, no DB lookup side effects
    assert {:error, :no_token} = Integrations.drive_list_files_for_user(12_345, "folder")
  end

  test "calendar list upcoming supports mock without token" do
    now = DateTime.utc_now()

    assert {:ok, list} =
             Integrations.calendar_list_upcoming_for_user(
               123,
               now,
               DateTime.add(now, 3600, :second),
               mock: :sample
             )

    assert is_list(list) and length(list) > 0
  end
end
