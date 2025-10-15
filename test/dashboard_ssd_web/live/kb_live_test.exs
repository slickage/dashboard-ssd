defmodule DashboardSSDWeb.KbLiveTest do
  use DashboardSSDWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Mox

  alias DashboardSSD.Accounts
  alias DashboardSSD.Integrations.{Notion, NotionMock}
  alias DashboardSSD.KnowledgeBase.{Activity, Cache, Types}
  alias DashboardSSDWeb.KbLive.Index

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

    test "denies guests without permission", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          email: "guest@example.com",
          name: "Guest",
          role_id: Accounts.ensure_role!("guest").id
        })

      conn = init_test_session(conn, %{user_id: user.id})

      assert {:error, {:redirect, %{to: "/", flash: %{"error" => message}}}} = live(conn, ~p"/kb")
      assert message == "You don't have permission to access this page"
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

    test "selecting another collection updates the documents", %{conn: conn} do
      Application.put_env(:dashboard_ssd, :integrations,
        notion_token: "tok",
        notion_curated_database_ids: ["db-handbook", "db-guides"]
      )

      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        curated_collections: [
          %{"id" => "db-handbook", "name" => "Company Handbook"},
          %{"id" => "db-guides", "name" => "Implementation Guides"}
        ]
      )

      Cache.reset()
      Notion.reset_circuits()

      handbook_page = %{
        "id" => "page-1",
        "url" => "https://notion.so/page-1",
        "created_time" => "2024-05-01T10:00:00Z",
        "last_edited_time" => "2024-05-01T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Handbook"}]}
        }
      }

      guide_page = %{
        "id" => "page-2",
        "url" => "https://notion.so/page-2",
        "created_time" => "2024-05-02T10:00:00Z",
        "last_edited_time" => "2024-05-02T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-guides"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Guide"}]}
        }
      }

      NotionMock
      |> stub(:query_database, fn "tok", db_id, _opts ->
        case db_id do
          "db-handbook" ->
            {:ok,
             %{
               "results" => [handbook_page],
               "has_more" => false,
               "next_cursor" => nil
             }}

          "db-guides" ->
            {:ok,
             %{
               "results" => [guide_page],
               "has_more" => false,
               "next_cursor" => nil
             }}
        end
      end)
      |> stub(:retrieve_page, fn "tok", page_id, _opts ->
        case page_id do
          "page-1" -> {:ok, handbook_page}
          "page-2" -> {:ok, guide_page}
        end
      end)
      |> stub(:retrieve_block_children, fn "tok", _page_id, _opts ->
        {:ok, %{"results" => [], "has_more" => false, "next_cursor" => nil}}
      end)

      {:ok, user} =
        Accounts.create_user(%{
          email: "collections@example.com",
          name: "Collections",
          role_id: Accounts.ensure_role!("employee").id
        })

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      _ = render(view)
      assert has_element?(view, "button[phx-value-id='db-guides']")

      render_click(element(view, "button", "Implementation Guides"))

      html = render(view)
      assert html =~ "Guide"
    end

    test "shows collection errors when curated fetch fails", %{conn: conn} do
      NotionMock
      |> expect(:query_database, 2, fn "tok", "db-handbook", _opts ->
        {:error, {:http_error, 503, %{}}}
      end)
      |> expect(:list_databases, fn "tok", _opts ->
        {:ok, %{"results" => [], "has_more" => false, "next_cursor" => nil}}
      end)

      {:ok, user} =
        Accounts.create_user(%{
          email: "collection-error@example.com",
          name: "Collection Error",
          role_id: Accounts.ensure_role!("employee").id
        })

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, _view, html} = live(conn, ~p"/kb")

      assert html =~ "HTTP error 503"
    end

    test "shows document errors when loading a collection fails", %{conn: conn} do
      prev_kb = Application.get_env(:dashboard_ssd, DashboardSSD.KnowledgeBase)
      prev_integrations = Application.get_env(:dashboard_ssd, :integrations)

      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        curated_collections: [
          %{"id" => "db-handbook", "name" => "Company Handbook"},
          %{"id" => "db-guides", "name" => "Implementation Guides"}
        ]
      )

      Application.put_env(:dashboard_ssd, :integrations,
        notion_token: "tok",
        notion_curated_database_ids: ["db-handbook", "db-guides"]
      )

      on_exit(fn ->
        if prev_kb do
          Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase, prev_kb)
        else
          Application.delete_env(:dashboard_ssd, DashboardSSD.KnowledgeBase)
        end

        if prev_integrations do
          Application.put_env(:dashboard_ssd, :integrations, prev_integrations)
        else
          Application.delete_env(:dashboard_ssd, :integrations)
        end
      end)

      NotionMock
      |> stub(:query_database, fn "tok", db_id, _opts ->
        case db_id do
          "db-handbook" ->
            {:ok, %{"results" => [], "has_more" => false, "next_cursor" => nil}}

          "db-guides" ->
            {:ok, %{"results" => [], "has_more" => false, "next_cursor" => nil}}
        end
      end)

      {:ok, user} =
        Accounts.create_user(%{
          email: "doc-error@example.com",
          name: "Doc Error",
          role_id: Accounts.ensure_role!("employee").id
        })

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      NotionMock
      |> expect(:query_database, fn "tok", "db-guides", _opts ->
        {:error, :timeout}
      end)

      render_click(element(view, "button[phx-value-id='db-guides']"))
      assert render(view) =~ "db-guides: timeout"
    end

    test "displays reader error when document cannot be loaded", %{conn: conn} do
      page = %{
        "id" => "page-1",
        "url" => "https://notion.so/page-1",
        "created_time" => "2024-05-01T10:00:00Z",
        "last_edited_time" => "2024-05-01T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Welcome"}]}
        }
      }

      NotionMock
      |> expect(:query_database, 2, fn "tok", "db-handbook", _opts ->
        {:ok, %{"results" => [page], "has_more" => false, "next_cursor" => nil}}
      end)
      |> expect(:retrieve_page, fn "tok", "page-1", _opts -> {:ok, page} end)
      |> expect(:retrieve_block_children, fn "tok", "page-1", _opts ->
        {:ok, %{"results" => [], "has_more" => false, "next_cursor" => nil}}
      end)

      {:ok, user} =
        Accounts.create_user(%{
          email: "reader-error@example.com",
          name: "Reader Error",
          role_id: Accounts.ensure_role!("employee").id
        })

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      Cache.delete(:collections, {:document_detail, "page-1"})

      NotionMock
      |> expect(:retrieve_page, fn "tok", "page-1", _opts ->
        {:error, {:http_error, 401, %{}}}
      end)

      render_click(element(view, "button[phx-value-id='page-1']"))

      assigns =
        view.pid
        |> :sys.get_state()
        |> Map.fetch!(:socket)
        |> Map.fetch!(:assigns)

      assert assigns.reader_error == %{document_id: "page-1", reason: {:http_error, 401, %{}}}
      assert assigns.selected_document == nil
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

      # Empty search query handled without feedback message
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

  describe "event handling" do
    test "open_search_result loads the selected document without reloading collection" do
      Cache.reset()
      Notion.reset_circuits()

      {:ok, user} =
        Accounts.create_user(%{
          email: "open-search@example.com",
          name: "Opener",
          role_id: Accounts.ensure_role!("employee").id
        })

      page = %{
        "id" => "page-open",
        "url" => "https://notion.so/page-open",
        "created_time" => "2024-05-10T09:00:00Z",
        "last_edited_time" => "2024-05-11T10:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Open"}]}
        }
      }

      NotionMock
      |> expect(:retrieve_page, fn "tok", "page-open", _opts -> {:ok, page} end)
      |> expect(:retrieve_block_children, fn "tok", "page-open", _opts ->
        {:ok, %{"results" => [], "has_more" => false, "next_cursor" => nil}}
      end)

      {:ok, last_updated_at, _} = DateTime.from_iso8601("2024-05-11T10:00:00Z")

      summary = %Types.DocumentSummary{
        id: "page-open",
        title: "Open",
        collection_id: "db-handbook",
        share_url: page["url"],
        last_updated_at: last_updated_at,
        summary: nil,
        owner: nil,
        tags: []
      }

      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          flash: %{},
          current_user: user,
          selected_collection_id: "db-handbook",
          documents: [summary],
          document_errors: [],
          selected_document: nil,
          selected_document_id: nil,
          reader_error: nil,
          recent_documents: [],
          recent_errors: []
        }
      }

      {:noreply, loading_socket} =
        Index.handle_event(
          "open_search_result",
          %{"id" => "page-open", "collection" => "db-handbook"},
          socket
        )

      assert loading_socket.assigns.reader_loading
      assert loading_socket.assigns.pending_document_id == "page-open"

      assert_receive {:load_document, "page-open", opts}

      {:noreply, new_socket} =
        Index.handle_info({:load_document, "page-open", opts}, loading_socket)

      assert new_socket.assigns.selected_collection_id == "db-handbook"
      assert new_socket.assigns.selected_document.id == "page-open"
      assert new_socket.assigns.selected_document.title == "Open"
      assert new_socket.assigns.selected_document_id == "page-open"

      assert [%Types.RecentActivity{document_id: "page-open"}] =
               new_socket.assigns.recent_documents
    end

    test "open_search_result keeps current state when collection id missing" do
      Cache.reset()

      {:ok, user} =
        Accounts.create_user(%{
          email: "open-empty@example.com",
          name: "Empty",
          role_id: Accounts.ensure_role!("employee").id
        })

      summary = %Types.DocumentSummary{
        id: "page-empty",
        collection_id: "db-handbook",
        title: "Existing",
        summary: nil,
        owner: nil,
        share_url: "https://notion.so/page-empty",
        last_updated_at: DateTime.utc_now(),
        synced_at: nil,
        tags: [],
        metadata: %{}
      }

      detail = %Types.DocumentDetail{
        id: "page-empty",
        collection_id: "db-handbook",
        title: "Existing",
        summary: nil,
        owner: nil,
        share_url: "https://notion.so/page-empty",
        last_updated_at: summary.last_updated_at,
        synced_at: nil,
        rendered_blocks: [],
        tags: [],
        metadata: %{},
        source: :cache
      }

      Cache.put(:collections, {:document_detail, "page-empty"}, detail, :timer.minutes(1))

      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          flash: %{},
          current_user: user,
          selected_collection_id: "db-handbook",
          documents: [summary],
          document_errors: [],
          selected_document: nil,
          selected_document_id: nil,
          reader_error: nil,
          recent_documents: [],
          recent_errors: []
        }
      }

      {:noreply, loading_socket} =
        Index.handle_event(
          "open_search_result",
          %{"id" => "page-empty"},
          socket
        )

      assert loading_socket.assigns.reader_loading
      assert loading_socket.assigns.pending_document_id == "page-empty"

      assert_receive {:load_document, "page-empty", opts}

      {:noreply, new_socket} =
        Index.handle_info({:load_document, "page-empty", opts}, loading_socket)

      assert new_socket.assigns.selected_collection_id == "db-handbook"
      assert new_socket.assigns.selected_document_id == "page-empty"
    end

    test "open_search_result loads new collection when id differs" do
      Cache.reset()

      {:ok, user} =
        Accounts.create_user(%{
          email: "open-new@example.com",
          name: "New Collection",
          role_id: Accounts.ensure_role!("employee").id
        })

      existing = %Types.DocumentSummary{
        id: "page-old",
        collection_id: "db-handbook",
        title: "Old",
        summary: nil,
        owner: nil,
        share_url: "https://notion.so/page-old",
        last_updated_at: DateTime.utc_now(),
        synced_at: nil,
        tags: [],
        metadata: %{}
      }

      new_doc = %Types.DocumentSummary{
        id: "page-new",
        collection_id: "db-guides",
        title: "New Doc",
        summary: "Fresh",
        owner: "Owner",
        share_url: "https://notion.so/page-new",
        last_updated_at: DateTime.utc_now(),
        synced_at: nil,
        tags: ["Guide"],
        metadata: %{}
      }

      detail = %Types.DocumentDetail{
        id: "page-new",
        collection_id: "db-guides",
        title: "New Doc",
        summary: "Fresh",
        owner: "Owner",
        share_url: "https://notion.so/page-new",
        last_updated_at: new_doc.last_updated_at,
        synced_at: nil,
        rendered_blocks: [],
        tags: ["Guide"],
        metadata: %{},
        source: :cache
      }

      Cache.put(:collections, {:documents, "db-guides"}, [new_doc], :timer.minutes(1))
      Cache.put(:collections, {:document_detail, "page-new"}, detail, :timer.minutes(1))

      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          flash: %{},
          current_user: user,
          selected_collection_id: "db-handbook",
          documents: [existing],
          document_errors: [],
          selected_document: nil,
          selected_document_id: nil,
          reader_error: nil,
          recent_documents: [],
          recent_errors: []
        }
      }

      {:noreply, loading_socket} =
        Index.handle_event(
          "open_search_result",
          %{"id" => "page-new", "collection" => "db-guides"},
          socket
        )

      assert loading_socket.assigns.reader_loading
      assert loading_socket.assigns.pending_document_id == "page-new"

      assert_receive {:load_document, "page-new", opts}

      {:noreply, new_socket} =
        Index.handle_info({:load_document, "page-new", opts}, loading_socket)

      assert new_socket.assigns.selected_collection_id == "db-guides"
      assert Enum.map(new_socket.assigns.documents, & &1.id) == ["page-new"]
      assert new_socket.assigns.selected_document_id == "page-new"
      assert new_socket.assigns.reader_error == nil
    end
  end

  defp restore_env(%{notion_token: token, notion_api_key: api_key}) do
    set_env("NOTION_TOKEN", token)
    set_env("NOTION_API_KEY", api_key)
  end

  defp set_env(key, nil), do: System.delete_env(key)
  defp set_env(key, value), do: System.put_env(key, value)
end
