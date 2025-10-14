defmodule DashboardSSDWeb.KbLiveTest do
  use DashboardSSDWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Mox

  alias DashboardSSD.Accounts
  alias DashboardSSD.Integrations.{Notion, NotionMock}
  alias DashboardSSD.KnowledgeBase.{Activity, Cache, Types}

  setup :verify_on_exit!

  setup do
    Mox.set_mox_global()

    Cache.reset()
    Accounts.ensure_role!("admin")
    Accounts.ensure_role!("employee")
    Accounts.ensure_role!("client")

    prev_integrations = Application.get_env(:dashboard_ssd, :integrations)
    prev_kb = Application.get_env(:dashboard_ssd, DashboardSSD.KnowledgeBase)

    prev_env = %{
      notion_token: System.get_env("NOTION_TOKEN"),
      notion_api_key: System.get_env("NOTION_API_KEY")
    }

    System.delete_env("NOTION_TOKEN")
    System.delete_env("NOTION_API_KEY")

    Application.put_env(:dashboard_ssd, :integrations,
      notion_token: "tok",
      notion_curated_database_ids: ["db-handbook"]
    )

    Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
      curated_collections: [%{"id" => "db-handbook", "name" => "Company Handbook"}]
    )

    NotionMock
    |> stub(:query_database, fn _token, _id, _opts ->
      {:ok, %{"results" => [], "has_more" => false}}
    end)

    Notion.reset_circuits()

    on_exit(fn ->
      restore_env(prev_env)

      if prev_integrations do
        Application.put_env(:dashboard_ssd, :integrations, prev_integrations)
      else
        Application.delete_env(:dashboard_ssd, :integrations)
      end

      if prev_kb do
        Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase, prev_kb)
      else
        Application.delete_env(:dashboard_ssd, DashboardSSD.KnowledgeBase)
      end

      Cache.reset()
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

  describe "landing view" do
    test "loads curated collections and recent activity", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          email: "landing@example.com",
          name: "Landing",
          role_id: Accounts.ensure_role!("employee").id
        })

      NotionMock
      |> expect(:query_database, 2, fn "tok", "db-handbook", _opts ->
        {:ok,
         %{
           "results" => [
             %{
               "id" => "page-1",
               "url" => "https://notion.so/page-1",
               "created_time" => "2024-05-01T10:00:00Z",
               "last_edited_time" => "2024-05-01T12:00:00Z",
               "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
               "properties" => %{
                 "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Welcome"}]}
               }
             }
           ],
           "total" => 1,
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)
      |> stub(:retrieve_page, fn "tok", "page-1", _opts ->
        {:ok,
         %{
           "id" => "page-1",
           "url" => "https://notion.so/page-1",
           "created_time" => "2024-05-01T10:00:00Z",
           "last_edited_time" => "2024-05-01T12:00:00Z",
           "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
           "properties" => %{
             "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Welcome"}]}
           }
         }}
      end)
      |> stub(:retrieve_block_children, fn
        "tok", "page-1", _opts ->
          {:ok, %{"results" => [], "has_more" => false, "next_cursor" => nil}}
      end)

      :ok =
        Activity.record_view(
          user,
          %{
            document_id: "page-1",
            document_title: "Welcome"
          },
          occurred_at: ~U[2024-05-01 12:00:00Z]
        )

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      assigns = view.pid |> :sys.get_state() |> Map.fetch!(:socket) |> Map.fetch!(:assigns)

      assert [%Types.Collection{id: "db-handbook"}] = assigns.collections
      assert [] = assigns.collection_errors
      assert [%Types.DocumentSummary{id: "page-1"}] = assigns.documents
      assert [%Types.RecentActivity{document_id: "page-1"}] = assigns.recent_documents
      assert [] = assigns.recent_errors
    end
  end

  describe "empty and error states" do
    test "shows message when curated collections are missing", %{conn: conn} do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        curated_collections: [],
        auto_discover?: false
      )

      {:ok, user} =
        Accounts.create_user(%{
          email: "empty@example.com",
          name: "Empty",
          role_id: Accounts.ensure_role!("employee").id
        })

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, _view, html} = live(conn, ~p"/kb")

      assert html =~ "No curated collections are available yet."
      assert html =~ "No documents are available in this collection yet."
      assert html =~ "You have not opened any documents recently."
    end

    test "auto discovery surfaces available databases", %{conn: conn} do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase, auto_discover?: true)
      Application.put_env(:dashboard_ssd, :integrations, notion_token: "tok")

      NotionMock
      |> expect(:list_databases, fn "tok", _opts ->
        {:ok,
         %{
           "results" => [
             %{
               "id" => "db-auto",
               "title" => [%{"plain_text" => "Auto DB"}],
               "description" => [],
               "last_edited_time" => "2024-05-01T12:00:00Z",
               "properties" => %{}
             }
           ],
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)

      {:ok, user} =
        Accounts.create_user(%{
          email: "auto@example.com",
          name: "Auto",
          role_id: Accounts.ensure_role!("employee").id
        })

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      assigns = view.pid |> :sys.get_state() |> Map.fetch!(:socket) |> Map.fetch!(:assigns)

      assert [%Types.Collection{id: "db-auto"}] = assigns.collections
      assert [] = assigns.collection_errors
    end

    test "displays collection errors when Notion fails", %{conn: conn} do
      NotionMock
      |> expect(:query_database, 2, fn "tok", "db-handbook", _opts ->
        {:error, :timeout}
      end)
      |> expect(:list_databases, fn "tok", _opts ->
        {:ok,
         %{
           "results" => [],
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)

      {:ok, user} =
        Accounts.create_user(%{
          email: "error@example.com",
          name: "Error",
          role_id: Accounts.ensure_role!("employee").id
        })

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, _view, html} = live(conn, ~p"/kb")

      assert html =~ "db-handbook: timeout"
    end
  end

  describe "document interactions" do
    test "selecting a document loads the reader", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          email: "reader@example.com",
          name: "Reader",
          role_id: Accounts.ensure_role!("employee").id
        })

      page_one = %{
        "id" => "page-1",
        "url" => "https://notion.so/page-1",
        "created_time" => "2024-05-01T10:00:00Z",
        "last_edited_time" => "2024-05-01T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Welcome"}]}
        }
      }

      page_two = %{
        "id" => "page-2",
        "url" => "https://notion.so/page-2",
        "created_time" => "2024-05-02T10:00:00Z",
        "last_edited_time" => "2024-05-02T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Project Kickoff"}]}
        }
      }

      NotionMock
      |> expect(:query_database, 2, fn "tok", "db-handbook", _opts ->
        {:ok,
         %{
           "results" => [page_one, page_two],
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)
      |> stub(:retrieve_page, fn
        "tok", "page-1", _opts -> {:ok, page_one}
        "tok", "page-2", _opts -> {:ok, page_two}
      end)
      |> stub(:retrieve_block_children, fn
        "tok", "page-1", _opts ->
          {:ok, %{"results" => [], "has_more" => false, "next_cursor" => nil}}

        "tok", "page-2", _opts ->
          {:ok,
           %{
             "results" => [
               %{
                 "id" => "block-1",
                 "type" => "paragraph",
                 "has_children" => false,
                 "paragraph" => %{"rich_text" => [%{"plain_text" => "Kickoff agenda"}]}
               }
             ],
             "has_more" => false,
             "next_cursor" => nil
           }}
      end)

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      view
      |> element("button[phx-value-id='page-2']")
      |> render_click()

      html = render(view)
      assert html =~ "Project Kickoff"
      assert html =~ "Kickoff agenda"
    end
  end

  describe "search" do
    setup do
      prev_kb = Application.get_env(:dashboard_ssd, DashboardSSD.KnowledgeBase)

      Application.put_env(:dashboard_ssd, :integrations,
        notion_token: "tok",
        notion_curated_database_ids: ["db-handbook"]
      )

      Application.put_env(
        :dashboard_ssd,
        DashboardSSD.KnowledgeBase,
        Keyword.merge(prev_kb || [],
          allowed_document_type_values: ["Wiki"],
          document_type_property_names: ["Type"],
          allow_documents_without_type?: true
        )
      )

      on_exit(fn ->
        if prev_kb do
          Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase, prev_kb)
        else
          Application.delete_env(:dashboard_ssd, DashboardSSD.KnowledgeBase)
        end
      end)

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
      assert rendered =~ "Updated 2024-05-01 12:00"
    end

    test "filters out search results that are not allowlisted", %{conn: conn} do
      Application.put_env(
        :dashboard_ssd,
        DashboardSSD.KnowledgeBase,
        Keyword.merge(
          Application.get_env(:dashboard_ssd, DashboardSSD.KnowledgeBase, []),
          allow_documents_without_type?: false
        )
      )

      {:ok, user} =
        Accounts.create_user(%{
          email: "employee-filter@example.com",
          name: "Filter",
          role_id: Accounts.ensure_role!("employee").id
        })

      Tesla.Mock.mock(fn
        %{
          method: :post,
          url: "https://api.notion.com/v1/search"
        } ->
          %Tesla.Env{
            status: 200,
            body: %{
              "results" => [
                %{
                  "id" => "page-456",
                  "url" => "https://notion.so/page-456",
                  "last_edited_time" => "2024-06-01T12:00:00Z",
                  "properties" => %{
                    "Name" => %{
                      "type" => "title",
                      "title" => [%{"plain_text" => "Daily Tasks"}]
                    },
                    "Type" => %{
                      "type" => "select",
                      "select" => %{"name" => "Task"}
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
      |> form("form", %{query: "tasks"})
      |> render_submit()

      rendered = render(view)
      assert rendered =~ "No documents matched your search."
      refute rendered =~ "Daily Tasks"
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

  defp restore_env(%{notion_token: token, notion_api_key: api_key}) do
    set_env("NOTION_TOKEN", token)
    set_env("NOTION_API_KEY", api_key)
  end

  defp set_env(key, nil), do: System.delete_env(key)
  defp set_env(key, value), do: System.put_env(key, value)
end
