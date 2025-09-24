defmodule DashboardSSDWeb.KbLiveTest do
  use DashboardSSDWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts

  setup do
    Accounts.ensure_role!("admin")
    Accounts.ensure_role!("employee")
    Accounts.ensure_role!("client")

    on_exit(fn ->
      Application.delete_env(:dashboard_ssd, :integrations)
      System.delete_env("NOTION_TOKEN")
    end)

    :ok
  end

  describe "knowledge base access" do
    test "redirects unauthenticated users", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/auth/google?redirect_to=/kb"}}} = live(conn, ~p"/kb")
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
  end
end
