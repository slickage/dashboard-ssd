defmodule DashboardSSDWeb.KbLiveTest do
  use DashboardSSDWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Mox

  alias DashboardSSD.Accounts
  alias DashboardSSD.Integrations.{Notion, NotionMock}
  alias DashboardSSD.KnowledgeBase.{Activity, CacheStore, Types}
  alias DashboardSSDWeb.KbLive.Index

  setup :verify_on_exit!

  setup do
    Mox.set_mox_global()

    CacheStore.reset()
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
      {:ok, %{"results" => [], "has_more" => false, "next_cursor" => nil}}
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

      CacheStore.reset()
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
      |> stub(:query_database, fn "tok", "db-handbook", _opts ->
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
      |> stub(:query_database, fn "tok", "db-handbook", _opts ->
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
      |> stub(:query_database, fn "tok", "db-handbook", _opts ->
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

    test "ignores toggle_collection events with blank ids" do
      socket = base_socket(%{expanded_collections: MapSet.new()})

      assert {:noreply, new_socket} =
               Index.handle_event("toggle_collection", %{"id" => ""}, socket)

      assert new_socket.assigns.expanded_collections == MapSet.new()
    end

    test "copy_share_link pushes feedback" do
      socket = base_socket(%{flash: %{}, search_dropdown_open: false})

      assert {:noreply, new_socket} =
               Index.handle_event(
                 "copy_share_link",
                 %{"url" => "https://example.com/share"},
                 socket
               )

      assert new_socket.assigns.flash == %{
               "info" => "Share link copied to clipboard"
             }
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

      CacheStore.reset()
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
      |> stub(:query_database, fn "tok", "db-handbook", _opts ->
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
            {:error, :timeout}
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
      |> stub(:query_database, fn "tok", "db-handbook", _opts ->
        {:ok, %{"results" => [page], "has_more" => false, "next_cursor" => nil}}
      end)
      |> expect(:retrieve_page, 3, fn "tok", "page-1", _opts ->
        {:error, {:http_error, 401, %{}}}
      end)

      {:ok, user} =
        Accounts.create_user(%{
          email: "reader-error@example.com",
          name: "Reader Error",
          role_id: Accounts.ensure_role!("employee").id
        })

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      CacheStore.delete({:document_detail, "page-1"})

      render_click(element(view, "button[phx-value-id='page-1']"))

      assigns =
        view.pid
        |> :sys.get_state()
        |> Map.fetch!(:socket)
        |> Map.fetch!(:assigns)

      assert assigns.reader_error == %{document_id: "page-1", reason: {:http_error, 401, %{}}}
      assert assigns.selected_document == nil
    end

    test "selects document on keydown", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          email: "select-key@example.com",
          name: "Select Key",
          role_id: Accounts.ensure_role!("employee").id
        })

      page = %{
        "id" => "page-1",
        "url" => "https://notion.so/page-1",
        "created_time" => "2024-05-01T10:00:00Z",
        "last_edited_time" => "2024-05-01T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Key Select"}]}
        }
      }

      NotionMock
      |> stub(:query_database, fn "tok", "db-handbook", _opts ->
        {:ok, %{"results" => [page], "has_more" => false, "next_cursor" => nil}}
      end)
      |> stub(:retrieve_page, fn "tok", "page-1", _opts -> {:ok, page} end)
      |> stub(:retrieve_block_children, fn "tok", "page-1", _opts ->
        {:ok, %{"results" => [], "has_more" => false, "next_cursor" => nil}}
      end)

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      view
      |> element("button[phx-value-id='page-1']")
      |> render_keydown(%{key: "Enter"})

      html = render(view)
      assert html =~ "Key Select"
    end

    test "toggles mobile menu", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          email: "mobile-menu@example.com",
          name: "Mobile Menu",
          role_id: Accounts.ensure_role!("employee").id
        })

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      assert view |> element("button[phx-click='toggle_mobile_menu']") |> render_click()
      assert view |> element("button[phx-click='close_mobile_menu']") |> has_element?()

      assert view |> element("button[phx-click='close_mobile_menu']") |> render_click()
    end

    test "toggles collection on keydown", %{conn: conn} do
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

      CacheStore.reset()
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
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Key Guide"}]}
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
          email: "toggle-key@example.com",
          name: "Toggle Key",
          role_id: Accounts.ensure_role!("employee").id
        })

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      view
      |> element("button[phx-value-id='db-guides']")
      |> render_keydown(%{key: "Enter"})

      html = render(view)
      assert html =~ "Key Guide"
    end

    test "processes async search result messages", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          email: "search-msg@example.com",
          name: "Search Msg",
          role_id: Accounts.ensure_role!("employee").id
        })

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      send(view.pid, {:search_result, "Doc", {:ok, %{"results" => []}}})
      render(view)
      assert live_assign(view, :query) == "Doc"
      assert live_assign(view, :search_dropdown_open)
      assert live_assign(view, :search_loading) == false

      send(view.pid, {:search_result, "Err", {:error, :timeout}})
      assert render(view) =~ "Unable to reach Notion"
      assert live_assign(view, :query) == "Err"
      assert live_assign(view, :results) == []
    end
  end

  describe "document caching" do
    test "loading document uses cache when available", %{conn: conn} do
      CacheStore.reset()

      {:ok, user} =
        Accounts.create_user(%{
          email: "cache-hit@example.com",
          name: "Cache Hit",
          role_id: Accounts.ensure_role!("employee").id
        })

      {:ok, last_updated_at, _} = DateTime.from_iso8601("2024-05-01T12:00:00Z")

      cached_document = %Types.DocumentDetail{
        id: "cached-doc",
        title: "Cached Document",
        collection_id: "db-handbook",
        share_url: "https://notion.so/cached-doc",
        last_updated_at: last_updated_at,
        rendered_blocks: [
          %{type: :paragraph, segments: [%{text: "Cached content"}], children: []}
        ],
        tags: [],
        metadata: %{},
        source: :cache
      }

      page = %{
        "id" => "cached-doc",
        "url" => "https://notion.so/cached-doc",
        "created_time" => "2024-05-01T10:00:00Z",
        "last_edited_time" => "2024-05-01T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Cached Document"}]}
        }
      }

      NotionMock
      |> stub(:query_database, fn "tok", "db-handbook", _opts ->
        {:ok, %{"results" => [page], "has_more" => false, "next_cursor" => nil}}
      end)
      |> stub(:retrieve_page, fn "tok", "cached-doc", _opts -> {:ok, page} end)
      |> stub(:retrieve_block_children, fn "tok", "cached-doc", _opts ->
        {:ok, %{"results" => [], "has_more" => false, "next_cursor" => nil}}
      end)

      CacheStore.put({:document_detail, "cached-doc"}, cached_document)

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      # Select the document, which should use cache
      view
      |> element("button[phx-value-id='cached-doc']")
      |> render_click()

      html = render(view)
      assert html =~ "Cached Document"
      assert html =~ "Cached content"
    end

    test "loading document fetches when not cached", %{conn: conn} do
      CacheStore.reset()

      {:ok, user} =
        Accounts.create_user(%{
          email: "cache-miss@example.com",
          name: "Cache Miss",
          role_id: Accounts.ensure_role!("employee").id
        })

      page = %{
        "id" => "fetched-doc",
        "url" => "https://notion.so/fetched-doc",
        "created_time" => "2024-05-01T10:00:00Z",
        "last_edited_time" => "2024-05-01T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Fetched Document"}]}
        }
      }

      NotionMock
      |> stub(:query_database, fn "tok", "db-handbook", _opts ->
        {:ok, %{"results" => [page], "has_more" => false, "next_cursor" => nil}}
      end)
      |> stub(:retrieve_page, fn "tok", "fetched-doc", _opts -> {:ok, page} end)
      |> stub(:retrieve_block_children, fn "tok", "fetched-doc", _opts ->
        {:ok,
         %{
           "results" => [
             %{
               "type" => "paragraph",
               "paragraph" => %{"rich_text" => [%{"plain_text" => "Fetched content"}]}
             }
           ],
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)
      |> expect(:retrieve_page, fn "tok", "fetched-doc", _opts -> {:ok, page} end)
      |> expect(:retrieve_block_children, fn "tok", "fetched-doc", _opts ->
        {:ok,
         %{
           "results" => [
             %{
               "type" => "paragraph",
               "paragraph" => %{"rich_text" => [%{"plain_text" => "Fetched content"}]}
             }
           ],
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      view
      |> element("button[phx-value-id='fetched-doc']")
      |> render_click()

      html = render(view)
      assert html =~ "Fetched Document"
      assert html =~ "Fetched content"
    end

    test "background update check ignores when document not selected", %{conn: _conn} do
      {:ok, _user} =
        Accounts.create_user(%{
          email: "ignore-update@example.com",
          name: "Ignore Update",
          role_id: Accounts.ensure_role!("employee").id
        })

      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          selected_document_id: "doc-1"
        }
      }

      {:noreply, new_socket} =
        Index.handle_info({:check_document_update, "doc-2", DateTime.utc_now()}, socket)

      assert new_socket == socket
    end

    test "background update refreshes document when changed", %{conn: _conn} do
      CacheStore.reset()

      Tesla.Mock.mock(fn
        %{method: :get, url: "https://api.notion.com/v1/pages/doc-1"} ->
          %Tesla.Env{
            status: 200,
            body: %{
              "id" => "doc-1",
              "url" => "https://notion.so/doc-1",
              "created_time" => "2024-05-01T10:00:00Z",
              "last_edited_time" => "2024-05-02T12:00:00Z",
              "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
              "properties" => %{
                "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Updated Document"}]}
              },
              "blocks" => [
                %{
                  "type" => "paragraph",
                  "paragraph" => %{"rich_text" => [%{"plain_text" => "Updated content"}]}
                }
              ]
            }
          }
      end)

      Application.put_env(:dashboard_ssd, :notion_client, NotionMock)

      NotionMock
      |> Mox.stub(:retrieve_page, fn _token, "doc-1", _opts ->
        {:ok,
         %{
           "id" => "doc-1",
           "url" => "https://notion.so/doc-1",
           "created_time" => "2024-05-01T10:00:00Z",
           "last_edited_time" => "2024-05-02T12:00:00Z",
           "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
           "properties" => %{
             "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Updated Document"}]}
           },
           "blocks" => [
             %{
               "type" => "paragraph",
               "paragraph" => %{"rich_text" => [%{"plain_text" => "Updated content"}]}
             }
           ]
         }}
      end)
      |> Mox.stub(:retrieve_block_children, fn _token, "doc-1", _opts ->
        {:ok, %{"results" => [], "has_more" => false, "next_cursor" => nil}}
      end)

      document = %Types.DocumentDetail{
        id: "doc-1",
        collection_id: "db-handbook",
        title: "Old Document",
        rendered_blocks: [
          %{
            "type" => "paragraph",
            "paragraph" => %{"rich_text" => [%{"plain_text" => "Old content"}]}
          }
        ],
        last_updated_at: ~U[2024-05-01 10:00:00Z],
        share_url: "https://notion.so/doc-1"
      }

      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          selected_document: document,
          selected_document_id: "doc-1"
        }
      }

      {:noreply, new_socket} =
        Index.handle_info({:check_document_update, "doc-1", document.last_updated_at}, socket)

      assert new_socket.assigns.selected_document.title == "Updated Document"
      assert new_socket.assigns.selected_document.last_updated_at == ~U[2024-05-02 12:00:00Z]
    end

    test "background update refreshes documents_by_collection when document is found", %{
      conn: _conn
    } do
      CacheStore.reset()

      Tesla.Mock.mock(fn
        %{method: :get, url: "https://api.notion.com/v1/pages/doc-1"} ->
          %Tesla.Env{
            status: 200,
            body: %{
              "id" => "doc-1",
              "url" => "https://notion.so/doc-1",
              "created_time" => "2024-05-01T10:00:00Z",
              "last_edited_time" => "2024-05-02T12:00:00Z",
              "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
              "properties" => %{
                "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Updated Document"}]}
              },
              "blocks" => [
                %{
                  "type" => "paragraph",
                  "paragraph" => %{"rich_text" => [%{"plain_text" => "Updated content"}]}
                }
              ]
            }
          }
      end)

      Application.put_env(:dashboard_ssd, :notion_client, NotionMock)

      NotionMock
      |> Mox.stub(:retrieve_page, fn _token, "doc-1", _opts ->
        {:ok,
         %{
           "id" => "doc-1",
           "url" => "https://notion.so/doc-1",
           "created_time" => "2024-05-01T10:00:00Z",
           "last_edited_time" => "2024-05-02T12:00:00Z",
           "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
           "properties" => %{
             "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Updated Document"}]}
           },
           "blocks" => [
             %{
               "type" => "paragraph",
               "paragraph" => %{"rich_text" => [%{"plain_text" => "Updated content"}]}
             }
           ]
         }}
      end)
      |> Mox.stub(:retrieve_block_children, fn _token, "doc-1", _opts ->
        {:ok, %{"results" => [], "has_more" => false, "next_cursor" => nil}}
      end)

      _old_document = %Types.DocumentSummary{
        id: "doc-1",
        collection_id: "db-handbook",
        title: "Old Document",
        summary: "Old summary",
        owner: "Old Owner",
        tags: ["old"],
        last_updated_at: ~U[2024-05-01 10:00:00Z],
        share_url: "https://notion.so/doc-1",
        synced_at: ~U[2024-05-01 10:00:00Z]
      }

      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          selected_document: %Types.DocumentDetail{
            id: "doc-1",
            collection_id: "db-handbook",
            title: "Old Document",
            rendered_blocks: [],
            last_updated_at: ~U[2024-05-01 10:00:00Z],
            share_url: "https://notion.so/doc-1"
          },
          selected_document_id: "doc-1",
          documents_by_collection: %{
            # Document not in this collection
            "db-other" => []
          },
          selected_collection_id: "db-other"
        }
      }

      {:noreply, new_socket} =
        Index.handle_info({:check_document_update, "doc-1", ~U[2024-05-01 10:00:00Z]}, socket)

      # Document should be updated and added to the appropriate collection
      assert new_socket.assigns.selected_document.title == "Updated Document"
      updated_collections = new_socket.assigns.documents_by_collection
      assert Map.has_key?(updated_collections, "db-handbook")
      handbook_docs = updated_collections["db-handbook"]
      assert length(handbook_docs) == 1
      assert hd(handbook_docs).id == "doc-1"
      assert hd(handbook_docs).title == "Updated Document"
    end

    test "loading document handles cache error gracefully", %{conn: conn} do
      CacheStore.reset()

      {:ok, user} =
        Accounts.create_user(%{
          email: "cache-error@example.com",
          name: "Cache Error",
          role_id: Accounts.ensure_role!("employee").id
        })

      page = %{
        "id" => "error-doc",
        "url" => "https://notion.so/error-doc",
        "created_time" => "2024-05-01T10:00:00Z",
        "last_edited_time" => "2024-05-01T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Error Document"}]}
        }
      }

      NotionMock
      |> stub(:query_database, fn "tok", "db-handbook", _opts ->
        {:ok, %{"results" => [page], "has_more" => false, "next_cursor" => nil}}
      end)
      |> stub(:retrieve_page, fn "tok", "error-doc", _opts -> {:error, :network_error} end)

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      view
      |> element("button[phx-value-id='error-doc']")
      |> render_click()

      socket = view.pid |> :sys.get_state() |> Map.fetch!(:socket)
      assert socket.assigns.reader_error == %{document_id: "error-doc", reason: :network_error}
      assert socket.assigns.selected_document == nil
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

    test "handles search results with properties but no title field", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          email: "no-title@example.com",
          name: "No Title",
          role_id: Accounts.ensure_role!("employee").id
        })

      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.notion.com/v1/search"} ->
          %Tesla.Env{
            status: 200,
            body: %{
              "results" => [
                %{
                  "id" => "pg-no-title",
                  "url" => "https://notion.so/pg-no-title",
                  "last_edited_time" => "2024-05-01T12:00:00Z",
                  "properties" => %{
                    "Tags" => %{"type" => "multi_select", "multi_select" => []}
                  }
                }
              ]
            }
          }
      end)

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      view
      |> form("form", %{query: "no title"})
      |> render_submit()

      rendered = render(view)
      assert rendered =~ "Untitled"
      assert rendered =~ "https://notion.so/pg-no-title"
    end

    test "handles search results with rich_text title", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          email: "rich-title@example.com",
          name: "Rich Title",
          role_id: Accounts.ensure_role!("employee").id
        })

      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.notion.com/v1/search"} ->
          %Tesla.Env{
            status: 200,
            body: %{
              "results" => [
                %{
                  "id" => "pg-rich",
                  "url" => "https://notion.so/pg-rich",
                  "last_edited_time" => "2024-05-01T12:00:00Z",
                  "properties" => %{
                    "Name" => %{
                      "type" => "rich_text",
                      "rich_text" => [%{"plain_text" => "Rich Title"}]
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
      |> form("form", %{query: "rich"})
      |> render_submit()

      rendered = render(view)
      assert rendered =~ "Rich Title"
    end

    test "handles search results with invalid last_edited_time", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          email: "invalid-date@example.com",
          name: "Invalid Date",
          role_id: Accounts.ensure_role!("employee").id
        })

      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.notion.com/v1/search"} ->
          %Tesla.Env{
            status: 200,
            body: %{
              "results" => [
                %{
                  "id" => "pg-invalid",
                  "url" => "https://notion.so/pg-invalid",
                  "last_edited_time" => "invalid-date",
                  "properties" => %{
                    "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Invalid Date"}]}
                  }
                }
              ]
            }
          }
      end)

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      view
      |> form("form", %{query: "invalid"})
      |> render_submit()

      rendered = render(view)
      assert rendered =~ "Invalid Date"
      # Should not show updated date since invalid
      refute rendered =~ "Updated"
    end

    test "handles search results with emoji icon type", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          email: "emoji-type@example.com",
          name: "Emoji Type",
          role_id: Accounts.ensure_role!("employee").id
        })

      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.notion.com/v1/search"} ->
          %Tesla.Env{
            status: 200,
            body: %{
              "results" => [
                %{
                  "id" => "pg-emoji",
                  "url" => "https://notion.so/pg-emoji",
                  "last_edited_time" => "2024-05-01T12:00:00Z",
                  "icon" => %{"type" => "emoji", "emoji" => "🚀"},
                  "properties" => %{
                    "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Emoji Icon"}]}
                  }
                }
              ]
            }
          }
      end)

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      view
      |> form("form", %{query: "emoji"})
      |> render_submit()

      rendered = render(view)
      assert rendered =~ "🚀"
      assert rendered =~ "Emoji Icon"
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

    test "clears search on x button keydown", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          email: "clear-key@example.com",
          name: "Clear Key",
          role_id: Accounts.ensure_role!("employee").id
        })

      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.notion.com/v1/search"} ->
          %Tesla.Env{status: 200, body: %{"results" => []}}
      end)

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      view
      |> form("form", %{query: "test"})
      |> render_change()

      assert render(view) =~ "test"

      view
      |> element("div[phx-click='clear_search']")
      |> render_keydown(%{key: "Enter"})

      html = render(view)
      refute html =~ "test"
    end

    test "clears search on x button click", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          email: "clear-click@example.com",
          name: "Clear Click",
          role_id: Accounts.ensure_role!("employee").id
        })

      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.notion.com/v1/search"} ->
          %Tesla.Env{status: 200, body: %{"results" => []}}
      end)

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      view
      |> form("form", %{query: "test"})
      |> render_change()

      assert render(view) =~ "test"

      view
      |> element("div[phx-click='clear_search']")
      |> render_click()

      html = render(view)
      refute html =~ "test"
    end

    test "handles async search result", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          email: "async@example.com",
          name: "Async",
          role_id: Accounts.ensure_role!("employee").id
        })

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      send(
        view.pid,
        {:search_result, "test",
         {:ok,
          %{
            "results" => [
              %{
                "id" => "page-1",
                "url" => "https://notion.so/page-1",
                "last_edited_time" => "2024-05-01T12:00:00Z",
                "properties" => %{
                  "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Async Test"}]}
                }
              }
            ]
          }}}
      )

      html = render(view)
      assert html =~ "Async Test"
    end

    test "handles async search error", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          email: "async-error@example.com",
          name: "Async Error",
          role_id: Accounts.ensure_role!("employee").id
        })

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      send(view.pid, {:search_result, "test", {:error, :timeout}})

      html = render(view)
      assert html =~ "Unable to reach Notion"
    end

    test "search with no results shows empty state", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          email: "no-results@example.com",
          name: "No Results",
          role_id: Accounts.ensure_role!("employee").id
        })

      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.notion.com/v1/search"} ->
          %Tesla.Env{
            status: 200,
            body: %{"results" => []}
          }

        _ ->
          %Tesla.Env{status: 404}
      end)

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      # Search for something that doesn't exist
      view |> form("form", %{query: "nonexistent"}) |> render_submit()

      assert render(view) =~ "No documents matched your search."
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

    test "typeahead search shows error on notion failure", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          email: "search-error@example.com",
          name: "Search Error",
          role_id: Accounts.ensure_role!("employee").id
        })

      # Mock notion_search HTTP request to return an error
      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.notion.com/v1/search"} ->
          {:error, :network_error}
      end)

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      # Perform search
      view
      |> form("form", %{query: "test"})
      |> render_change()

      # Check that error is shown
      html = render(view)
      assert html =~ "Unable to reach Notion"
    end

    test "handle_info ignores load_document for mismatched id", %{conn: _conn} do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          pending_document_id: "doc-1"
        }
      }

      {:noreply, new_socket} = Index.handle_info({:load_document, "doc-2", []}, socket)

      assert new_socket == socket
    end

    test "background update ignores when document not selected", %{conn: _conn} do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          selected_document_id: "doc-1"
        }
      }

      {:noreply, new_socket} =
        Index.handle_info({:check_document_update, "doc-2", DateTime.utc_now()}, socket)

      assert new_socket == socket
    end

    test "background update does nothing when document not changed", %{conn: _conn} do
      CacheStore.reset()

      Tesla.Mock.mock(fn
        %{method: :get, url: "https://api.notion.com/v1/pages/doc-1"} ->
          %Tesla.Env{
            status: 200,
            body: %{
              "id" => "doc-1",
              "last_edited_time" => "2024-05-01T10:00:00Z"
            }
          }
      end)

      Application.put_env(:dashboard_ssd, :notion_client, NotionMock)

      document = %Types.DocumentDetail{
        id: "doc-1",
        collection_id: "db-handbook",
        title: "Test Document",
        rendered_blocks: [],
        last_updated_at: ~U[2024-05-01 10:00:00Z],
        share_url: "https://notion.so/doc-1"
      }

      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          selected_document: document,
          selected_document_id: "doc-1"
        }
      }

      {:noreply, new_socket} =
        Index.handle_info({:check_document_update, "doc-1", document.last_updated_at}, socket)

      assert new_socket == socket
    end

    test "clear_search_key clears search on escape", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          email: "clear-escape@example.com",
          name: "Clear Escape",
          role_id: Accounts.ensure_role!("employee").id
        })

      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.notion.com/v1/search"} ->
          %Tesla.Env{status: 200, body: %{"results" => []}}
      end)

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      # Set search query
      view
      |> form("form", %{query: "test"})
      |> render_change()

      assert render(view) =~ "test"

      # Press escape
      view
      |> element("input[name='query']")
      |> render_keydown(%{key: "Escape"})

      html = render(view)
      refute html =~ "test"
    end

    test "select_document_key selects document on space", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          email: "select-space@example.com",
          name: "Select Space",
          role_id: Accounts.ensure_role!("employee").id
        })

      page = %{
        "id" => "page-1",
        "url" => "https://notion.so/page-1",
        "created_time" => "2024-05-01T10:00:00Z",
        "last_edited_time" => "2024-05-01T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Space Select"}]}
        }
      }

      NotionMock
      |> stub(:query_database, fn "tok", "db-handbook", _opts ->
        {:ok, %{"results" => [page], "has_more" => false, "next_cursor" => nil}}
      end)
      |> stub(:retrieve_page, fn "tok", "page-1", _opts -> {:ok, page} end)
      |> stub(:retrieve_block_children, fn "tok", "page-1", _opts ->
        {:ok, %{"results" => [], "has_more" => false, "next_cursor" => nil}}
      end)

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      # Select document with space key
      view
      |> element("button[phx-value-id='page-1']")
      |> render_keydown(%{key: " "})

      html = render(view)
      assert html =~ "Space Select"
    end

    test "close_mobile_menu sets mobile_menu_open to false", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          email: "close-menu@example.com",
          name: "Close Menu",
          role_id: Accounts.ensure_role!("employee").id
        })

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      # First open the menu
      view
      |> element("button[phx-click='toggle_mobile_menu']")
      |> render_click()

      assigns = view.pid |> :sys.get_state() |> Map.fetch!(:socket) |> Map.fetch!(:assigns)
      assert assigns.mobile_menu_open == true

      # Now close it
      view
      |> element("button[phx-click='close_mobile_menu']")
      |> render_click()

      assigns = view.pid |> :sys.get_state() |> Map.fetch!(:socket) |> Map.fetch!(:assigns)
      assert assigns.mobile_menu_open == false
    end

    test "toggle_mobile_menu closes when already open", %{conn: conn} do
      {:ok, user} =
        Accounts.create_user(%{
          email: "toggle-close@example.com",
          name: "Toggle Close",
          role_id: Accounts.ensure_role!("employee").id
        })

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      # Open the menu
      view
      |> element("button[phx-click='toggle_mobile_menu']")
      |> render_click()

      assigns = view.pid |> :sys.get_state() |> Map.fetch!(:socket) |> Map.fetch!(:assigns)
      assert assigns.mobile_menu_open == true

      # Toggle again to close
      view
      |> element("button[phx-click='toggle_mobile_menu']")
      |> render_click()

      assigns = view.pid |> :sys.get_state() |> Map.fetch!(:socket) |> Map.fetch!(:assigns)
      assert assigns.mobile_menu_open == false
    end
  end

  describe "event handling" do
    test "open_search_result loads the selected document without reloading collection" do
      CacheStore.reset()
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
      CacheStore.reset()

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

      CacheStore.put({:document_detail, "page-empty"}, detail, :timer.minutes(1))

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
      CacheStore.reset()

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

      CacheStore.put({:documents, "db-guides"}, [new_doc], :timer.minutes(1))
      CacheStore.put({:document_detail, "page-new"}, detail, :timer.minutes(1))

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
      assert Enum.map(new_socket.assigns.documents, & &1.id) == []
      assert new_socket.assigns.selected_document_id == "page-new"
      assert new_socket.assigns.reader_error == nil
    end

    test "close_search_dropdown sets dropdown to false" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          search_dropdown_open: true
        }
      }

      {:noreply, new_socket} = Index.handle_event("close_search_dropdown", %{}, socket)

      assert new_socket.assigns.search_dropdown_open == false
    end

    test "toggle_collection ignores nil id" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          expanded_collections: MapSet.new()
        }
      }

      {:noreply, new_socket} = Index.handle_event("toggle_collection", %{"id" => nil}, socket)

      assert new_socket == socket
    end

    test "toggle_collection collapses when already expanded" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          expanded_collections: MapSet.new(["db-handbook"]),
          documents_by_collection: %{},
          document_errors: %{}
        }
      }

      {:noreply, new_socket} =
        Index.handle_event("toggle_collection", %{"id" => "db-handbook"}, socket)

      assert MapSet.member?(new_socket.assigns.expanded_collections, "db-handbook") == false
    end

    test "toggle_collection expands when not expanded" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          expanded_collections: MapSet.new(),
          documents_by_collection: %{},
          document_errors: %{}
        }
      }

      {:noreply, new_socket} =
        Index.handle_event("toggle_collection", %{"id" => "db-guides"}, socket)

      assert MapSet.member?(new_socket.assigns.expanded_collections, "db-guides") == true
    end

    test "clear_search_key ignores invalid key" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          query: "test",
          results: [%{id: "1"}],
          search_performed: true
        }
      }

      {:noreply, new_socket} = Index.handle_event("clear_search_key", %{"key" => "A"}, socket)

      assert new_socket == socket
    end

    test "clear_search_key handles space key" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          flash: %{},
          query: "test",
          results: [%{id: "1"}],
          search_performed: true
        }
      }

      {:noreply, new_socket} = Index.handle_event("clear_search_key", %{"key" => " "}, socket)

      assert new_socket.assigns.query == ""
      assert new_socket.assigns.results == []
      assert new_socket.assigns.search_performed == false
    end

    test "clear_search_key handles escape key" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          flash: %{},
          query: "test",
          results: [%{id: "1"}],
          search_performed: true
        }
      }

      {:noreply, new_socket} =
        Index.handle_event("clear_search_key", %{"key" => "Escape"}, socket)

      assert new_socket.assigns.query == ""
      assert new_socket.assigns.results == []
      assert new_socket.assigns.search_performed == false
    end

    test "open_search_result_key ignores invalid key" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{}
        }
      }

      {:noreply, new_socket} =
        Index.handle_event("open_search_result_key", %{"key" => "A"}, socket)

      assert new_socket == socket
    end

    test "open_search_result_key handles Enter key" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          selected_collection_id: "db-handbook",
          documents: [
            %Types.DocumentSummary{id: "doc-1", collection_id: "db-handbook", title: "Test"}
          ],
          selected_document: nil,
          selected_document_id: nil,
          reader_error: nil,
          search_dropdown_open: true
        }
      }

      {:noreply, new_socket} =
        Index.handle_event("open_search_result_key", %{"id" => "doc-1", "key" => "Enter"}, socket)

      assert new_socket.assigns.selected_document_id == "doc-1"
      assert new_socket.assigns.search_dropdown_open == false
      assert new_socket.assigns.reader_loading == true
    end

    test "toggle_collection_key ignores invalid key" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          expanded_collections: MapSet.new()
        }
      }

      {:noreply, new_socket} =
        Index.handle_event("toggle_collection_key", %{"key" => "A"}, socket)

      assert new_socket == socket
    end

    test "toggle_collection_key handles Enter key" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          expanded_collections: MapSet.new(),
          documents_by_collection: %{},
          document_errors: %{}
        }
      }

      {:noreply, new_socket} =
        Index.handle_event(
          "toggle_collection_key",
          %{"id" => "db-guides", "key" => "Enter"},
          socket
        )

      assert MapSet.member?(new_socket.assigns.expanded_collections, "db-guides") == true
    end

    test "toggle_collection removes empty collection from list", %{conn: conn} do
      CacheStore.reset()
      Notion.reset_circuits()

      {:ok, user} =
        Accounts.create_user(%{
          email: "remove-empty@example.com",
          name: "Remove Empty",
          role_id: Accounts.ensure_role!("employee").id
        })

      Application.put_env(:dashboard_ssd, :integrations,
        notion_token: "tok",
        notion_curated_database_ids: ["db-empty"]
      )

      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        curated_collections: [%{"id" => "db-empty", "name" => "Empty Collection"}]
      )

      NotionMock
      |> stub(:query_database, fn "tok", "db-empty", _opts ->
        {:ok, %{"results" => [], "has_more" => false, "next_cursor" => nil}}
      end)

      conn = init_test_session(conn, %{user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/kb")

      # Initially should have the collection
      assert has_element?(view, "button[phx-value-id='db-empty']")

      # Toggle it to load documents (which are empty)
      view |> element("button[phx-value-id='db-empty']") |> render_click()

      # Should remove the collection since it has no documents
      assigns = view.pid |> :sys.get_state() |> Map.fetch!(:socket) |> Map.fetch!(:assigns)
      refute Enum.any?(assigns.collections, &(&1.id == "db-empty"))
    end

    test "select_document_key ignores invalid key" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{}
        }
      }

      {:noreply, new_socket} = Index.handle_event("select_document_key", %{"key" => "A"}, socket)

      assert new_socket == socket
    end

    test "select_document_key handles Enter key" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          selected_collection_id: "db-handbook",
          documents: [
            %Types.DocumentSummary{id: "doc-1", collection_id: "db-handbook", title: "Test Doc"}
          ],
          selected_document: nil,
          selected_document_id: nil,
          reader_error: nil,
          search_dropdown_open: true
        }
      }

      {:noreply, new_socket} =
        Index.handle_event("select_document_key", %{"id" => "doc-1", "key" => "Enter"}, socket)

      assert new_socket.assigns.selected_document_id == "doc-1"
      assert new_socket.assigns.selected_collection_id == "db-handbook"
      assert new_socket.assigns.search_dropdown_open == false
      assert new_socket.assigns.reader_loading == true
      assert new_socket.assigns.pending_document_id == "doc-1"
    end

    test "handle_info ignores mismatched document_id" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          pending_document_id: "doc-1"
        }
      }

      {:noreply, new_socket} = Index.handle_info({:load_document, "doc-2", %{}}, socket)

      assert new_socket == socket
    end

    test "handle_info processes matching document_id" do
      CacheStore.reset()

      {:ok, user} =
        Accounts.create_user(%{
          email: "load-doc@example.com",
          name: "Load Doc",
          role_id: Accounts.ensure_role!("employee").id
        })

      page = %{
        "id" => "page-load",
        "url" => "https://notion.so/page-load",
        "created_time" => "2024-05-01T10:00:00Z",
        "last_edited_time" => "2024-05-01T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Load Test"}]}
        }
      }

      NotionMock
      |> expect(:retrieve_page, fn "tok", "page-load", _opts -> {:ok, page} end)
      |> expect(:retrieve_block_children, fn "tok", "page-load", _opts ->
        {:ok, %{"results" => [], "has_more" => false, "next_cursor" => nil}}
      end)

      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          current_user: user,
          pending_document_id: "page-load",
          reader_loading: true,
          selected_document_id: "page-load",
          selected_document: nil,
          reader_error: nil,
          collections: [
            %DashboardSSD.KnowledgeBase.Types.Collection{
              id: "db-handbook",
              name: "Company Handbook"
            }
          ],
          collection_errors: [],
          selected_collection_id: "db-handbook",
          document_errors: %{},
          documents_by_collection: %{"db-handbook" => []},
          documents: [],
          recent_documents: [],
          recent_errors: [],
          expanded_collections: MapSet.new(),
          search_dropdown_open: false,
          query: "",
          results: [],
          search_performed: false
        }
      }

      {:noreply, new_socket} =
        Index.handle_info({:load_document, "page-load", [source: :url]}, socket)

      assert new_socket.assigns.pending_document_id == nil
      assert new_socket.assigns.reader_loading == false
      assert new_socket.assigns.selected_document.id == "page-load"
      assert new_socket.assigns.selected_document.title == "Load Test"
      assert new_socket.assigns.selected_document_id == "page-load"
      assert new_socket.assigns.reader_error == nil
    end

    test "handle_info uses cached document detail when available" do
      CacheStore.reset()

      document = %Types.DocumentDetail{
        id: "doc-cached",
        collection_id: nil,
        title: "Cached Document",
        rendered_blocks: [],
        share_url: "https://example.com/doc-cached",
        last_updated_at: ~U[2024-05-01 12:00:00Z]
      }

      CacheStore.put({:document_detail, document.id}, document)

      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          current_user: nil,
          pending_document_id: document.id,
          reader_loading: true,
          selected_document_id: nil,
          selected_document: nil,
          documents_by_collection: %{},
          document_errors: %{},
          selected_collection_id: nil,
          recent_documents: [],
          recent_errors: [],
          search_dropdown_open: true,
          search_performed: true,
          results: [%{id: "old"}],
          query: "cached"
        }
      }

      {:noreply, new_socket} =
        Index.handle_info({:load_document, document.id, [source: :search]}, socket)

      assert new_socket.assigns.selected_document.id == document.id
      assert new_socket.assigns.selected_document.title == "Cached Document"
      refute new_socket.assigns.reader_loading
      assert new_socket.assigns.pending_document_id == nil
      assert new_socket.assigns.results == []
      refute new_socket.assigns.search_performed
      refute new_socket.assigns.search_dropdown_open

      assert [%Types.RecentActivity{document_id: "doc-cached"} | _] =
               new_socket.assigns.recent_documents
    end

    test "handle_params loads document from URL params" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          pending_document_id: nil,
          reader_loading: false,
          selected_document_id: nil,
          selected_document: nil,
          reader_error: nil
        }
      }

      {:noreply, new_socket} =
        Index.handle_params(
          %{"document_id" => "page-params"},
          "http://example.com/kb?document_id=page-params",
          socket
        )

      assert new_socket.assigns.pending_document_id == "page-params"
      assert new_socket.assigns.reader_loading == true
      assert new_socket.assigns.selected_document_id == "page-params"
      assert new_socket.assigns.selected_document == nil

      assert_receive {:load_document, "page-params", opts}
      assert opts[:source] == :url
    end

    test "handle_params ignores params without document_id" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          pending_document_id: "existing",
          reader_loading: true,
          selected_document_id: "existing",
          selected_document: nil,
          reader_error: nil
        }
      }

      {:noreply, new_socket} = Index.handle_params(%{}, "http://example.com/kb", socket)

      assert new_socket == socket
    end

    test "copy_share_link sets flash message" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          flash: %{}
        }
      }

      {:noreply, new_socket} =
        Index.handle_event(
          "copy_share_link",
          %{"url" => "http://example.com/kb?document_id=test"},
          socket
        )

      assert new_socket.assigns.flash == %{"info" => "Share link copied to clipboard"}
    end

    test "clear_search resets search state" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          query: "test query",
          results: [%{id: "1"}],
          search_performed: true,
          search_dropdown_open: true,
          flash: %{"error" => "some error"}
        }
      }

      {:noreply, new_socket} = Index.handle_event("clear_search", %{}, socket)

      assert new_socket.assigns.query == ""
      assert new_socket.assigns.results == []
      assert new_socket.assigns.search_performed == false
      assert new_socket.assigns.search_dropdown_open == false
      assert new_socket.assigns.flash == %{}
    end

    test "close_search_dropdown closes dropdown" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          search_dropdown_open: true
        }
      }

      {:noreply, new_socket} = Index.handle_event("close_search_dropdown", %{}, socket)

      assert new_socket.assigns.search_dropdown_open == false
    end

    test "toggle_mobile_menu toggles menu state" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          mobile_menu_open: false
        }
      }

      {:noreply, new_socket} = Index.handle_event("toggle_mobile_menu", %{}, socket)

      assert new_socket.assigns.mobile_menu_open == true

      {:noreply, final_socket} = Index.handle_event("toggle_mobile_menu", %{}, new_socket)

      assert final_socket.assigns.mobile_menu_open == false
    end

    test "close_mobile_menu closes menu" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          mobile_menu_open: true
        }
      }

      {:noreply, new_socket} = Index.handle_event("close_mobile_menu", %{}, socket)

      assert new_socket.assigns.mobile_menu_open == false
    end

    test "typeahead_search handles missing env error" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          query: "",
          results: [],
          search_performed: false,
          search_loading: false,
          search_dropdown_open: false,
          flash: %{}
        }
      }

      # Mock the missing env error by clearing integrations config
      prev_integrations = Application.get_env(:dashboard_ssd, :integrations)
      Application.delete_env(:dashboard_ssd, :integrations)

      {:noreply, new_socket} =
        Index.handle_event("typeahead_search", %{"query" => "test"}, socket)

      # Restore config
      if prev_integrations do
        Application.put_env(:dashboard_ssd, :integrations, prev_integrations)
      end

      assert new_socket.assigns.query == "test"
      assert new_socket.assigns.results == []
      assert new_socket.assigns.search_performed == true
      assert new_socket.assigns.search_dropdown_open == true
      assert new_socket.assigns.flash == %{"error" => "Notion integration is not configured."}
    end

    test "typeahead_search handles generic error" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          query: "",
          results: [],
          search_performed: false,
          search_loading: false,
          search_dropdown_open: false,
          flash: %{}
        }
      }

      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.notion.com/v1/search"} ->
          {:error, :timeout}
      end)

      {:noreply, new_socket} =
        Index.handle_event("typeahead_search", %{"query" => "test"}, socket)

      assert new_socket.assigns.query == "test"
      assert new_socket.assigns.results == []
      assert new_socket.assigns.search_performed == true
      assert new_socket.assigns.search_dropdown_open == true
      assert new_socket.assigns.flash == %{"error" => "Unable to reach Notion (:timeout)."}
    end
  end

  defp live_assign(view, key) do
    view
    |> view_assigns()
    |> Map.get(key)
  end

  defp view_assigns(view) do
    view.pid
    |> :sys.get_state()
    |> Map.fetch!(:socket)
    |> Map.fetch!(:assigns)
  end

  defp base_socket(assigns) do
    %Phoenix.LiveView.Socket{
      endpoint: DashboardSSDWeb.Endpoint,
      view: Index,
      root_pid: self(),
      transport_pid: self(),
      private: %{live_temp: %{events: []}},
      assigns:
        %{__changed__: %{}, flash: %{}}
        |> Map.merge(assigns)
    }
  end

  defp restore_env(%{notion_token: token, notion_api_key: api_key}) do
    set_env("NOTION_TOKEN", token)
    set_env("NOTION_API_KEY", api_key)
  end

  defp set_env(key, nil), do: System.delete_env(key)
  defp set_env(key, value), do: System.put_env(key, value)
end
