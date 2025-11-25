defmodule DashboardSSD.IntegrationsTest do
  use DashboardSSD.DataCase, async: false

  alias DashboardSSD.Accounts
  alias DashboardSSD.Accounts.ExternalIdentity
  alias DashboardSSD.Integrations
  alias DashboardSSD.Repo
  import Tesla.Mock

  @moduletag :tmp_dir

  setup do
    previous_env =
      for key <- [
            "LINEAR_TOKEN",
            "SLACK_BOT_TOKEN",
            "SLACK_CHANNEL",
            "NOTION_TOKEN",
            "GOOGLE_DRIVE_TOKEN",
            "GOOGLE_OAUTH_TOKEN"
          ],
          into: %{} do
        {key, System.get_env(key)}
      end

    Enum.each(Map.keys(previous_env), &System.delete_env/1)
    Application.delete_env(:dashboard_ssd, :integrations)

    on_exit(fn ->
      Enum.each(previous_env, fn
        {key, nil} -> System.delete_env(key)
        {key, value} -> System.put_env(key, value)
      end)

      Application.delete_env(:dashboard_ssd, :integrations)
    end)

    :ok
  end

  test "linear_list_issues returns error when token missing" do
    assert {:error, {:missing_env, "LINEAR_TOKEN"}} =
             Integrations.linear_list_issues("query {}", %{})
  end

  test "linear_list_issues executes request when token present" do
    mock(fn %{method: :post, url: "https://api.linear.app/graphql"} ->
      {:ok, %Tesla.Env{status: 200, body: %{"data" => %{}}}}
    end)

    System.put_env("LINEAR_TOKEN", "token")

    assert {:ok, %{"data" => %{}}} = Integrations.linear_list_issues("query {}", %{})
  end

  test "linear_list_issues strips bearer prefix" do
    mock(fn %{method: :post, headers: headers} ->
      assert {"authorization", "abc-123"} in headers
      {:ok, %Tesla.Env{status: 200, body: %{"data" => %{}}}}
    end)

    Application.put_env(:dashboard_ssd, :integrations, linear_token: "Bearer abc-123")

    assert {:ok, %{"data" => %{}}} = Integrations.linear_list_issues("query {}", %{})
  end

  test "linear_graphql reports rate limit message" do
    mock(fn %{method: :post, url: "https://api.linear.app/graphql"} ->
      {:ok,
       %Tesla.Env{
         status: 429,
         body: %{
           "errors" => [
             %{
               "extensions" => %{"code" => "RATELIMITED", "userPresentableMessage" => "slow down"}
             }
           ]
         }
       }}
    end)

    System.put_env("LINEAR_TOKEN", "token")

    assert {:error, {:rate_limited, message}} =
             Integrations.linear_graphql("query {}", %{})

    assert message =~ "slow down"
  end

  test "slack_send_message returns error when channel missing" do
    Application.put_env(:dashboard_ssd, :integrations, slack_bot_token: "token")
    System.put_env("SLACK_CHANNEL", "")

    assert {:error, {:missing_env, "SLACK_CHANNEL"}} =
             Integrations.slack_send_message(nil, "text")
  after
    System.delete_env("SLACK_CHANNEL")
  end

  test "slack_send_message sends when config present" do
    mock(fn %{method: :post, url: "https://slack.com/api/chat.postMessage"} ->
      {:ok, %Tesla.Env{status: 200, body: %{"ok" => true}}}
    end)

    Application.put_env(:dashboard_ssd, :integrations,
      slack_bot_token: "token",
      slack_channel: "alerts"
    )

    assert {:ok, %{"ok" => true}} = Integrations.slack_send_message(nil, "ping")
  end

  test "notion_search returns error when token missing" do
    assert {:error, {:missing_env, "NOTION_TOKEN"}} =
             Integrations.notion_search("project")
  end

  test "drive_list_files_in_folder returns error without tokens" do
    assert {:error, {:missing_env, "GOOGLE_DRIVE_TOKEN/GOOGLE_OAUTH_TOKEN"}} =
             Integrations.drive_list_files_in_folder("folder")
  end

  test "drive_list_files_in_folder lists files with config token" do
    mock(fn %{method: :get, url: "https://www.googleapis.com/drive/v3/files"} ->
      {:ok, %Tesla.Env{status: 200, body: %{"files" => []}}}
    end)

    Application.put_env(:dashboard_ssd, :integrations, drive_token: "drive-token")

    assert {:ok, %{"files" => []}} = Integrations.drive_list_files_in_folder("abc123")
  end

  test "drive_list_files_for_user returns :no_token when identity missing" do
    Accounts.ensure_role!("employee")

    {:ok, user} =
      Accounts.create_user(%{
        email: "integration@example.com",
        name: "Integration",
        role_id: Accounts.ensure_role!("employee").id
      })

    assert {:error, :no_token} = Integrations.drive_list_files_for_user(user.id, "folder")
  end

  test "drive_list_files_for_user uses stored OAuth token" do
    mock(fn %{method: :get, url: "https://www.googleapis.com/drive/v3/files"} ->
      {:ok, %Tesla.Env{status: 200, body: %{"files" => ["doc"]}}}
    end)

    Accounts.ensure_role!("employee")

    {:ok, user} =
      Accounts.create_user(%{
        email: "drive-user@example.com",
        name: "Drive User",
        role_id: Accounts.ensure_role!("employee").id
      })

    %ExternalIdentity{}
    |> ExternalIdentity.changeset(%{
      user_id: user.id,
      provider: "google",
      token: "user-token"
    })
    |> Repo.insert!()

    assert {:ok, %{"files" => ["doc"]}} =
             Integrations.drive_list_files_for_user(user, "folder-1")
  end

  describe "drive_service_token/0" do
    setup do
      original_test_env = Application.get_env(:dashboard_ssd, :test_env?, true)

      on_exit(fn ->
        Application.put_env(:dashboard_ssd, :test_env?, original_test_env)
        System.delete_env("GOOGLE_DRIVE_TOKEN")
        System.delete_env("GOOGLE_OAUTH_TOKEN")
        System.delete_env("DRIVE_SERVICE_ACCOUNT_JSON")
      end)

      :ok
    end

    test "prefers explicit env tokens" do
      System.put_env("GOOGLE_DRIVE_TOKEN", "env-token")
      assert {:ok, "env-token"} = Integrations.drive_service_token()
    end

    test "returns stub token when running in test env without creds" do
      Application.put_env(:dashboard_ssd, :test_env?, true)
      System.delete_env("GOOGLE_DRIVE_TOKEN")
      System.delete_env("GOOGLE_OAUTH_TOKEN")

      assert {:ok, "drive-test-token"} = Integrations.drive_service_token()
    end

    test "returns error when service account json invalid", %{tmp_dir: tmp_dir} do
      Application.put_env(:dashboard_ssd, :test_env?, false)
      path = Path.join(tmp_dir, "invalid-sa.json")
      File.write!(path, "not json")
      System.put_env("DRIVE_SERVICE_ACCOUNT_JSON", path)
      System.delete_env("GOOGLE_DRIVE_TOKEN")
      System.delete_env("GOOGLE_OAUTH_TOKEN")

      assert {:error, {:invalid_json, _}} = Integrations.drive_service_token()
    end
  end
end
