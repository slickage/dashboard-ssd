defmodule DashboardSSD.IntegrationsTest do
  use DashboardSSD.DataCase, async: false

  alias DashboardSSD.Accounts
  alias DashboardSSD.Accounts.ExternalIdentity
  alias DashboardSSD.Integrations
  alias DashboardSSD.Repo
  import Tesla.Mock

  @moduletag :tmp_dir

  @service_account_pem """
  -----BEGIN PRIVATE KEY-----
  MIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQCoud2XdpSkNZx7
  KGmObvp6uX9GfFHH0TzCfHhi+okpkmY5P54KujKKrGtJ7qm+uOjsfyuJo2oeIkai
  Rm3/l+tq49gi2EecHcTix73ftCy0dsdt35+MMlY98MRVj43lHH1k9rmiOSBXzpe4
  yKAU7i9JrfDivLL9V/EjZDaXrbHmQUXnJ9zV6YEJs8G8t3QsSAu6PDu6lp5l0UIQ
  8WuURGiTP4e0LQVUL3Uy3amCMF1jQ7NSzMdLenefYLn4uSzv2SLu/jqTJdqjhiC/
  0frf3PrUMpv7qEPeNBt8PxnUJlwbLzesB1dMvyzZdSJ98Pn/BIq8Wdh+jeScSPPV
  QwACdzVhAgMBAAECggEAEwiMj8aHtBJ8KYSAi9nHFcsRKYFitFjNMt9ZsUiz6mWi
  dHjRukIQ64XRwJBUw7gWRn9+CNPPZ8DUGQA67mdT3kX/nsapJVpSWIbRy4eGt4Di
  tGlSlT0kb25Wp5Q/HIZfOuF+RWeOV3ltsiGntVS9LuGZV+qTgnLGOAjZA7lLZT7u
  0ksMU0NRNbQI5/BFIWQqkD2H+teYxFB+9ZD7dt7q6SDO23tpwXXTpENSw/rwKvfj
  jZHRfSEuRrLZ6A7LSkwfIDhyvsBPqRNCBerxQhL5rsZ3QhcD2fa04h2/U/VTpLZF
  yRafBM+z+7LhSfE1fI/v0+kuO/OxWu3p3nm6sI90FQKBgQDaV39wV4d1xPSNUv6y
  GJVSQ+SOfxpKnkzsc+GENjzowG/R7ZDxDGQZlUUUyfsHjT1U+rUQ+GH3I9+/7b41
  SuIHztfZ5ApnWZ3s1aqtvg7hJf6GFOnsWBnPlJ5UvdUboQ3qfnmuHKbuPY7USpma
  eceDFX++D5EKH2avhF+C1Vu5qwKBgQDF06uoSMrPXM3vVRPlGNAOLmsPdQ0Malw5
  +o7YuZr8GXX9uK4coUkwrLHboDjK+80lZp+No6Z+neJlqvgUzCYvO3N1l48FrgR9
  bCVSSnvwIuR54sla/MBXBrx01MefN1Y6vmKvRG47PHis+1TmVSk1pGSka0Afr7Ue
  qZ4ox4F5IwKBgHiuCesPBfkK7lw6djn7qnS4v9ge2mpJypyahBguXkYLLwLp+sWw
  opcdUPxnkw8eerrAg1mo34TY2C/d+Na91+aW5ekxyKpM9yPTCS5UsSayeFalspGG
  NGXucADIl8RYpTdpxll8zqs5bPtbbEDcdHC4bk2fjvv4VSpH0P6gbL1XAoGAUg5q
  tXL8LOchxJRVnEGei0NVxSOYNf4oIyR6/AqA7vDgsE1aayW7ZiU74Q2kgQ3RGiJn
  LCkldn+m2OUB4h6L+CuAyNYEzSZRVnT1Rhz/K6xNeQFI5CTS40Y4BX39D120tskh
  xfFsh8WdiKL3pFLOtSFrXYffIUWQqxdQMzoNymECgYAWwjrYjpmILUDFertjdIeO
  DRbAlhFUBIsf+MjNn8LFcYi8NdSjB0pBxFRmPxpPaML5FsEUKt4i36lGfzAFunWv
  oXnbh1iMnQiJTJfofkVFHKDEngS2HIYu0DpUH285CihhRTbsAJQPhyd7Tqz9V22j
  POsYo2bqqH+AGPh6e4M4aA==
  -----END PRIVATE KEY-----
  """

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

  test "notion_search executes request when token configured" do
    mock(fn %{method: :post, url: "https://api.notion.com/v1/search"} ->
      {:ok, %Tesla.Env{status: 200, body: %{"results" => []}}}
    end)

    System.put_env("NOTION_TOKEN", "notion-secret")

    assert {:ok, %{"results" => []}} = Integrations.notion_search("project")
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

    test "returns error when service account file unreadable", %{tmp_dir: tmp_dir} do
      Application.put_env(:dashboard_ssd, :test_env?, false)
      missing_path = Path.join(tmp_dir, "missing.json")
      System.put_env("DRIVE_SERVICE_ACCOUNT_JSON", missing_path)
      System.delete_env("GOOGLE_DRIVE_TOKEN")
      System.delete_env("GOOGLE_OAUTH_TOKEN")

      assert {:error, {:unreadable_service_account, _}} = Integrations.drive_service_token()
    after
      Application.put_env(:dashboard_ssd, :test_env?, true)
    end

    test "returns error when service account json missing keys", %{tmp_dir: tmp_dir} do
      Application.put_env(:dashboard_ssd, :test_env?, false)
      path = Path.join(tmp_dir, "missing-keys.json")
      File.write!(path, Jason.encode!(%{"client_email" => "bot@example.com"}))

      System.put_env("DRIVE_SERVICE_ACCOUNT_JSON", path)
      System.delete_env("GOOGLE_DRIVE_TOKEN")
      System.delete_env("GOOGLE_OAUTH_TOKEN")

      assert {:error, :invalid_service_account_json} = Integrations.drive_service_token()
    after
      Application.put_env(:dashboard_ssd, :test_env?, true)
    end

    test "returns error when JWT signing fails", %{tmp_dir: tmp_dir} do
      Application.put_env(:dashboard_ssd, :test_env?, false)
      path = Path.join(tmp_dir, "bad-pem.json")

      File.write!(
        path,
        Jason.encode!(%{"client_email" => "bot@example.com", "private_key" => "invalid"})
      )

      System.put_env("DRIVE_SERVICE_ACCOUNT_JSON", path)
      System.delete_env("GOOGLE_DRIVE_TOKEN")
      System.delete_env("GOOGLE_OAUTH_TOKEN")

      assert {:error, {:jwt_sign_exception, _}} = Integrations.drive_service_token()
    after
      Application.put_env(:dashboard_ssd, :test_env?, true)
    end

    test "mints token from service account", %{tmp_dir: tmp_dir} do
      Application.put_env(:dashboard_ssd, :test_env?, false)
      System.delete_env("GOOGLE_DRIVE_TOKEN")
      System.delete_env("GOOGLE_OAUTH_TOKEN")

      path = Path.join(tmp_dir, "service-account.json")

      File.write!(
        path,
        Jason.encode!(%{
          "client_email" => "bot@example.com",
          "private_key" => @service_account_pem
        })
      )

      System.put_env("DRIVE_SERVICE_ACCOUNT_JSON", path)

      mock(fn %{method: :post, url: "https://oauth2.googleapis.com/token"} ->
        {:ok, %Tesla.Env{status: 200, body: %{"access_token" => "minted-token"}}}
      end)

      assert {:ok, "minted-token"} = Integrations.drive_service_token()
    after
      Application.put_env(:dashboard_ssd, :test_env?, true)
    end

    test "returns error when service account json missing" do
      Application.put_env(:dashboard_ssd, :test_env?, false)
      System.delete_env("DRIVE_SERVICE_ACCOUNT_JSON")
      System.delete_env("GOOGLE_APPLICATION_CREDENTIALS")
      System.delete_env("GOOGLE_DRIVE_TOKEN")
      System.delete_env("GOOGLE_OAUTH_TOKEN")
      Application.delete_env(:dashboard_ssd, :shared_documents_integrations)

      assert {:error, :missing_service_account_json} = Integrations.drive_service_token()
    after
      Application.put_env(:dashboard_ssd, :test_env?, true)
    end

    test "reads service account path from shared_documents config", %{tmp_dir: tmp_dir} do
      Application.put_env(:dashboard_ssd, :test_env?, false)

      Application.put_env(:dashboard_ssd, :shared_documents_integrations, %{
        drive: %{service_account_json_path: Path.join(tmp_dir, "config-sa.json")}
      })

      path = Path.join(tmp_dir, "config-sa.json")

      pem = """
      -----BEGIN PRIVATE KEY-----
      MIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQCoud2XdpSkNZx7
      KGmObvp6uX9GfFHH0TzCfHhi+okpkmY5P54KujKKrGtJ7qm+uOjsfyuJo2oeIkai
      Rm3/l+tq49gi2EecHcTix73ftCy0dsdt35+MMlY98MRVj43lHH1k9rmiOSBXzpe4
      yKAU7i9JrfDivLL9V/EjZDaXrbHmQUXnJ9zV6YEJs8G8t3QsSAu6PDu6lp5l0UIQ
      8WuURGiTP4e0LQVUL3Uy3amCMF1jQ7NSzMdLenefYLn4uSzv2SLu/jqTJdqjhiC/
      0frf3PrUMpv7qEPeNBt8PxnUJlwbLzesB1dMvyzZdSJ98Pn/BIq8Wdh+jeScSPPV
      QwACdzVhAgMBAAECggEAEwiMj8aHtBJ8KYSAi9nHFcsRKYFitFjNMt9ZsUiz6mWi
      dHjRukIQ64XRwJBUw7gWRn9+CNPPZ8DUGQA67mdT3kX/nsapJVpSWIbRy4eGt4Di
      tGlSlT0kb25Wp5Q/HIZfOuF+RWeOV3ltsiGntVS9LuGZV+qTgnLGOAjZA7lLZT7u
      0ksMU0NRNbQI5/BFIWQqkD2H+teYxFB+9ZD7dt7q6SDO23tpwXXTpENSw/rwKvfj
      jZHRfSEuRrLZ6A7LSkwfIDhyvsBPqRNCBerxQhL5rsZ3QhcD2fa04h2/U/VTpLZF
      yRafBM+z+7LhSfE1fI/v0+kuO/OxWu3p3nm6sI90FQKBgQDaV39wV4d1xPSNUv6y
      GJVSQ+SOfxpKnkzsc+GENjzowG/R7ZDxDGQZlUUUyfsHjT1U+rUQ+GH3I9+/7b41
      SuIHztfZ5ApnWZ3s1aqtvg7hJf6GFOnsWBnPlJ5UvdUboQ3qfnmuHKbuPY7USpma
      eceDFX++D5EKH2avhF+C1Vu5qwKBgQDF06uoSMrPXM3vVRPlGNAOLmsPdQ0Malw5
      +o7YuZr8GXX9uK4coUkwrLHboDjK+80lZp+No6Z+neJlqvgUzCYvO3N1l48FrgR9
      bCVSSnvwIuR54sla/MBXBrx01MefN1Y6vmKvRG47PHis+1TmVSk1pGSka0Afr7Ue
      qZ4ox4F5IwKBgHiuCesPBfkK7lw6djn7qnS4v9ge2mpJypyahBguXkYLLwLp+sWw
      opcdUPxnkw8eerrAg1mo34TY2C/d+Na91+aW5ekxyKpM9yPTCS5UsSayeFalspGG
      NGXucADIl8RYpTdpxll8zqs5bPtbbEDcdHC4bk2fjvv4VSpH0P6gbL1XAoGAUg5q
      tXL8LOchxJRVnEGei0NVxSOYNf4oIyR6/AqA7vDgsE1aayW7ZiU74Q2kgQ3RGiJn
      LCkldn+m2OUB4h6L+CuAyNYEzSZRVnT1Rhz/K6xNeQFI5CTS40Y4BX39D120tskh
      xfFsh8WdiKL3pFLOtSFrXYffIUWQqxdQMzoNymECgYAWwjrYjpmILUDFertjdIeO
      DRbAlhFUBIsf+MjNn8LFcYi8NdSjB0pBxFRmPxpPaML5FsEUKt4i36lGfzAFunWv
      oXnbh1iMnQiJTJfofkVFHKDEngS2HIYu0DpUH285CihhRTbsAJQPhyd7Tqz9V22j
      POsYo2bqqH+AGPh6e4M4aA==
      -----END PRIVATE KEY-----
      """

      File.write!(
        path,
        Jason.encode!(%{"client_email" => "bot@example.com", "private_key" => pem})
      )

      mock(fn %{method: :post, url: "https://oauth2.googleapis.com/token"} ->
        {:ok, %Tesla.Env{status: 200, body: %{"access_token" => "cfg-minted"}}}
      end)

      System.delete_env("DRIVE_SERVICE_ACCOUNT_JSON")
      System.delete_env("GOOGLE_DRIVE_TOKEN")
      System.delete_env("GOOGLE_OAUTH_TOKEN")

      assert {:ok, "cfg-minted"} = Integrations.drive_service_token()
    after
      Application.put_env(:dashboard_ssd, :test_env?, true)
      Application.delete_env(:dashboard_ssd, :shared_documents_integrations)
    end

    test "mints token when response body is encoded string", %{tmp_dir: tmp_dir} do
      Application.put_env(:dashboard_ssd, :test_env?, false)
      System.delete_env("GOOGLE_DRIVE_TOKEN")
      System.delete_env("GOOGLE_OAUTH_TOKEN")

      path = Path.join(tmp_dir, "service-account-string.json")

      File.write!(
        path,
        Jason.encode!(%{
          "client_email" => "bot@example.com",
          "private_key" => @service_account_pem
        })
      )

      System.put_env("DRIVE_SERVICE_ACCOUNT_JSON", path)

      mock(fn %{method: :post, url: "https://oauth2.googleapis.com/token"} ->
        {:ok, %Tesla.Env{status: 200, body: Jason.encode!(%{"access_token" => "minted-string"})}}
      end)

      assert {:ok, "minted-string"} = Integrations.drive_service_token()
    after
      Application.put_env(:dashboard_ssd, :test_env?, true)
    end

    test "returns error when token exchange payload is invalid json", %{tmp_dir: tmp_dir} do
      Application.put_env(:dashboard_ssd, :test_env?, false)
      System.delete_env("GOOGLE_DRIVE_TOKEN")
      System.delete_env("GOOGLE_OAUTH_TOKEN")

      path = Path.join(tmp_dir, "invalid-response.json")

      File.write!(
        path,
        Jason.encode!(%{
          "client_email" => "bot@example.com",
          "private_key" => @service_account_pem
        })
      )

      System.put_env("DRIVE_SERVICE_ACCOUNT_JSON", path)

      mock(fn %{method: :post, url: "https://oauth2.googleapis.com/token"} ->
        {:ok, %Tesla.Env{status: 200, body: "not json"}}
      end)

      assert {:error, {:token_exchange_failed, 200, {:invalid_json, _}}} =
               Integrations.drive_service_token()
    after
      Application.put_env(:dashboard_ssd, :test_env?, true)
    end

    test "returns error when token exchange fails", %{tmp_dir: tmp_dir} do
      Application.put_env(:dashboard_ssd, :test_env?, false)
      System.delete_env("GOOGLE_DRIVE_TOKEN")
      System.delete_env("GOOGLE_OAUTH_TOKEN")

      path = Path.join(tmp_dir, "service-account-error.json")

      File.write!(
        path,
        Jason.encode!(%{
          "client_email" => "bot@example.com",
          "private_key" => @service_account_pem
        })
      )

      System.put_env("DRIVE_SERVICE_ACCOUNT_JSON", path)

      mock(fn %{method: :post, url: "https://oauth2.googleapis.com/token"} ->
        {:ok, %Tesla.Env{status: 500, body: %{"error" => "boom"}}}
      end)

      assert {:error, {:token_exchange_failed, 500, %{"error" => "boom"}}} =
               Integrations.drive_service_token()
    after
      Application.put_env(:dashboard_ssd, :test_env?, true)
    end
  end

  describe "drive helpers" do
    setup do
      Application.put_env(:dashboard_ssd, :integrations, drive_token: "svc-token")

      on_exit(fn ->
        Application.delete_env(:dashboard_ssd, :integrations)
      end)

      :ok
    end

    test "drive_download_file streams media" do
      mock(fn %{
                method: :get,
                url: "https://www.googleapis.com/drive/v3/files/file-1",
                query: query
              } ->
        assert query[:alt] == "media"
        {:ok, %Tesla.Env{status: 200, body: "bytes"}}
      end)

      assert {:ok, %Tesla.Env{body: "bytes"}} = Integrations.drive_download_file("file-1")
    end

    test "drive_share_folder posts permissions" do
      mock(fn
        %{method: :post, url: "https://www.googleapis.com/drive/v3/files/folder-9/permissions"} ->
          {:ok, %Tesla.Env{status: 200, body: %{"id" => "perm"}}}
      end)

      assert {:ok, %{"id" => "perm"}} =
               Integrations.drive_share_folder("folder-9", %{role: "reader", type: "anyone"})
    end

    test "drive_unshare_folder deletes permission" do
      mock(fn
        %{
          method: :delete,
          url: "https://www.googleapis.com/drive/v3/files/folder-9/permissions/perm-1"
        } ->
          {:ok, %Tesla.Env{status: 204, body: ""}}
      end)

      assert :ok = Integrations.drive_unshare_folder("folder-9", "perm-1")
    end

    test "drive_list_permissions returns permission list" do
      mock(fn
        %{method: :get, url: "https://www.googleapis.com/drive/v3/files/folder-9/permissions"} ->
          {:ok, %Tesla.Env{status: 200, body: %{"permissions" => [%{"id" => "1"}]}}}
      end)

      assert {:ok, [%{"id" => "1"}]} = Integrations.drive_list_permissions("folder-9")
    end

    test "env_drive_token helper returns tuple" do
      Application.put_env(:dashboard_ssd, :integrations, drive_token: "inline-token")
      assert {:ok, "inline-token"} = Integrations.env_drive_token()

      Application.put_env(:dashboard_ssd, :integrations, drive_token: "")

      assert {:error, {:missing_env, "GOOGLE_DRIVE_TOKEN/GOOGLE_OAUTH_TOKEN"}} =
               Integrations.env_drive_token()
    end
  end

  test "linear_graphql falls back to default message" do
    mock(fn %{method: :post, url: "https://api.linear.app/graphql"} ->
      {:ok,
       %Tesla.Env{
         status: 429,
         body: %{
           "errors" => [
             %{
               "extensions" => %{"code" => "RATELIMITED"},
               "message" => nil
             }
           ]
         }
       }}
    end)

    System.put_env("LINEAR_TOKEN", "linear-token")

    assert {:error, {:rate_limited, msg}} = Integrations.linear_graphql("{}", %{})
    assert msg =~ "Linear API rate limit exceeded"
  end
end
