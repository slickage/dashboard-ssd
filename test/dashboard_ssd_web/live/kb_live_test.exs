defmodule DashboardSSDWeb.KbLiveTest do
  use DashboardSSDWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts
  alias DashboardSSD.Integrations.Notion

  setup do
    Accounts.ensure_role!("admin")
    Accounts.ensure_role!("employee")
    Accounts.ensure_role!("client")

    Notion.reset_circuits()

    on_exit(fn ->
      Application.delete_env(:dashboard_ssd, :integrations)
      System.delete_env("NOTION_TOKEN")
      Notion.reset_circuits()
    end)

    :ok
  end

  describe "knowledge base access" do
    test "redirects unauthenticated users", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login?redirect_to=%2Fkb"}}} = live(conn, ~p"/kb")
    end

    test "allows employees to view the knowledge base", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          email: "employee@example.com",
          name: "Employee",
          role_id: Accounts.ensure_role!("employee").id
        })

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, _view, html} = live(conn, ~p"/kb")

      assert html =~ "Knowledge Base"
    end
  end

  describe "search" do
    setup do
      Application.put_env(:dashboard_ssd, :integrations, notion_token: "tok")
      :ok
    end

    test "displays results returned from Notion", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          email: "employee-search@example.com",
          name: "Searcher",
          role_id: Accounts.ensure_role!("employee").id
        })

      Tesla.Mock.mock(fn
        %{
          method: :post,
          url: "https://api.notion.com/v1/search",
          headers: headers,
          body: body
        } ->
          assert Enum.any?(headers, fn {k, v} ->
                   k == "authorization" and String.contains?(v, "tok")
                 end)

          _ = if is_binary(body), do: Jason.decode!(body), else: body

          %Tesla.Env{
            status: 200,
            body: %{
              "results" => [
                %{
                  "id" => "page-123",
                  "url" => "https://notion.so/page-123",
                  "last_edited_time" => "2024-05-01T12:00:00Z",
                  "icon" => %{"emoji" => "📄"},
                  "properties" => %{
                    "Name" => %{
                      "type" => "title",
                      "title" => [%{"plain_text" => "Public Roadmap"}]
                    }
                  }
                }
              ]
            }
          }
      end)

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      view
      |> form("form", %{query: "roadmap"})
      |> render_submit()

      rendered = render(view)
      assert rendered =~ "Public Roadmap"
      assert rendered =~ "https://notion.so/page-123"
      assert rendered =~ "Last updated"
    end

    test "shows flash when integration missing", %{conn: conn} do
      Application.delete_env(:dashboard_ssd, :integrations)

      {:ok, user} =
        Accounts.create_user(%{
          email: "client@example.com",
          name: "Client",
          role_id: Accounts.ensure_role!("client").id
        })

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      view
      |> form("form", %{query: "docs"})
      |> render_submit()

      assert render(view) =~ "Notion integration is not configured"
    end

    test "ignores empty search queries", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          email: "empties@example.com",
          name: "Empty",
          role_id: Accounts.ensure_role!("employee").id
        })

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      view
      |> form("form", %{query: ""})
      |> render_submit()

      assert render(view) =~ "Enter a search term"
    end

    test "shows error when notion returns http error", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          email: "errors@example.com",
          name: "Errors",
          role_id: Accounts.ensure_role!("employee").id
        })

      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.notion.com/v1/search"} ->
          %Tesla.Env{status: 500, body: %{"error" => "server"}}
      end)

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      view
      |> form("form", %{query: "dash"})
      |> render_submit()

      assert render(view) =~ "Notion API returned status 500"
    end

    test "shows fallback title and nil date when Notion omits data", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          email: "untitled@example.com",
          name: "Untitled",
          role_id: Accounts.ensure_role!("employee").id
        })

      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.notion.com/v1/search"} ->
          %Tesla.Env{
            status: 200,
            body: %{"results" => [%{"id" => "pg", "url" => "https://notion.so/pg"}]}
          }
      end)

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      view
      |> form("form", %{query: "untitled"})
      |> render_submit()

      rendered = render(view)
      assert rendered =~ "Untitled"
      assert rendered =~ "https://notion.so/pg"
    end

    test "handles generic notion errors", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          email: "timeouts@example.com",
          name: "Timeout",
          role_id: Accounts.ensure_role!("employee").id
        })

      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.notion.com/v1/search"} ->
          {:error, :timeout}
      end)

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      view
      |> form("form", %{query: "timeout"})
      |> render_submit()

      assert render(view) =~ "Unable to reach Notion (:timeout)"
    end

    test "handles structured notion errors", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          email: "struct-error@example.com",
          name: "Struct",
          role_id: Accounts.ensure_role!("employee").id
        })

      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.notion.com/v1/search"} ->
          {:error, %Tesla.Error{reason: :nxdomain}}
      end)

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      view
      |> form("form", %{query: "offline"})
      |> render_submit()

      assert render(view) =~ "Unable to reach Notion"
    end

    test "mobile menu toggle works", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          email: "mobile@example.com",
          name: "Mobile",
          role_id: Accounts.ensure_role!("employee").id
        })

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      # Toggle mobile menu open
      view
      |> element("button[phx-click='toggle_mobile_menu']")
      |> render_click()

      # Close mobile menu by clicking the close button
      view
      |> element("button[phx-click='close_mobile_menu']")
      |> render_click()
    end
  end
end
