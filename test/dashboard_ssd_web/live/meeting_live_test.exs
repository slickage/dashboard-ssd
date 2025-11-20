defmodule DashboardSSDWeb.MeetingLiveTest do
  use DashboardSSDWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts
  alias DashboardSSD.Meetings.CacheStore

  setup %{conn: conn} do
    prev_integrations = Application.get_env(:dashboard_ssd, :integrations)
    prev_tesla = Application.get_env(:tesla, :adapter)
    # Ensure Fireflies client authenticates and uses mock adapter in tests
    Application.put_env(:dashboard_ssd, :integrations, Keyword.merge(prev_integrations || [], fireflies_api_token: "test-token"))
    Application.put_env(:tesla, :adapter, Tesla.Mock)
    {:ok, user} =
      Accounts.create_user(%{
        email: "meeting_tester@example.com",
        name: "Mtg Test",
        role_id: Accounts.ensure_role!("admin").id
      })

    on_exit(fn ->
      case prev_integrations do
        nil -> Application.delete_env(:dashboard_ssd, :integrations)
        v -> Application.put_env(:dashboard_ssd, :integrations, v)
      end

      case prev_tesla do
        nil -> Application.delete_env(:tesla, :adapter)
        v -> Application.put_env(:tesla, :adapter, v)
      end
    end)

    {:ok, conn: init_test_session(conn, %{user_id: user.id})}
  end

  test "renders meeting detail", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/meetings/evt-demo")
    assert html =~ "Meeting"
  end

  test "meeting page renders bitstring action_items without crash", %{conn: conn} do
    # Seed Fireflies cache so fetch_latest_for_series returns bitstring items
    key = {:series_artifacts, "series-alpha"}
    val = %{accomplished: "Summary here", action_items: "A\nB"}
    :ok = CacheStore.put(key, val, :timer.minutes(5))

    {:ok, _view, html} = live(conn, ~p"/meetings/evt-1?series_id=series-alpha&title=Weekly")
    assert html =~ "Last meeting summary"
    assert html =~ "Summary here"
    assert html =~ "A"
    assert html =~ "B"
  end

  test "shows inline rate limit message in meeting detail", %{conn: conn} do
    # Mock Fireflies to return rate-limited error for any query
    Tesla.Mock.mock(fn %{method: :post, url: "https://api.fireflies.ai/graphql"} ->
      %Tesla.Env{
        status: 200,
        body: %{
          "data" => nil,
          "errors" => [
            %{
              "code" => "too_many_requests",
              "message" => "Too many requests. Please retry after 02:34:56 AM (UTC)",
              "extensions" => %{"code" => "too_many_requests", "status" => 429}
            }
          ]
        }
      }
    end)

    {:ok, _view, html} = live(conn, ~p"/meetings/evt-1?series_id=series-1&title=Weekly")
    assert html =~ "Last meeting summary"
    assert html =~ "Too many requests"
  end

  # What to bring section removed in favor of a single freeform agenda field
end
