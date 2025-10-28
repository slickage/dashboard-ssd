defmodule DashboardSSD.Integrations.WrappersTest do
  use DashboardSSD.DataCase

  alias DashboardSSD.Accounts.{ExternalIdentity, User}
  alias DashboardSSD.Integrations
  alias DashboardSSD.Repo

  setup do
    # Ensure Tesla uses the mock adapter
    Application.put_env(:tesla, :adapter, Tesla.Mock)

    # Clear env-backed fallbacks used by the wrappers to avoid accidental leakage
    prev_env = %{
      "LINEAR_TOKEN" => System.get_env("LINEAR_TOKEN"),
      "SLACK_BOT_TOKEN" => System.get_env("SLACK_BOT_TOKEN"),
      "SLACK_CHANNEL" => System.get_env("SLACK_CHANNEL"),
      "NOTION_TOKEN" => System.get_env("NOTION_TOKEN"),
      "GOOGLE_DRIVE_TOKEN" => System.get_env("GOOGLE_DRIVE_TOKEN"),
      "GOOGLE_OAUTH_TOKEN" => System.get_env("GOOGLE_OAUTH_TOKEN")
    }

    Enum.each(prev_env, fn {k, _} -> System.delete_env(k) end)

    # Reset application config for integrations per test
    prev_cfg = Application.get_env(:dashboard_ssd, :integrations)
    Application.put_env(:dashboard_ssd, :integrations, [])

    on_exit(fn ->
      Enum.each(prev_env, fn
        {_k, nil} -> :ok
        {k, v} -> System.put_env(k, v)
      end)

      if prev_cfg do
        Application.put_env(:dashboard_ssd, :integrations, prev_cfg)
      else
        Application.delete_env(:dashboard_ssd, :integrations)
      end
    end)

    :ok
  end

  describe "slack_send_message/2" do
    test "uses configured token and default channel" do
      Application.put_env(:dashboard_ssd, :integrations,
        slack_bot_token: "tok",
        slack_channel: "C123"
      )

      Tesla.Mock.mock(fn
        %{
          method: :post,
          url: "https://slack.com/api/chat.postMessage",
          headers: headers,
          body: body
        } ->
          assert Enum.any?(headers, fn {k, v} ->
                   k == "authorization" and String.starts_with?(v, "Bearer ")
                 end)

          body = if is_binary(body), do: Jason.decode!(body), else: body
          assert body["channel"] == "C123"
          assert body["text"] == "Hello"
          %Tesla.Env{status: 200, body: %{"ok" => true}}
      end)

      assert {:ok, %{"ok" => true}} = Integrations.slack_send_message(nil, "Hello")
    end

    test "errors when channel missing" do
      Application.put_env(:dashboard_ssd, :integrations, slack_bot_token: "tok")

      assert {:error, {:missing_env, "SLACK_CHANNEL"}} =
               Integrations.slack_send_message(nil, "Hi")
    end

    test "uses env var token and channel when not configured" do
      Application.put_env(:dashboard_ssd, :integrations, [])

      System.put_env("SLACK_BOT_TOKEN", "tok-env")
      System.put_env("SLACK_CHANNEL", "CENV")

      Tesla.Mock.mock(fn
        %{method: :post, url: "https://slack.com/api/chat.postMessage", body: body} ->
          body = if is_binary(body), do: Jason.decode!(body), else: body
          assert body["channel"] == "CENV"
          %Tesla.Env{status: 200, body: %{"ok" => true}}
      end)

      assert {:ok, %{"ok" => true}} = Integrations.slack_send_message(nil, "Hello")
    end
  end

  describe "linear_list_issues/2" do
    test "posts GraphQL with token" do
      Application.put_env(:dashboard_ssd, :integrations, linear_token: "tok")

      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.linear.app/graphql", headers: headers, body: body} ->
          assert Enum.any?(headers, fn {k, v} -> k == "authorization" and v == "tok" end)

          body = if is_binary(body), do: Jason.decode!(body), else: body
          assert Map.has_key?(body, "query") or Map.has_key?(body, :query)
          %Tesla.Env{status: 200, body: %{"data" => %{"issues" => []}}}
      end)

      assert {:ok, %{"data" => %{"issues" => []}}} =
               Integrations.linear_list_issues("{ issues { id } }", %{})
    end

    test "errors when missing token" do
      Application.put_env(:dashboard_ssd, :integrations, [])

      assert {:error, {:missing_env, "LINEAR_TOKEN"}} =
               Integrations.linear_list_issues("{ q }", %{})
    end

    test "uses env var token when not configured" do
      Application.put_env(:dashboard_ssd, :integrations, [])
      System.put_env("LINEAR_TOKEN", "tok-env")

      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.linear.app/graphql", headers: headers} ->
          assert Enum.any?(headers, fn {k, v} -> k == "authorization" and v == "tok-env" end)

          %Tesla.Env{status: 200, body: %{"data" => %{"issues" => []}}}
      end)

      assert {:ok, %{"data" => _}} = Integrations.linear_list_issues("{ issues { id } }", %{})
    end

    test "strips 'Bearer ' prefix from token if present" do
      Application.put_env(:dashboard_ssd, :integrations, linear_token: "Bearer tok")

      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.linear.app/graphql", headers: headers} ->
          assert Enum.any?(headers, fn {k, v} -> k == "authorization" and v == "tok" end)
          %Tesla.Env{status: 200, body: %{"data" => %{"issues" => []}}}
      end)

      assert {:ok, %{"data" => _}} = Integrations.linear_list_issues("{ issues { id } }", %{})
    end
  end

  describe "linear_graphql/2" do
    test "returns rate_limited error with user presentable message" do
      Application.put_env(:dashboard_ssd, :integrations, linear_token: "tok")

      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.linear.app/graphql"} ->
          %Tesla.Env{
            status: 429,
            body: %{
              "errors" => [
                %{
                  "message" => "ratelimit exceeded",
                  "extensions" => %{
                    "code" => "RATELIMITED",
                    "userPresentableMessage" =>
                      "This IP address has been rate limited due to unusual activity. Please try again later."
                  }
                }
              ]
            }
          }
      end)

      assert {:error, {:rate_limited, msg}} =
               Integrations.linear_graphql("{ issues { id } }", %{})

      assert msg ==
               "This IP address has been rate limited due to unusual activity. Please try again later."
    end

    test "returns message when only error string present" do
      Application.put_env(:dashboard_ssd, :integrations, linear_token: "tok")

      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.linear.app/graphql"} ->
          %Tesla.Env{
            status: 429,
            body: %{
              "errors" => [
                %{
                  "message" => "RateLimit exceeded"
                }
              ]
            }
          }
      end)

      assert {:error, {:rate_limited, msg}} =
               Integrations.linear_graphql("{ issues { id } }", %{})

      assert msg == "RateLimit exceeded"
    end

    test "uses default message when response missing details" do
      Application.put_env(:dashboard_ssd, :integrations, linear_token: "tok")

      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.linear.app/graphql"} ->
          %Tesla.Env{status: 429, body: %{"message" => "too many requests"}}
      end)

      assert {:error, {:rate_limited, msg}} =
               Integrations.linear_graphql("{ issues { id } }", %{})

      assert msg == "Linear API rate limit exceeded. Please wait before retrying."
    end
  end

  describe "notion_search/1" do
    test "posts search with token" do
      Application.put_env(:dashboard_ssd, :integrations, notion_token: "tok")

      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.notion.com/v1/search", headers: headers, body: body} ->
          assert Enum.any?(headers, fn {k, v} ->
                   k == "authorization" and String.starts_with?(v, "Bearer ")
                 end)

          _ = if is_binary(body), do: Jason.decode!(body), else: body
          %Tesla.Env{status: 200, body: %{"results" => []}}
      end)

      assert {:ok, %{"results" => []}} = Integrations.notion_search("dashboard")
    end

    test "posts search with options" do
      Application.put_env(:dashboard_ssd, :integrations, notion_token: "tok")

      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.notion.com/v1/search", body: body} ->
          decoded_body = if is_binary(body), do: Jason.decode!(body), else: body
          assert decoded_body["query"] == "test query"
          assert decoded_body["filter"] == %{"property" => "object", "value" => "page"}
          %Tesla.Env{status: 200, body: %{"results" => []}}
      end)

      assert {:ok, %{"results" => []}} =
               Integrations.notion_search("test query",
                 body: %{filter: %{property: "object", value: "page"}}
               )
    end

    test "errors when missing token" do
      Application.put_env(:dashboard_ssd, :integrations, [])
      assert {:error, {:missing_env, "NOTION_TOKEN"}} = Integrations.notion_search("q")
    end
  end

  describe "drive_list_files_in_folder/1" do
    test "gets with q param using configured token" do
      Application.put_env(:dashboard_ssd, :integrations, drive_token: "tok")

      Tesla.Mock.mock(fn
        %{
          method: :get,
          url: "https://www.googleapis.com/drive/v3/files",
          headers: headers,
          query: query
        } ->
          assert Enum.any?(headers, fn {k, v} ->
                   k == "authorization" and String.starts_with?(v, "Bearer ")
                 end)

          assert Enum.any?(query, fn {k, _v} -> k == :q end)
          %Tesla.Env{status: 200, body: %{"files" => []}}
      end)

      assert {:ok, %{"files" => []}} = Integrations.drive_list_files_in_folder("folder123")
    end

    test "errors when missing token envs" do
      Application.put_env(:dashboard_ssd, :integrations, [])

      assert {:error, {:missing_env, "GOOGLE_DRIVE_TOKEN/GOOGLE_OAUTH_TOKEN"}} =
               Integrations.drive_list_files_in_folder("folder123")
    end

    test "uses env var oauth token when not configured" do
      Application.put_env(:dashboard_ssd, :integrations, [])
      System.put_env("GOOGLE_OAUTH_TOKEN", "tok-env")

      Tesla.Mock.mock(fn
        %{
          method: :get,
          url: "https://www.googleapis.com/drive/v3/files",
          headers: headers,
          query: query
        } ->
          assert Enum.any?(headers, fn {k, v} ->
                   k == "authorization" and String.starts_with?(v, "Bearer ")
                 end)

          assert Enum.any?(query, fn {k, _v} -> k == :q end)
          %Tesla.Env{status: 200, body: %{"files" => []}}
      end)

      assert {:ok, %{"files" => []}} = Integrations.drive_list_files_in_folder("folder123")
    end
  end

  describe "drive_list_files_for_user/2" do
    test "uses user's stored google token if present" do
      # Insert a user and a google identity with a token
      user = Repo.insert!(%User{name: "U", email: "u@example.com"})

      Repo.insert!(
        %ExternalIdentity{}
        |> ExternalIdentity.changeset(%{
          user_id: user.id,
          provider: "google",
          provider_id: "uid-1",
          token: "tok"
        })
      )

      Tesla.Mock.mock(fn
        %{
          method: :get,
          url: "https://www.googleapis.com/drive/v3/files",
          headers: headers,
          query: query
        } ->
          assert Enum.any?(headers, fn {k, v} ->
                   k == "authorization" and String.starts_with?(v, "Bearer ")
                 end)

          assert Enum.any?(query, fn {k, _v} -> k == :q end)
          %Tesla.Env{status: 200, body: %{"files" => []}}
      end)

      assert {:ok, %{"files" => []}} =
               Integrations.drive_list_files_for_user(user.id, "folder123")
    end

    test "returns :no_token when user has no google token" do
      user = Repo.insert!(%User{name: "U2", email: "u2@example.com"})
      assert {:error, :no_token} = Integrations.drive_list_files_for_user(user.id, "folder123")
    end

    test "accepts map with :id for user param" do
      user = Repo.insert!(%User{name: "U3", email: "u3@example.com"})

      Repo.insert!(
        %ExternalIdentity{}
        |> ExternalIdentity.changeset(%{user_id: user.id, provider: "google", token: "tok"})
      )

      Tesla.Mock.mock(fn
        %{method: :get, url: "https://www.googleapis.com/drive/v3/files"} ->
          %Tesla.Env{status: 200, body: %{"files" => []}}
      end)

      assert {:ok, %{"files" => []}} =
               Integrations.drive_list_files_for_user(%{id: user.id}, "folder123")
    end
  end

  describe "slack_send_message/2 variations" do
    test "explicit channel param overrides default" do
      Application.put_env(:dashboard_ssd, :integrations,
        slack_bot_token: "tok",
        slack_channel: "CDEFAULT"
      )

      Tesla.Mock.mock(fn
        %{method: :post, url: "https://slack.com/api/chat.postMessage", body: body} ->
          body = if is_binary(body), do: Jason.decode!(body), else: body
          assert body["channel"] == "C999"
          %Tesla.Env{status: 200, body: %{"ok" => true}}
      end)

      assert {:ok, %{"ok" => true}} = Integrations.slack_send_message("C999", "Hello")
    end

    test "errors when missing token" do
      Application.put_env(:dashboard_ssd, :integrations, [])

      assert {:error, {:missing_env, "SLACK_BOT_TOKEN"}} =
               Integrations.slack_send_message("C1", "Hi")
    end
  end
end
