defmodule DashboardSSD.KnowledgeBase.CatalogTest do
  use ExUnit.Case, async: false

  import Mox

  alias DashboardSSD.Integrations.{Notion, NotionMock}
  alias DashboardSSD.KnowledgeBase.{CacheStore, Catalog, Types}

  setup :verify_on_exit!

  setup do
    Mox.set_mox_global()

    prev_integrations = Application.get_env(:dashboard_ssd, :integrations)
    prev_kb = Application.get_env(:dashboard_ssd, DashboardSSD.KnowledgeBase)

    prev_env = %{
      notion_token: System.get_env("NOTION_TOKEN"),
      notion_api_key: System.get_env("NOTION_API_KEY")
    }

    System.delete_env("NOTION_TOKEN")
    System.delete_env("NOTION_API_KEY")

    on_exit(fn ->
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

      restore_env(prev_env)
      CacheStore.reset()
      Notion.reset_circuits()
    end)

    Application.put_env(:dashboard_ssd, :integrations,
      notion_token: "token",
      notion_curated_database_ids: ["db-handbook"]
    )

    Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
      curated_collections: [
        %{"id" => "db-handbook", "name" => "Company Handbook", "description" => "Everything HQ"}
      ],
      allowed_document_type_values: ["Wiki"],
      document_type_property_names: ["Type"],
      allow_documents_without_type?: true
    )

    CacheStore.reset()
    Notion.reset_circuits()

    :ok
  end

  describe "list_collections/1" do
    test "returns curated collections enriched with Notion metadata and caches results" do
      NotionMock
      |> expect(:query_database, fn "token", "db-handbook", opts ->
        assert Keyword.get(opts, :page_size) == 100

        {:ok,
         %{
           "results" => [
             %{"last_edited_time" => "2024-05-01T12:00:00Z"}
           ],
           "has_more" => false
         }}
      end)

      assert {:ok, %{collections: [collection], errors: []}} = Catalog.list_collections()

      assert %Types.Collection{
               id: "db-handbook",
               name: "Company Handbook",
               description: "Everything HQ",
               document_count: 1,
               last_document_updated_at: %DateTime{},
               last_synced_at: %DateTime{}
             } = collection

      # Second invocation should hit the cache and avoid another Notion call.
      assert {:ok, %{collections: [^collection], errors: []}} = Catalog.list_collections()
    end

    test "handles Notion errors when listing collections" do
      NotionMock
      |> expect(:list_databases, fn "token", _opts ->
        {:ok, %{"results" => [], "has_more" => false}}
      end)
      |> expect(:query_database, fn "token", "db-handbook", _opts ->
        {:error, :timeout}
      end)

      assert {:ok, %{collections: [], errors: [error]}} = Catalog.list_collections()
      assert error.collection_id == "db-handbook"
      assert error.reason == :timeout
    end

    test "bypasses cache for collections when cache? is false" do
      CacheStore.reset()
      Notion.reset_circuits()

      NotionMock
      |> expect(:query_database, 2, fn "token", "db-handbook", _opts ->
        {:ok,
         %{
           "results" => [
             %{"last_edited_time" => "2024-05-01T12:00:00Z"}
           ],
           "has_more" => false
         }}
      end)

      # First call with cache?: false
      assert {:ok, %{collections: [collection1], errors: []}} =
               Catalog.list_collections(cache?: false)

      # Second call with cache?: false should call Notion again
      assert {:ok, %{collections: [collection2], errors: []}} =
               Catalog.list_collections(cache?: false)

      assert collection1.id == "db-handbook"
      assert collection2.id == "db-handbook"
    end

    test "falls back to default curated ids when metadata missing" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        default_curated_database_ids: ["db-default"]
      )

      Application.put_env(:dashboard_ssd, :integrations,
        notion_token: "token",
        notion_curated_database_ids: ["db-default"]
      )

      CacheStore.reset()
      Notion.reset_circuits()

      NotionMock
      |> expect(:query_database, fn "token", "db-default", _opts ->
        {:ok, %{"results" => [], "has_more" => false}}
      end)

      assert {:ok, %{collections: [collection], errors: []}} = Catalog.list_collections()

      assert %Types.Collection{id: "db-default", name: "db-default"} = collection
      assert collection.document_count == 0
      assert collection.last_document_updated_at == nil
    end

    test "supports curated collections defined with atom keys" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        curated_collections: [%{id: "db-atom", name: "Atom Docs"}]
      )

      Application.put_env(:dashboard_ssd, :integrations,
        notion_token: "token",
        notion_curated_database_ids: ["db-atom"]
      )

      CacheStore.reset()
      Notion.reset_circuits()

      NotionMock
      |> stub(:query_database, fn _token, _id, _opts ->
        {:ok, %{"results" => [], "has_more" => false}}
      end)
      |> stub(:list_databases, fn _token, _opts ->
        {:ok, %{"results" => [], "has_more" => false}}
      end)

      assert {:ok, %{collections: [collection], errors: []}} = Catalog.list_collections()

      assert %Types.Collection{id: "db-atom", name: "Atom Docs"} = collection
    end

    test "surfaces errors when Notion requests fail" do
      NotionMock
      |> expect(:query_database, fn "token", "db-handbook", _opts ->
        {:error, :timeout}
      end)
      |> expect(:list_databases, fn "token", _opts ->
        {:ok,
         %{
           "results" => [],
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)

      assert {:ok,
              %{collections: [], errors: [%{collection_id: "db-handbook", reason: :timeout}]}} =
               Catalog.list_collections()
    end

    test "returns missing token error when configuration absent" do
      Application.delete_env(:dashboard_ssd, :integrations)

      assert {:error, {:missing_env, "NOTION_TOKEN"}} = Catalog.list_collections()
    end

    test "merges metadata and uses environment token fallback" do
      Application.delete_env(:dashboard_ssd, :integrations)
      System.put_env("NOTION_TOKEN", "env-token")

      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        curated_collections: [
          %{
            "id" => "db-meta",
            "name" => "Meta Collection",
            "icon" => "📚",
            "team" => "Eng"
          }
        ]
      )

      CacheStore.reset()
      Notion.reset_circuits()

      NotionMock
      |> expect(:query_database, fn "env-token", "db-meta", _opts ->
        {:ok, %{"total" => 5}}
      end)

      assert {:ok, %{collections: [collection], errors: []}} = Catalog.list_collections()

      assert collection.id == "db-meta"
      assert collection.icon == "📚"
      assert collection.document_count == 5
      assert collection.metadata == %{"team" => "Eng"}
    end

    test "bypasses cache when cache? option is false" do
      CacheStore.reset()
      Notion.reset_circuits()

      NotionMock
      |> expect(:query_database, 2, fn "token", "db-handbook", _opts ->
        {:ok, %{"results" => [], "has_more" => false}}
      end)

      assert {:ok, _} = Catalog.list_collections(cache?: false)
      assert {:ok, _} = Catalog.list_collections(cache?: false)
    end

    test "supports curated collections provided as keyword lists" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        curated_collections: [[id: "db-kw", name: "Keyword Docs", icon: "📘", owner: "kb"]]
      )

      Application.put_env(:dashboard_ssd, :integrations,
        notion_token: "token",
        notion_curated_database_ids: ["db-kw"]
      )

      CacheStore.reset()
      Notion.reset_circuits()

      NotionMock
      |> expect(:query_database, fn "token", "db-kw", _opts ->
        {:ok,
         %{
           "results" => [%{"last_edited_time" => "2024-05-10T10:00:00Z"}],
           "has_more" => false
         }}
      end)

      assert {:ok, %{collections: [collection], errors: []}} = Catalog.list_collections()
      assert collection.id == "db-kw"
      assert collection.name == "Keyword Docs"
      assert collection.icon == "📘"
      assert collection.metadata == %{owner: "kb"}
    end

    test "falls back to NOTION_API_KEY when integrations config missing" do
      Application.delete_env(:dashboard_ssd, :integrations)
      System.put_env("NOTION_API_KEY", "api-key")

      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        curated_collections: [%{"id" => "db-api", "name" => "API Collection"}]
      )

      CacheStore.reset()
      Notion.reset_circuits()

      NotionMock
      |> expect(:query_database, fn "api-key", "db-api", _opts ->
        {:ok, %{"results" => [], "has_more" => false}}
      end)

      assert {:ok, %{collections: [collection], errors: []}} = Catalog.list_collections()
      assert collection.id == "db-api"
    end

    test "filters curated collections using allowed ids configuration" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        curated_collections: [
          %{"id" => "db-allowed", "name" => "Visible"},
          %{"id" => "db-blocked", "name" => "Hidden"}
        ]
      )

      Application.put_env(:dashboard_ssd, :integrations,
        notion_token: "token",
        notion_curated_database_ids: ["db-allowed"]
      )

      CacheStore.reset()
      Notion.reset_circuits()

      NotionMock
      |> expect(:query_database, fn "token", "db-allowed", _opts ->
        {:ok, %{"results" => [], "has_more" => false}}
      end)

      assert {:ok, %{collections: [collection], errors: []}} = Catalog.list_collections()
      assert collection.id == "db-allowed"
    end

    test "bypasses cached collections when cache? option false" do
      CacheStore.reset()
      Notion.reset_circuits()

      NotionMock
      |> expect(:query_database, 2, fn "token", "db-handbook", _opts ->
        {:ok, %{"results" => [], "has_more" => false}}
      end)

      assert {:ok, %{collections: [_collection], errors: []}} =
               Catalog.list_collections(cache?: false)

      assert {:ok, %{collections: [_collection], errors: []}} =
               Catalog.list_collections(cache?: false)
    end

    test "accepts curated collections defined with atom identifiers" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        curated_collections: [%{id: :db_atom, name: "Atom Catalog"}]
      )

      Application.put_env(:dashboard_ssd, :integrations,
        notion_token: "token",
        notion_curated_database_ids: [:db_atom]
      )

      CacheStore.reset()
      Notion.reset_circuits()

      NotionMock
      |> expect(:query_database, fn "token", id, _opts ->
        assert id == :db_atom
        {:ok, %{"results" => [], "has_more" => false}}
      end)

      assert {:ok, %{collections: [collection], errors: []}} = Catalog.list_collections()
      assert collection.id == :db_atom
      assert collection.name == "Atom Catalog"
    end

    test "falls back to auto discovery when curated databases return 404" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        curated_collections: [%{"id" => "db-missing"}],
        auto_discover?: true
      )

      Application.put_env(:dashboard_ssd, :integrations, notion_token: "token")

      CacheStore.reset()
      Notion.reset_circuits()

      NotionMock
      |> expect(:query_database, fn "token", "db-missing", _opts ->
        {:error, {:http_error, 404, %{}}}
      end)
      |> expect(:list_databases, fn "token", _opts ->
        {:ok,
         %{
           "results" => [
             %{
               "id" => "db-auto-fallback",
               "title" => [%{"plain_text" => "Auto Fallback"}],
               "description" => [],
               "last_edited_time" => "2024-05-05T00:00:00Z",
               "properties" => %{}
             }
           ],
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)

      assert {:ok, %{collections: [collection], errors: []}} = Catalog.list_collections()

      assert collection.id == "db-auto-fallback"
    end

    test "auto discoves databases when no curated configuration is present" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase, auto_discover?: true)
      Application.put_env(:dashboard_ssd, :integrations, notion_token: "token")

      CacheStore.reset()
      Notion.reset_circuits()

      response = %{
        "results" => [
          %{
            "id" => "db-auto",
            "title" => [%{"plain_text" => "Auto DB"}],
            "description" => [%{"plain_text" => "Auto Description"}],
            "icon" => %{"emoji" => "📗"},
            "last_edited_time" => nil,
            "created_time" => "2024-04-01T12:00:00Z",
            "url" => "https://notion.so/db-auto",
            "parent" => %{"type" => "workspace"},
            "archived" => false,
            "properties" => %{}
          }
        ],
        "has_more" => false,
        "next_cursor" => nil
      }

      NotionMock
      |> expect(:list_databases, fn "token", opts ->
        assert Keyword.get(opts, :page_size) == 50
        {:ok, response}
      end)

      assert {:ok, %{collections: [collection], errors: []}} = Catalog.list_collections()
      assert collection.id == "db-auto"
      assert collection.name == "Auto DB"
      assert collection.description == "Auto Description"
      assert collection.icon == "📗"
      assert %DateTime{} = collection.last_synced_at
    end

    test "auto discovery respects allow and exclude lists" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        auto_discover?: true,
        exclude_database_ids: ["db-ignore"]
      )

      Application.put_env(:dashboard_ssd, :integrations,
        notion_token: "token",
        notion_curated_database_ids: ["db-allowed"]
      )

      CacheStore.reset()
      Notion.reset_circuits()

      response = %{
        "results" => [
          %{
            "id" => "db-allowed",
            "title" => [%{"plain_text" => "Allowed"}],
            "description" => [],
            "last_edited_time" => "2024-05-01T12:00:00Z",
            "icon" => nil,
            "properties" => %{}
          },
          %{
            "id" => "db-ignore",
            "title" => [%{"plain_text" => "Ignored"}],
            "description" => [],
            "last_edited_time" => "2024-05-02T12:00:00Z",
            "icon" => nil,
            "properties" => %{}
          },
          %{
            "id" => "db-unlisted",
            "title" => [%{"plain_text" => "Unlisted"}],
            "description" => [],
            "last_edited_time" => "2024-05-03T12:00:00Z",
            "icon" => nil,
            "properties" => %{}
          }
        ],
        "has_more" => false,
        "next_cursor" => nil
      }

      NotionMock
      |> expect(:list_databases, fn "token", _opts -> {:ok, response} end)

      assert {:ok, %{collections: [collection], errors: []}} = Catalog.list_collections()
      assert collection.id == "db-allowed"
    end

    test "auto discovery paginates through database listings" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase, auto_discover?: true)
      Application.put_env(:dashboard_ssd, :integrations, notion_token: "token")

      CacheStore.reset()
      Notion.reset_circuits()

      page_one = %{
        "results" => [
          %{
            "id" => "db-a",
            "title" => [%{"plain_text" => "A"}],
            "description" => [],
            "last_edited_time" => "2024-05-01T00:00:00Z",
            "properties" => %{}
          }
        ],
        "has_more" => true,
        "next_cursor" => "cursor-1"
      }

      page_two = %{
        "results" => [
          %{
            "id" => "db-b",
            "title" => [%{"plain_text" => "B"}],
            "description" => [],
            "last_edited_time" => "2024-05-02T00:00:00Z",
            "properties" => %{}
          }
        ],
        "has_more" => false,
        "next_cursor" => nil
      }

      NotionMock
      |> expect(:list_databases, fn "token", opts ->
        refute Keyword.has_key?(opts, :start_cursor)
        {:ok, page_one}
      end)
      |> expect(:list_databases, fn "token", opts ->
        assert Keyword.get(opts, :start_cursor) == "cursor-1"
        {:ok, page_two}
      end)

      assert {:ok, %{collections: collections, errors: []}} = Catalog.list_collections()
      assert Enum.map(collections, & &1.id) == ["db-a", "db-b"]
    end

    test "auto discovery surfaces errors from the Notion API" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase, auto_discover?: true)
      Application.put_env(:dashboard_ssd, :integrations, notion_token: "token")

      CacheStore.reset()
      Notion.reset_circuits()

      NotionMock
      |> expect(:list_databases, fn "token", _opts -> {:error, :timeout} end)

      assert {:ok, %{collections: [], errors: [%{reason: :timeout}]}} = Catalog.list_collections()
    end

    test "auto discovery enriches metadata and handles external icons" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase, auto_discover?: true)
      Application.put_env(:dashboard_ssd, :integrations, notion_token: "token")

      CacheStore.reset()
      Notion.reset_circuits()

      NotionMock
      |> expect(:list_databases, fn "token", _opts ->
        {:ok,
         %{
           "results" => [
             %{
               "id" => "db-meta",
               "title" => [%{"plain_text" => "Meta"}],
               "description" => [%{"plain_text" => "Detailed metadata"}],
               "icon" => %{
                 "type" => "external",
                 "external" => %{"url" => "https://example.com/icon.png"}
               },
               "last_edited_time" => "2024-05-03T07:30:00Z",
               "created_time" => "2024-04-01T08:00:00Z",
               "url" => "https://notion.so/db-meta",
               "parent" => %{"type" => "workspace"},
               "archived" => false,
               "properties" => %{"Name" => %{"type" => "title"}}
             }
           ],
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)

      assert {:ok, %{collections: [collection], errors: []}} = Catalog.list_collections()
      assert collection.icon == "https://example.com/icon.png"
      assert collection.description == "Detailed metadata"
      assert collection.metadata[:url] == "https://notion.so/db-meta"
      assert collection.metadata[:created_time] == "2024-04-01T08:00:00Z"
      assert collection.metadata[:last_edited_time] == "2024-05-03T07:30:00Z"
      assert collection.metadata[:archived] == false
      assert collection.metadata[:parent] == %{"type" => "workspace"}
      assert collection.metadata[:properties] == %{"Name" => %{"type" => "title"}}
    end

    test "auto page collection aggregates and caches pages" do
      Application.put_env(:dashboard_ssd, :integrations, notion_token: "token")

      CacheStore.reset()
      Notion.reset_circuits()

      page = %{
        "id" => "page-auto",
        "url" => "https://notion.so/page-auto",
        "created_time" => "2024-05-01T09:00:00Z",
        "last_edited_time" => "2024-05-05T12:00:00Z",
        "parent" => %{"type" => "workspace"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Auto Page"}]}
        }
      }

      NotionMock
      |> expect(:search, 1, fn "token", "", opts ->
        body = Keyword.fetch!(opts, :body)
        assert body[:page_size] == 50
        {:ok, %{"results" => [page], "has_more" => false, "next_cursor" => nil}}
      end)

      assert {:ok, %{documents: [doc], errors: []}} = Catalog.list_documents("kb:auto:pages")
      assert doc.id == "page-auto"
      assert doc.collection_id == "kb:auto:pages"
      assert doc.title == "Auto Page"

      # Second call should reuse cached data and avoid extra search calls.
      assert {:ok, %{documents: [cached_doc], errors: []}} =
               Catalog.list_documents("kb:auto:pages")

      assert cached_doc.id == "page-auto"
    end

    test "auto page collection respects include and exclude filters" do
      Application.put_env(:dashboard_ssd, :integrations, notion_token: "token")

      CacheStore.reset()
      Notion.reset_circuits()

      direct_match_page = %{
        "id" => "page-direct",
        "last_edited_time" => "2024-05-05T10:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-other"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Direct"}]}
        }
      }

      parent_match_page = %{
        "id" => "page-parent",
        "last_edited_time" => "2024-05-06T09:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-include"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Parent Match"}]}
        }
      }

      excluded_page = %{
        "id" => "page-exclude",
        "last_edited_time" => "2024-05-06T10:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-exclude"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Exclude Me"}]}
        }
      }

      empty_id_page = %{
        "id" => "",
        "last_edited_time" => "2024-05-07T08:00:00Z",
        "parent" => %{"type" => "workspace"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Empty"}]}
        }
      }

      NotionMock
      |> expect(:search, 1, fn "token", "", opts ->
        body = Keyword.fetch!(opts, :body)
        assert body[:page_size] == 50

        {:ok,
         %{
           "results" => [direct_match_page, parent_match_page, excluded_page, empty_id_page],
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)

      assert {:ok, %{documents: docs, errors: []}} =
               Catalog.list_documents("kb:auto:pages",
                 cache?: false,
                 include_ids: ["page-direct", "db-include"],
                 exclude_ids: ["db-exclude"]
               )

      assert Enum.map(docs, & &1.id) == ["page-parent", "page-direct"]
    end

    test "handles databases with empty title" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase, auto_discover?: true)
      Application.put_env(:dashboard_ssd, :integrations, notion_token: "token")

      CacheStore.reset()
      Notion.reset_circuits()

      response = %{
        "results" => [
          %{
            "id" => "db-empty-title",
            "title" => [],
            "description" => [],
            "last_edited_time" => "2024-05-01T12:00:00Z",
            "properties" => %{}
          }
        ],
        "has_more" => false,
        "next_cursor" => nil
      }

      NotionMock
      |> expect(:list_databases, fn "token", _opts -> {:ok, response} end)

      assert {:ok, %{collections: [collection], errors: []}} = Catalog.list_collections()
      assert collection.id == "db-empty-title"
      assert collection.name == "db-empty-title"
    end

    test "handles databases with empty description" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase, auto_discover?: true)
      Application.put_env(:dashboard_ssd, :integrations, notion_token: "token")

      CacheStore.reset()
      Notion.reset_circuits()

      response = %{
        "results" => [
          %{
            "id" => "db-empty-desc",
            "title" => [%{"plain_text" => "Empty Desc"}],
            "description" => [],
            "last_edited_time" => "2024-05-01T12:00:00Z",
            "properties" => %{}
          }
        ],
        "has_more" => false,
        "next_cursor" => nil
      }

      NotionMock
      |> expect(:list_databases, fn "token", _opts -> {:ok, response} end)

      assert {:ok, %{collections: [collection], errors: []}} = Catalog.list_collections()
      assert collection.id == "db-empty-desc"
      assert collection.description == nil
    end

    test "auto discovery handles emoji icons" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase, auto_discover?: true)
      Application.put_env(:dashboard_ssd, :integrations, notion_token: "token")

      CacheStore.reset()
      Notion.reset_circuits()

      NotionMock
      |> expect(:list_databases, fn "token", _opts ->
        {:ok,
         %{
           "results" => [
             %{
               "id" => "db-emoji",
               "title" => [%{"plain_text" => "Emoji DB"}],
               "description" => [],
               "icon" => %{"type" => "emoji", "emoji" => "📚"},
               "last_edited_time" => "2024-05-04T00:00:00Z",
               "properties" => %{}
             }
           ],
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)

      assert {:ok, %{collections: [collection], errors: []}} = Catalog.list_collections()
      assert collection.icon == "📚"
    end

    test "auto discovery handles unknown icon types" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase, auto_discover?: true)
      Application.put_env(:dashboard_ssd, :integrations, notion_token: "token")

      CacheStore.reset()
      Notion.reset_circuits()

      NotionMock
      |> expect(:list_databases, fn "token", _opts ->
        {:ok,
         %{
           "results" => [
             %{
               "id" => "db-unknown-icon",
               "title" => [%{"plain_text" => "Unknown Icon DB"}],
               "description" => [],
               "icon" => %{"type" => "unknown", "unknown" => "value"},
               "last_edited_time" => "2024-05-05T00:00:00Z",
               "properties" => %{}
             }
           ],
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)

      assert {:ok, %{collections: [collection], errors: []}} = Catalog.list_collections()
      assert collection.icon == nil
    end

    test "auto discovery clamps configured page size to Notion limits" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        auto_discover?: true,
        auto_discover_page_size: 250
      )

      Application.put_env(:dashboard_ssd, :integrations, notion_token: "token")

      CacheStore.reset()
      Notion.reset_circuits()

      NotionMock
      |> expect(:list_databases, fn "token", opts ->
        assert Keyword.get(opts, :page_size) == 100

        {:ok,
         %{
           "results" => [],
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)

      assert {:ok, %{collections: [], errors: []}} = Catalog.list_collections()
    end

    test "auto discovery caches results to avoid redundant API calls" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase, auto_discover?: true)
      Application.put_env(:dashboard_ssd, :integrations, notion_token: "token")

      CacheStore.reset()
      Notion.reset_circuits()

      NotionMock
      |> expect(:list_databases, fn "token", _opts ->
        {:ok,
         %{
           "results" => [
             %{
               "id" => "db-cache",
               "title" => [%{"plain_text" => "Cache"}],
               "description" => [],
               "last_edited_time" => "2024-05-01T00:00:00Z",
               "properties" => %{}
             }
           ],
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)

      assert {:ok, %{collections: [%Types.Collection{id: "db-cache"}], errors: []}} =
               Catalog.list_collections()

      # Second call should hit the cache and avoid another API roundtrip.
      assert {:ok, %{collections: [%Types.Collection{id: "db-cache"}], errors: []}} =
               Catalog.list_collections()
    end

    test "auto discovery does not prune when disabled" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        auto_discover?: true,
        hide_empty_collections: false
      )

      Application.put_env(:dashboard_ssd, :integrations, notion_token: "token")

      CacheStore.reset()
      Notion.reset_circuits()

      NotionMock
      |> expect(:list_databases, fn "token", _opts ->
        {:ok,
         %{
           "results" => [
             %{"id" => "db-a", "title" => [%{"plain_text" => "A"}], "properties" => %{}},
             %{"id" => "db-b", "title" => [%{"plain_text" => "B"}], "properties" => %{}}
           ],
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)

      assert {:ok, %{collections: collections, errors: []}} = Catalog.list_collections()
      assert Enum.map(collections, & &1.id) == ["db-a", "db-b"]
    end

    test "returns an empty set when auto discovery is disabled and no curated data exists" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase, auto_discover?: false)
      Application.put_env(:dashboard_ssd, :integrations, notion_token: "token")

      CacheStore.reset()
      Notion.reset_circuits()

      assert {:ok, %{collections: [], errors: []}} = Catalog.list_collections()
    end

    test "handles file icons, atom keys, and blank titles from Notion responses" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        auto_discover?: true,
        auto_discover_page_size: :invalid
      )

      Application.put_env(:dashboard_ssd, :integrations, notion_token: "token")

      CacheStore.reset()
      Notion.reset_circuits()

      NotionMock
      |> expect(:list_databases, fn "token", opts ->
        # Invalid configuration should fall back to the default page size.
        assert Keyword.get(opts, :page_size) == 50

        {:ok,
         %{
           results: [
             %{
               id: "db-atom",
               title: [%{plain_text: ""}],
               description: [%{plain_text: ""}],
               icon: %{
                 "type" => "file",
                 "file" => %{"url" => "https://example.com/icon-file.png"}
               },
               last_edited_time: "2024-05-04T00:00:00Z",
               created_time: "2024-05-01T00:00:00Z",
               url: "https://notion.so/db-atom",
               parent: %{type: "page_id", page_id: "page"},
               archived: true,
               properties: %{Name: %{type: "title"}}
             },
             %{
               id: nil,
               title: [],
               description: [],
               icon: nil,
               last_edited_time: nil
             }
           ],
           has_more: false,
           next_cursor: nil
         }}
      end)

      assert {:ok, %{collections: [collection], errors: []}} = Catalog.list_collections()
      assert collection.id == "db-atom"
      assert collection.name == "db-atom"
      assert collection.icon == "https://example.com/icon-file.png"
      assert collection.description == nil
      assert collection.metadata[:archived] == true
      assert collection.metadata[:parent] == %{type: "page_id", page_id: "page"}
    end

    test "handles has_more flag without a next cursor" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase, auto_discover?: true)
      Application.put_env(:dashboard_ssd, :integrations, notion_token: "token")

      CacheStore.reset()
      Notion.reset_circuits()

      NotionMock
      |> expect(:list_databases, fn "token", _opts ->
        {:ok,
         %{
           "results" => [%{"id" => "db-multi", "title" => [%{"plain_text" => "Multi"}]}],
           "has_more" => true,
           "next_cursor" => nil
         }}
      end)

      assert {:ok, %{collections: [%Types.Collection{id: "db-multi"}], errors: []}} =
               Catalog.list_collections()
    end

    test "normalizes include and exclude identifiers of varying types" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        auto_discover?: true,
        exclude_database_ids: [:blocked]
      )

      Application.put_env(:dashboard_ssd, :integrations,
        notion_token: "token",
        notion_curated_database_ids: [1234]
      )

      CacheStore.reset()
      Notion.reset_circuits()

      NotionMock
      |> expect(:list_databases, fn "token", _opts ->
        {:ok,
         %{
           "results" => [
             %{"id" => "1234", "title" => [%{"plain_text" => "Allowed"}]},
             %{"id" => "blocked", "title" => [%{"plain_text" => "Blocked"}]}
           ],
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)

      assert {:ok, %{collections: [collection], errors: []}} = Catalog.list_collections()
      assert collection.id == "1234"
    end

    test "auto discovery prunes empty databases when hide enabled and document_count is present" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        auto_discover?: true,
        hide_empty_collections: true
      )

      Application.put_env(:dashboard_ssd, :integrations, notion_token: "token")

      CacheStore.reset()
      Notion.reset_circuits()

      NotionMock
      |> expect(:list_databases, fn "token", _opts ->
        {:ok,
         %{
           "results" => [
             %{"id" => "db-empty", "title" => [%{"plain_text" => "Empty"}], "properties" => %{}},
             %{
               "id" => "db-nonempty",
               "title" => [%{"plain_text" => "Nonempty"}],
               "properties" => %{}
             }
           ],
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)
      |> expect(:query_database, fn "token", "db-empty", _opts ->
        {:ok, %{"results" => [], "total" => 0, "has_more" => false, "next_cursor" => nil}}
      end)
      |> expect(:query_database, fn "token", "db-nonempty", _opts ->
        {:ok,
         %{
           "results" => [
             %{
               "id" => "page-1",
               "last_edited_time" => "2024-05-01T00:00:00Z",
               "parent" => %{"type" => "database_id", "database_id" => "db-nonempty"},
               "properties" => %{
                 "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Doc"}]}
               }
             }
           ],
           "total" => 1,
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)

      assert {:ok, %{collections: collections, errors: []}} = Catalog.list_collections()
      assert Enum.map(collections, & &1.id) == ["db-nonempty"]
    end

    test "auto discovery prunes empty databases when hide enabled" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        auto_discover?: true,
        hide_empty_collections: true
      )

      Application.put_env(:dashboard_ssd, :integrations, notion_token: "token")

      CacheStore.reset()
      Notion.reset_circuits()

      NotionMock
      |> expect(:list_databases, fn "token", _opts ->
        {:ok,
         %{
           "results" => [
             %{"id" => "db-empty", "title" => [%{"plain_text" => "Empty"}], "properties" => %{}},
             %{
               "id" => "db-nonempty",
               "title" => [%{"plain_text" => "Nonempty"}],
               "properties" => %{}
             }
           ],
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)
      |> expect(:query_database, fn "token", "db-empty", _opts ->
        {:ok, %{"results" => [], "has_more" => false, "next_cursor" => nil}}
      end)
      |> expect(:query_database, fn "token", "db-nonempty", _opts ->
        {:ok,
         %{
           "results" => [
             %{
               "id" => "page-1",
               "last_edited_time" => "2024-05-01T00:00:00Z",
               "parent" => %{"type" => "database_id", "database_id" => "db-nonempty"},
               "properties" => %{
                 "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Doc"}]}
               }
             }
           ],
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)

      assert {:ok, %{collections: collections, errors: []}} = Catalog.list_collections()
      assert Enum.map(collections, & &1.id) == ["db-nonempty"]
    end
  end

  describe "list_documents/2" do
    test "returns document summaries for a collection" do
      CacheStore.reset()
      Notion.reset_circuits()

      page = %{
        "id" => "page-1",
        "url" => "https://notion.so/page-1",
        "created_time" => "2024-05-01T09:00:00Z",
        "last_edited_time" => "2024-05-01T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{
            "type" => "title",
            "title" => [%{"plain_text" => "Welcome"}]
          },
          "Summary" => %{
            "type" => "rich_text",
            "rich_text" => [%{"plain_text" => "Onboarding overview"}]
          },
          "Tags" => %{
            "type" => "multi_select",
            "multi_select" => [%{"name" => "Onboarding"}]
          },
          "Owner" => %{
            "type" => "people",
            "people" => [%{"name" => "Jane Doe"}]
          }
        }
      }

      NotionMock
      |> expect(:query_database, fn "token", "db-handbook", _opts ->
        {:ok, %{"results" => [page], "has_more" => false, "next_cursor" => nil}}
      end)

      assert {:ok, %{documents: [summary], errors: []}} =
               Catalog.list_documents("db-handbook")

      assert summary.id == "page-1"
      assert summary.title == "Welcome"
      assert summary.summary == "Onboarding overview"
      assert summary.tags == ["Onboarding"]
      assert summary.owner == "Jane Doe"
      assert summary.tags == ["Onboarding"]
      assert summary.collection_id == "db-handbook"
    end

    test "handles pages with empty title" do
      CacheStore.reset()
      Notion.reset_circuits()

      page = %{
        "id" => "page-empty-title",
        "url" => "https://notion.so/page-empty-title",
        "created_time" => "2024-05-01T09:00:00Z",
        "last_edited_time" => "2024-05-01T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => []}
        }
      }

      NotionMock
      |> expect(:query_database, fn "token", "db-handbook", _opts ->
        {:ok, %{"results" => [page], "has_more" => false, "next_cursor" => nil}}
      end)

      assert {:ok, %{documents: [summary], errors: []}} = Catalog.list_documents("db-handbook")
      assert summary.title == "Untitled"
    end

    test "handles pages with empty people property" do
      CacheStore.reset()
      Notion.reset_circuits()

      page = %{
        "id" => "page-empty-people",
        "url" => "https://notion.so/page-empty-people",
        "created_time" => "2024-05-01T09:00:00Z",
        "last_edited_time" => "2024-05-01T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Empty People"}]},
          "Owner" => %{"type" => "people", "people" => []}
        }
      }

      NotionMock
      |> expect(:query_database, fn "token", "db-handbook", _opts ->
        {:ok, %{"results" => [page], "has_more" => false, "next_cursor" => nil}}
      end)

      assert {:ok, %{documents: [summary], errors: []}} = Catalog.list_documents("db-handbook")
      assert summary.owner == "Unknown"
    end

    test "truncates long summaries" do
      CacheStore.reset()
      Notion.reset_circuits()

      long_text = String.duplicate("Summary text ", 50)

      page = %{
        "id" => "page-long-summary",
        "url" => "https://notion.so/page-long-summary",
        "created_time" => "2024-05-01T09:00:00Z",
        "last_edited_time" => "2024-05-01T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Long Summary"}]},
          "Summary" => %{"type" => "rich_text", "rich_text" => [%{"plain_text" => long_text}]}
        }
      }

      NotionMock
      |> expect(:query_database, fn "token", "db-handbook", _opts ->
        {:ok, %{"results" => [page], "has_more" => false, "next_cursor" => nil}}
      end)

      assert {:ok, %{documents: [summary], errors: []}} = Catalog.list_documents("db-handbook")
      assert String.ends_with?(summary.summary, "...")
      assert String.length(summary.summary) == 200
    end

    test "bypasses cache when cache? is false" do
      CacheStore.reset()
      Notion.reset_circuits()

      page = %{
        "id" => "page-2",
        "url" => "https://notion.so/page-2",
        "created_time" => "2024-05-02T09:00:00Z",
        "last_edited_time" => "2024-05-02T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{
            "type" => "title",
            "title" => [%{"plain_text" => "No Cache"}]
          }
        }
      }

      NotionMock
      |> expect(:query_database, fn "token", "db-handbook", _opts ->
        {:ok, %{"results" => [page], "has_more" => false, "next_cursor" => nil}}
      end)

      assert {:ok, %{documents: [summary], errors: []}} =
               Catalog.list_documents("db-handbook", cache?: false)

      assert summary.id == "page-2"
      assert summary.title == "No Cache"
    end

    test "derives tags and owners from various property combinations" do
      CacheStore.reset()
      Notion.reset_circuits()

      people_page = %{
        "id" => "page-people",
        "url" => "https://notion.so/page-people",
        "created_time" => "2024-05-05T09:00:00Z",
        "last_edited_time" => "2024-05-05T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "People"}]},
          "Tags" => %{
            "type" => "multi_select",
            "multi_select" => [%{"name" => "Alpha"}, %{"name" => "Beta"}]
          },
          "Owner" => %{
            "type" => "people",
            "people" => [%{"name" => "Jane"}, %{"name" => "Jon"}]
          }
        }
      }

      fallback_page = %{
        "id" => "page-fallback",
        "url" => "https://notion.so/page-fallback",
        "created_time" => "2024-05-06T09:00:00Z",
        "last_edited_time" => "2024-05-06T11:00:00Z",
        "last_edited_by" => %{"name" => "Editor"},
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Fallback"}]},
          "Notes" => %{
            "type" => "rich_text",
            "rich_text" => [%{"plain_text" => "  Snippet text  "}]
          }
        }
      }

      NotionMock
      |> expect(:query_database, fn "token", "db-handbook", _opts ->
        {:ok,
         %{
           "results" => [fallback_page, people_page],
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)

      assert {:ok, %{documents: [first, second], errors: []}} =
               Catalog.list_documents("db-handbook", cache?: false)

      assert first.id == "page-fallback"
      assert first.owner == "Editor"
      assert first.summary == "Snippet text"
      assert first.tags == []

      assert second.id == "page-people"
      assert second.owner == "Jane, Jon"
      assert second.tags == ["Alpha", "Beta"]
    end

    test "normalizes identifiers and truncates long summaries" do
      CacheStore.reset()
      Notion.reset_circuits()

      long_text = String.duplicate("Summary text ", 20)

      properties =
        [
          {"OwnerAtom", %{type: "people", people: [%{name: "Atom"}]}},
          {"Name", %{"type" => "title", "title" => [%{"plain_text" => "Normalized"}]}},
          {"Summary",
           %{
             "type" => "rich_text",
             "rich_text" => [%{"plain_text" => "  " <> long_text <> "  "}]
           }},
          {"Tags",
           %{
             "type" => "multi_select",
             "multi_select" => [%{"name" => "Alpha"}, %{"name" => "Beta"}]
           }}
        ]
        |> Enum.into(%{})

      page = %{
        "id" => "PAGE-UPPER-1234",
        "url" => "https://notion.so/page-upper-1234",
        "created_time" => "2024-05-07T09:00:00Z",
        "last_edited_time" => "2024-05-07T10:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "DB-HANDBOOK"},
        "properties" => properties
      }

      NotionMock
      |> expect(:query_database, fn "token", "db-handbook", _opts ->
        {:ok,
         %{
           "results" => [page],
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)

      assert {:ok, %{documents: [summary], errors: []}} =
               Catalog.list_documents("db-handbook", cache?: false)

      assert summary.id == "page-upper-1234"
      assert summary.collection_id == "db-handbook"
      assert summary.owner == "Atom"
      assert summary.tags == ["Alpha", "Beta"]
      assert String.ends_with?(summary.summary, "...")
      assert summary.metadata[:last_edited_time] == "2024-05-07T10:00:00Z"
    end

    test "handles status property for type filtering" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        allowed_document_type_values: ["Published"]
      )

      page = %{
        "id" => "page-status",
        "url" => "https://notion.so/page-status",
        "created_time" => "2024-05-01T10:00:00Z",
        "last_edited_time" => "2024-05-01T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Status Page"}]},
          "Type" => %{
            "type" => "status",
            "status" => %{"name" => "Published"}
          }
        }
      }

      NotionMock
      |> expect(:query_database, fn "token", "db-handbook", _opts ->
        {:ok, %{"results" => [page], "has_more" => false, "next_cursor" => nil}}
      end)

      assert {:ok, %{documents: [_]}} = Catalog.list_documents("db-handbook")
    end

    test "filters documents based on type when not allowed" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        allowed_document_type_values: ["Published"]
      )

      published_page = %{
        "id" => "page-published",
        "url" => "https://notion.so/page-published",
        "created_time" => "2024-05-01T10:00:00Z",
        "last_edited_time" => "2024-05-01T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Published Page"}]},
          "Type" => %{
            "type" => "status",
            "status" => %{"name" => "Published"}
          }
        }
      }

      draft_page = %{
        "id" => "page-draft",
        "url" => "https://notion.so/page-draft",
        "created_time" => "2024-05-01T11:00:00Z",
        "last_edited_time" => "2024-05-01T13:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Draft Page"}]},
          "Type" => %{
            "type" => "status",
            "status" => %{"name" => "Draft"}
          }
        }
      }

      NotionMock
      |> expect(:query_database, fn "token", "db-handbook", _opts ->
        {:ok,
         %{"results" => [draft_page, published_page], "has_more" => false, "next_cursor" => nil}}
      end)

      assert {:ok, %{documents: documents, errors: []}} = Catalog.list_documents("db-handbook")
      assert Enum.map(documents, & &1.id) == ["page-published"]
    end

    test "includes documents with null type name when allowing without type" do
      page = %{
        "id" => "page-null-type",
        "url" => "https://notion.so/page-null-type",
        "created_time" => "2024-06-01T09:00:00Z",
        "last_edited_time" => "2024-06-01T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{
            "type" => "title",
            "title" => [%{"plain_text" => "Null Type Doc"}]
          },
          "Type" => %{
            "type" => "select",
            "select" => %{"name" => nil}
          }
        }
      }

      NotionMock
      |> expect(:query_database, fn "token", "db-handbook", _opts ->
        {:ok, %{"results" => [page], "has_more" => false, "next_cursor" => nil}}
      end)

      assert {:ok, %{documents: [_], errors: []}} = Catalog.list_documents("db-handbook")
    end

    test "includes documents for exempt databases even when type is not allowlisted" do
      CacheStore.reset()
      Notion.reset_circuits()

      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        curated_collections: [
          %{"id" => "db-handbook", "name" => "Company Handbook"}
        ],
        allowed_document_type_values: ["Wiki"],
        document_type_property_names: ["Type"],
        allow_documents_without_type?: false,
        document_type_filter_exempt_ids: ["db-handbook"]
      )

      page = %{
        "id" => "page-task",
        "url" => "https://notion.so/page-task",
        "created_time" => "2024-06-01T09:00:00Z",
        "last_edited_time" => "2024-06-01T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
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

      NotionMock
      |> expect(:query_database, fn "token", "db-handbook", _opts ->
        {:ok, %{"results" => [page], "has_more" => false, "next_cursor" => nil}}
      end)

      assert {:ok, %{documents: [summary], errors: []}} = Catalog.list_documents("db-handbook")
      assert summary.id == "page-task"
    end

    test "filters documents based on multi-select type values" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        allowed_document_type_values: ["Guide", "Reference"],
        document_type_property_names: ["Category"]
      )

      multi_select_page = %{
        "id" => "page-multi",
        "url" => "https://notion.so/page-multi",
        "created_time" => "2024-06-03T09:00:00Z",
        "last_edited_time" => "2024-06-03T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Multi Select"}]},
          "Category" => %{
            "type" => "multi_select",
            "multi_select" => [
              %{"name" => "Guide"},
              %{"name" => "Reference"}
            ]
          }
        }
      }

      single_match_page = %{
        "id" => "page-single",
        "url" => "https://notion.so/page-single",
        "created_time" => "2024-06-03T10:00:00Z",
        "last_edited_time" => "2024-06-03T13:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Single Match"}]},
          "Category" => %{
            "type" => "multi_select",
            "multi_select" => [%{"name" => "Guide"}]
          }
        }
      }

      no_match_page = %{
        "id" => "page-no-match",
        "url" => "https://notion.so/page-no-match",
        "created_time" => "2024-06-03T11:00:00Z",
        "last_edited_time" => "2024-06-03T14:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "No Match"}]},
          "Category" => %{
            "type" => "multi_select",
            "multi_select" => [%{"name" => "Other"}]
          }
        }
      }

      NotionMock
      |> expect(:query_database, fn "token", "db-handbook", _opts ->
        {:ok,
         %{
           "results" => [no_match_page, multi_select_page, single_match_page],
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)

      assert {:ok, %{documents: documents, errors: []}} = Catalog.list_documents("db-handbook")
      assert Enum.map(documents, & &1.id) == ["page-single", "page-multi"]
    end

    test "includes documents without type when allow_documents_without_type? is true" do
      CacheStore.reset()
      Notion.reset_circuits()

      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        curated_collections: [
          %{"id" => "db-handbook", "name" => "Company Handbook"}
        ],
        allowed_document_type_values: ["Wiki"],
        document_type_property_names: ["Type"],
        allow_documents_without_type?: true
      )

      page = %{
        "id" => "page-no-type",
        "url" => "https://notion.so/page-no-type",
        "created_time" => "2024-06-02T09:00:00Z",
        "last_edited_time" => "2024-06-02T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{
            "type" => "title",
            "title" => [%{"plain_text" => "Untyped Doc"}]
          }
        }
      }

      NotionMock
      |> expect(:query_database, fn "token", "db-handbook", _opts ->
        {:ok, %{"results" => [page], "has_more" => false, "next_cursor" => nil}}
      end)

      assert {:ok, %{documents: [summary], errors: []}} = Catalog.list_documents("db-handbook")
      assert summary.id == "page-no-type"
      assert summary.title == "Untyped Doc"
    end

    test "returns errors when query fails" do
      NotionMock
      |> expect(:query_database, fn "token", "db-fail", _opts ->
        {:error, :timeout}
      end)

      assert {:ok, %{documents: [], errors: [%{collection_id: "db-fail", reason: :timeout}]}} =
               Catalog.list_documents("db-fail")
    end

    test "paginates database documents across cursors" do
      CacheStore.reset()
      Notion.reset_circuits()

      page_one = %{
        "id" => "page-1",
        "url" => "https://notion.so/page-1",
        "created_time" => "2024-05-01T09:00:00Z",
        "last_edited_time" => "2024-05-02T09:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Page One"}]}
        }
      }

      page_two = %{
        "id" => "page-2",
        "url" => "https://notion.so/page-2",
        "created_time" => "2024-05-03T09:00:00Z",
        "last_edited_time" => "2024-05-04T09:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Page Two"}]}
        }
      }

      NotionMock
      |> expect(:query_database, fn "token", "db-handbook", opts ->
        assert Keyword.get(opts, :start_cursor) == nil

        {:ok,
         %{
           "results" => [page_one],
           "has_more" => true,
           "next_cursor" => "cursor-1"
         }}
      end)
      |> expect(:query_database, fn "token", "db-handbook", opts ->
        assert Keyword.get(opts, :start_cursor) == "cursor-1"

        {:ok,
         %{
           "results" => [page_two],
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)

      assert {:ok, %{documents: documents, errors: []}} =
               Catalog.list_documents("db-handbook", cache?: false)

      assert Enum.map(documents, & &1.id) == ["page-2", "page-1"]
      assert Enum.map(documents, & &1.title) == ["Page Two", "Page One"]
    end

    test "returns documents for page collection" do
      Application.put_env(:dashboard_ssd, :integrations,
        notion_token: "token",
        notion_curated_database_ids: ["workspace"]
      )

      CacheStore.reset()
      Notion.reset_circuits()

      page = %{
        "id" => "page-1",
        "object" => "page",
        "url" => "https://notion.so/page-1",
        "created_time" => "2024-05-01T09:00:00Z",
        "last_edited_time" => "2024-05-01T12:00:00Z",
        "parent" => %{"type" => "workspace"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Page Doc"}]}
        }
      }

      NotionMock
      |> expect(:search, fn "token", "", _opts ->
        {:ok, %{"results" => [page], "has_more" => false, "next_cursor" => nil}}
      end)

      assert {:ok, %{documents: [summary], errors: []}} =
               Catalog.list_documents("kb:auto:pages", cache?: false)

      assert summary.id == "page-1"
      assert summary.title == "Page Doc"
    end

    test "filters pages with empty id" do
      Application.put_env(:dashboard_ssd, :integrations,
        notion_token: "token",
        notion_curated_database_ids: ["workspace"]
      )

      CacheStore.reset()
      Notion.reset_circuits()

      page = %{
        "id" => "",
        "object" => "page",
        "url" => "https://notion.so/page-empty",
        "created_time" => "2024-05-01T09:00:00Z",
        "last_edited_time" => "2024-05-01T12:00:00Z",
        "parent" => %{"type" => "workspace"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Empty ID"}]}
        }
      }

      NotionMock
      |> expect(:search, fn "token", "", _opts ->
        {:ok, %{"results" => [page], "has_more" => false, "next_cursor" => nil}}
      end)

      assert {:ok, %{documents: [], errors: []}} =
               Catalog.list_documents("kb:auto:pages", cache?: false)
    end

    test "excludes pages based on exclude ids" do
      Application.put_env(:dashboard_ssd, :integrations,
        notion_token: "token",
        notion_curated_database_ids: ["workspace"]
      )

      CacheStore.reset()
      Notion.reset_circuits()

      page = %{
        "id" => "page-excluded",
        "object" => "page",
        "url" => "https://notion.so/page-excluded",
        "created_time" => "2024-05-01T09:00:00Z",
        "last_edited_time" => "2024-05-01T12:00:00Z",
        "parent" => %{"type" => "workspace"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Excluded"}]}
        }
      }

      NotionMock
      |> expect(:search, fn "token", "", _opts ->
        {:ok, %{"results" => [page], "has_more" => false, "next_cursor" => nil}}
      end)

      assert {:ok, %{documents: [], errors: []}} =
               Catalog.list_documents("kb:auto:pages", cache?: false, exclude_ids: ["workspace"])
    end
  end

  describe "get_document/2" do
    setup do
      CacheStore.reset()
      Notion.reset_circuits()
      :ok
    end

    test "returns a document detail with normalized blocks" do
      page = %{
        "id" => "page-1",
        "url" => "https://notion.so/page-1",
        "created_time" => "2024-05-01T09:00:00Z",
        "last_edited_time" => "2024-05-01T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{
            "type" => "title",
            "title" => [%{"plain_text" => "Welcome"}]
          },
          "Tags" => %{
            "type" => "multi_select",
            "multi_select" => [%{"name" => "Onboarding"}]
          },
          "Owner" => %{
            "type" => "people",
            "people" => [%{"name" => "Jane Doe"}]
          }
        }
      }

      blocks_response = %{
        "results" => [
          %{
            "id" => "block-1",
            "type" => "heading_1",
            "has_children" => false,
            "heading_1" => %{"rich_text" => [%{"plain_text" => "Introductions"}]}
          },
          %{
            "id" => "block-2",
            "type" => "paragraph",
            "has_children" => false,
            "paragraph" => %{"rich_text" => [%{"plain_text" => "Welcome aboard"}]}
          }
        ],
        "has_more" => false,
        "next_cursor" => nil
      }

      NotionMock
      |> expect(:retrieve_page, fn "token", "page-1", _opts -> {:ok, page} end)
      |> expect(:retrieve_block_children, fn "token", "page-1", _opts ->
        {:ok, blocks_response}
      end)

      assert {:ok, detail} = Catalog.get_document("page-1")
      assert detail.id == "page-1"
      assert detail.collection_id == "db-handbook"
      assert detail.title == "Welcome"
      assert detail.owner == "Jane Doe"
      assert detail.tags == ["Onboarding"]
      assert Enum.map(detail.rendered_blocks, & &1.type) == [:heading_1, :paragraph]
    end

    test "handles block retrieval errors" do
      page = %{
        "id" => "page-error",
        "url" => "https://notion.so/page-error",
        "created_time" => "2024-05-01T09:00:00Z",
        "last_edited_time" => "2024-05-01T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{
            "type" => "title",
            "title" => [%{"plain_text" => "Error Doc"}]
          }
        }
      }

      NotionMock
      |> expect(:retrieve_page, fn "token", "page-error", _opts -> {:ok, page} end)
      |> expect(:retrieve_block_children, fn "token", "page-error", _opts ->
        {:error, :network_error}
      end)

      assert {:error, :network_error} = Catalog.get_document("page-error")
    end

    test "normalizes table blocks" do
      page = %{
        "id" => "page-table",
        "url" => "https://notion.so/page-table",
        "created_time" => "2024-05-10T09:00:00Z",
        "last_edited_time" => "2024-05-11T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Table Doc"}]}
        }
      }

      table_block = %{
        "id" => "table-1",
        "type" => "table",
        "has_children" => true,
        "table" => %{
          "has_column_header" => true,
          "has_row_header" => false,
          "table_width" => 2
        }
      }

      table_rows = %{
        "results" => [
          %{
            "id" => "row-1",
            "type" => "table_row",
            "has_children" => false,
            "table_row" => %{
              "cells" => [
                [%{"plain_text" => "Column A"}],
                [%{"plain_text" => "Column B"}]
              ]
            }
          },
          %{
            "id" => "row-2",
            "type" => "table_row",
            "has_children" => false,
            "table_row" => %{
              "cells" => [
                [%{"plain_text" => "Foo"}],
                [%{"plain_text" => "Bar"}]
              ]
            }
          }
        ],
        "has_more" => false,
        "next_cursor" => nil
      }

      page_blocks = %{
        "results" => [table_block],
        "has_more" => false,
        "next_cursor" => nil
      }

      NotionMock
      |> expect(:retrieve_page, fn "token", "page-table", _opts -> {:ok, page} end)
      |> expect(:retrieve_block_children, fn "token", "page-table", _opts ->
        {:ok, page_blocks}
      end)
      |> expect(:retrieve_block_children, fn "token", "table-1", _opts -> {:ok, table_rows} end)

      assert {:ok, detail} = Catalog.get_document("page-table")
      assert [%{type: :table} = table] = detail.rendered_blocks
      assert table.has_column_header? == true
      assert length(table.rows) == 2
      first_row = hd(table.rows)
      assert first_row.type == :table_row
      first_cell = first_row.cells |> hd() |> hd()
      assert first_cell.text == "Column A"
    end

    test "marks unknown blocks as unsupported" do
      page = %{
        "id" => "page-unknown",
        "url" => "https://notion.so/page-unknown",
        "created_time" => "2024-05-12T09:00:00Z",
        "last_edited_time" => "2024-05-12T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Mystery"}]}
        }
      }

      blocks_response = %{
        "results" => [
          %{
            "id" => "mystery",
            "type" => "unsupported_type",
            "has_children" => false,
            "unsupported_type" => %{}
          }
        ],
        "has_more" => false,
        "next_cursor" => nil
      }

      NotionMock
      |> expect(:retrieve_page, fn "token", "page-unknown", _opts -> {:ok, page} end)
      |> expect(:retrieve_block_children, fn "token", "page-unknown", _opts ->
        {:ok, blocks_response}
      end)

      assert {:ok, detail} = Catalog.get_document("page-unknown")
      assert [%{type: :unsupported, raw_type: "unsupported_type"}] = detail.rendered_blocks
    end

    test "normalizes common block types" do
      page = %{
        "id" => "page-blocks",
        "url" => "https://notion.so/page-blocks",
        "created_time" => "2024-05-12T10:00:00Z",
        "last_edited_time" => "2024-05-12T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Blocks"}]}
        }
      }

      blocks_response = %{
        "results" => [
          %{
            "id" => "para-1",
            "type" => "paragraph",
            "has_children" => false,
            "paragraph" => %{
              "rich_text" => [
                %{
                  "plain_text" => "Bold text",
                  "annotations" => %{
                    "bold" => true,
                    "italic" => true,
                    "strikethrough" => true,
                    "underline" => false,
                    "code" => false,
                    "color" => "red",
                    "unknown" => true
                  }
                },
                %{
                  "plain_text" => " code ",
                  "href" => "https://example.com",
                  "annotations" => %{
                    "bold" => false,
                    "italic" => false,
                    "strikethrough" => false,
                    "underline" => false,
                    "code" => true,
                    "color" => "default"
                  }
                }
              ]
            }
          },
          %{
            "id" => "heading-1",
            "type" => "heading_1",
            "has_children" => false,
            "heading_1" => %{"rich_text" => [%{"plain_text" => "Heading"}]}
          },
          %{
            "id" => "heading-2",
            "type" => "heading_2",
            "has_children" => false,
            "heading_2" => %{"rich_text" => [%{"plain_text" => "Subheading"}]}
          },
          %{
            "id" => "heading-3",
            "type" => "heading_3",
            "has_children" => false,
            "heading_3" => %{"rich_text" => [%{"plain_text" => "Tertiary"}]}
          },
          %{
            "id" => "bullet-1",
            "type" => "bulleted_list_item",
            "has_children" => false,
            "bulleted_list_item" => %{"rich_text" => [%{"plain_text" => "Bullet"}]}
          },
          %{
            "id" => "numbered-1",
            "type" => "numbered_list_item",
            "has_children" => false,
            "numbered_list_item" => %{"rich_text" => [%{"plain_text" => "Number"}]}
          },
          %{
            "id" => "quote-1",
            "type" => "quote",
            "has_children" => false,
            "quote" => %{"rich_text" => [%{"plain_text" => "Quote"}]}
          },
          %{
            "id" => "callout-1",
            "type" => "callout",
            "has_children" => false,
            "callout" => %{
              "icon" => %{"emoji" => "💡"},
              "rich_text" => [%{plain_text: "Callout"}]
            }
          },
          %{
            "id" => "code-1",
            "type" => "code",
            "has_children" => false,
            "code" => %{
              "language" => "bash",
              "rich_text" => [%{"plain_text" => "echo hi"}]
            }
          },
          %{
            "id" => "divider-1",
            "type" => "divider",
            "has_children" => false,
            "divider" => %{}
          },
          %{
            "id" => "image-1",
            "type" => "image",
            "has_children" => false,
            "image" => %{
              "type" => "external",
              "external" => %{"url" => "https://example.com/img.png"},
              "caption" => [%{"plain_text" => "Caption"}]
            }
          },
          %{
            "id" => "image-2",
            "type" => "image",
            "has_children" => false,
            "image" => %{
              "type" => "file",
              "file" => %{"url" => "https://example.com/upload.png"},
              "caption" => [%{"plain_text" => "Upload"}]
            }
          },
          %{
            "id" => "todo-1",
            "type" => "to_do",
            "has_children" => false,
            "to_do" => %{
              "rich_text" => [%{"plain_text" => "Task"}],
              "checked" => true
            }
          },
          %{
            "id" => "bookmark-1",
            "type" => "bookmark",
            "has_children" => false,
            "bookmark" => %{
              "url" => "https://example.com",
              "caption" => [%{"plain_text" => "Link"}]
            }
          }
        ],
        "has_more" => false,
        "next_cursor" => nil
      }

      NotionMock
      |> expect(:retrieve_page, fn "token", "page-blocks", _opts -> {:ok, page} end)
      |> expect(:retrieve_block_children, fn "token", "page-blocks", _opts ->
        {:ok, blocks_response}
      end)

      assert {:ok, detail} = Catalog.get_document("page-blocks")

      [
        paragraph,
        heading1,
        heading2,
        heading3,
        bullet,
        numbered,
        quote,
        callout,
        code,
        divider,
        image_ext,
        image_file,
        todo,
        bookmark
      ] =
        detail.rendered_blocks

      assert paragraph.type == :paragraph
      assert heading1.type == :heading_1 and heading1.level == 1
      assert heading2.type == :heading_2 and heading2.level == 2
      assert heading3.type == :heading_3 and heading3.level == 3
      assert bullet.type == :bulleted_list_item and bullet.style == :bullet
      assert numbered.type == :numbered_list_item and numbered.style == :numbered
      assert quote.type == :quote
      assert callout.type == :callout and callout.icon == %{"emoji" => "💡"}
      assert code.type == :code and code.language == "bash" and code.plain_text == "echo hi"
      assert divider.type == :divider
      assert image_ext.type == :image and image_ext.source == "https://example.com/img.png"
      assert image_file.type == :image and image_file.source == "https://example.com/upload.png"
      assert todo.type == :to_do and todo.checked == true and todo.plain_text == "Task"
      assert bookmark.type == :bookmark and bookmark.url == "https://example.com"
    end

    test "normalizes link_to_page blocks" do
      page = %{
        "id" => "page-link",
        "url" => "https://notion.so/page-link",
        "created_time" => "2024-05-12T10:05:00Z",
        "last_edited_time" => "2024-05-12T12:05:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Link"}]}
        }
      }

      blocks_response = %{
        "results" => [
          %{
            "id" => "link-1",
            "type" => "link_to_page",
            "has_children" => false,
            "link_to_page" => %{"type" => "page_id", "page_id" => "page-linked"}
          }
        ],
        "has_more" => false,
        "next_cursor" => nil
      }

      linked_page = %{
        "id" => "page-linked",
        "url" => "https://notion.so/page-linked",
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Linked Doc"}]}
        },
        "icon" => %{"emoji" => "📄"}
      }

      NotionMock
      |> expect(:retrieve_page, fn "token", "page-link", _opts -> {:ok, page} end)
      |> expect(:retrieve_block_children, fn "token", "page-link", _opts ->
        {:ok, blocks_response}
      end)
      |> expect(:retrieve_page, fn "token", "page-linked", _opts -> {:ok, linked_page} end)

      assert {:ok, detail} = Catalog.get_document("page-link")

      assert [link_block] = detail.rendered_blocks
      assert link_block.type == :link_to_page
      assert link_block.target_type == "page_id"
      assert link_block.target_id == "page-linked"
      assert link_block.target_title == "Linked Doc"
      assert link_block.target_icon == "📄"
      assert Enum.map(link_block.segments, & &1[:text]) == ["Linked Doc"]
    end

    test "link_to_page falls back when linked page unavailable" do
      page = %{
        "id" => "page-link-error",
        "url" => "https://notion.so/page-link-error",
        "created_time" => "2024-05-12T10:05:00Z",
        "last_edited_time" => "2024-05-12T12:05:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Link"}]}
        }
      }

      blocks_response = %{
        "results" => [
          %{
            "id" => "link-err",
            "type" => "link_to_page",
            "has_children" => false,
            "link_to_page" => %{"type" => "page_id", "page_id" => "missing-page"}
          }
        ],
        "has_more" => false,
        "next_cursor" => nil
      }

      NotionMock
      |> expect(:retrieve_page, fn "token", "page-link-error", _opts -> {:ok, page} end)
      |> expect(:retrieve_block_children, fn "token", "page-link-error", _opts ->
        {:ok, blocks_response}
      end)
      |> expect(:retrieve_page, fn "token", "missing-page", _opts -> {:error, :not_found} end)

      assert {:ok, detail} = Catalog.get_document("page-link-error")

      assert [%{type: :link_to_page, target_title: nil, target_icon: nil, segments: segments}] =
               detail.rendered_blocks

      assert Enum.map(segments, & &1[:text]) == ["Open linked page"]
    end

    test "link_to_page supports database targets" do
      page = %{
        "id" => "page-db-link",
        "url" => "https://notion.so/page-db-link",
        "created_time" => "2024-05-12T10:10:00Z",
        "last_edited_time" => "2024-05-12T12:10:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Link"}]}
        }
      }

      blocks_response = %{
        "results" => [
          %{
            "id" => "db-link",
            "type" => "link_to_page",
            "has_children" => false,
            "link_to_page" => %{"type" => "database_id", "database_id" => "db-target"}
          }
        ],
        "has_more" => false,
        "next_cursor" => nil
      }

      NotionMock
      |> expect(:retrieve_page, fn "token", "page-db-link", _opts -> {:ok, page} end)
      |> expect(:retrieve_block_children, fn "token", "page-db-link", _opts ->
        {:ok, blocks_response}
      end)

      assert {:ok, detail} = Catalog.get_document("page-db-link")

      assert [block] = detail.rendered_blocks
      assert block.type == :link_to_page
      assert block.target_type == "database_id"
      assert block.target_id == "db-target"
      assert Enum.map(block.segments, & &1[:text]) == ["Open linked database"]
    end

    test "link_to_page handles missing target id gracefully" do
      page = %{
        "id" => "page-link-missing",
        "url" => "https://notion.so/page-link-missing",
        "created_time" => "2024-05-12T10:15:00Z",
        "last_edited_time" => "2024-05-12T12:15:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Link"}]}
        }
      }

      blocks_response = %{
        "results" => [
          %{
            "id" => "link-missing",
            "type" => "link_to_page",
            "has_children" => false,
            "link_to_page" => %{"type" => "page_id", "page_id" => nil}
          }
        ],
        "has_more" => false,
        "next_cursor" => nil
      }

      NotionMock
      |> expect(:retrieve_page, fn "token", "page-link-missing", _opts -> {:ok, page} end)
      |> expect(:retrieve_block_children, fn "token", "page-link-missing", _opts ->
        {:ok, blocks_response}
      end)

      assert {:ok, detail} = Catalog.get_document("page-link-missing")

      assert [
               %{
                 type: :link_to_page,
                 target_id: target_id,
                 target_title: nil,
                 target_icon: nil,
                 segments: segments
               }
             ] = detail.rendered_blocks

      assert target_id == ""
      assert Enum.map(segments, & &1[:text]) == ["Open linked page"]
    end

    test "handles callout blocks without icon" do
      page = %{
        "id" => "page-callout-no-icon",
        "url" => "https://notion.so/page-callout-no-icon",
        "created_time" => "2024-05-12T10:00:00Z",
        "last_edited_time" => "2024-05-12T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Callout No Icon"}]}
        }
      }

      blocks_response = %{
        "results" => [
          %{
            "id" => "callout-no-icon",
            "type" => "callout",
            "has_children" => false,
            "callout" => %{
              "rich_text" => [%{"plain_text" => "Callout without icon"}]
            }
          }
        ],
        "has_more" => false,
        "next_cursor" => nil
      }

      NotionMock
      |> expect(:retrieve_page, fn "token", "page-callout-no-icon", _opts -> {:ok, page} end)
      |> expect(:retrieve_block_children, fn "token", "page-callout-no-icon", _opts ->
        {:ok, blocks_response}
      end)

      assert {:ok, detail} = Catalog.get_document("page-callout-no-icon")

      assert [%{type: :callout, icon: nil}] = detail.rendered_blocks
    end

    test "paginates block children and captures unsupported blocks" do
      page = %{
        "id" => "page-paginate",
        "url" => "https://notion.so/page-paginate",
        "created_time" => "2024-05-12T09:00:00Z",
        "last_edited_time" => "2024-05-12T11:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Pagination"}]}
        }
      }

      first_batch = %{
        "results" => [
          %{
            "id" => "block-1",
            "type" => "paragraph",
            "has_children" => false,
            "paragraph" => %{"rich_text" => [%{"plain_text" => "First"}]}
          }
        ],
        "has_more" => true,
        "next_cursor" => "cursor-1"
      }

      second_batch = %{
        "results" => [
          %{
            "id" => "block-2",
            "type" => "mystery_block",
            "has_children" => false,
            "mystery_block" => %{}
          }
        ],
        "has_more" => false,
        "next_cursor" => nil
      }

      NotionMock
      |> expect(:retrieve_page, fn "token", "page-paginate", _opts -> {:ok, page} end)
      |> expect(:retrieve_block_children, fn "token", "page-paginate", opts ->
        refute Keyword.has_key?(opts, :start_cursor)
        {:ok, first_batch}
      end)
      |> expect(:retrieve_block_children, fn "token", "page-paginate", opts ->
        assert Keyword.get(opts, :start_cursor) == "cursor-1"
        {:ok, second_batch}
      end)

      assert {:ok, detail} = Catalog.get_document("page-paginate", cache?: false)
      assert Enum.map(detail.rendered_blocks, & &1.type) == [:paragraph, :unsupported]

      unsupported =
        detail.rendered_blocks
        |> Enum.find(&(&1.type == :unsupported))

      assert unsupported.raw_type == "mystery_block"
    end

    test "handles block pagination errors during retrieval" do
      page = %{
        "id" => "page-paginate-error",
        "url" => "https://notion.so/page-paginate-error",
        "created_time" => "2024-05-12T09:00:00Z",
        "last_edited_time" => "2024-05-12T11:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Pagination Error"}]}
        }
      }

      first_batch = %{
        "results" => [
          %{
            "id" => "block-1",
            "type" => "paragraph",
            "has_children" => false,
            "paragraph" => %{"rich_text" => [%{"plain_text" => "First"}]}
          }
        ],
        "has_more" => true,
        "next_cursor" => "cursor-1"
      }

      NotionMock
      |> expect(:retrieve_page, fn "token", "page-paginate-error", _opts -> {:ok, page} end)
      |> expect(:retrieve_block_children, fn "token", "page-paginate-error", opts ->
        refute Keyword.has_key?(opts, :start_cursor)
        {:ok, first_batch}
      end)
      |> expect(:retrieve_block_children, fn "token", "page-paginate-error", opts ->
        assert Keyword.get(opts, :start_cursor) == "cursor-1"
        {:error, :pagination_timeout}
      end)

      assert {:error, :pagination_timeout} =
               Catalog.get_document("page-paginate-error", cache?: false)
    end

    test "handles block pagination with has_more but no next_cursor" do
      page = %{
        "id" => "page-incomplete",
        "url" => "https://notion.so/page-incomplete",
        "created_time" => "2024-05-15T09:00:00Z",
        "last_edited_time" => "2024-05-15T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Incomplete"}]}
        }
      }

      blocks_response = %{
        "results" => [
          %{
            "id" => "block-1",
            "type" => "paragraph",
            "has_children" => false,
            "paragraph" => %{"rich_text" => [%{"plain_text" => "Only block"}]}
          }
        ],
        "has_more" => true,
        "next_cursor" => nil
      }

      NotionMock
      |> expect(:retrieve_page, fn "token", "page-incomplete", _opts -> {:ok, page} end)
      |> expect(:retrieve_block_children, fn "token", "page-incomplete", _opts ->
        {:ok, blocks_response}
      end)

      assert {:ok, detail} = Catalog.get_document("page-incomplete", cache?: false)
      assert [%{type: :paragraph}] = detail.rendered_blocks
    end

    test "returns error when page retrieval fails" do
      NotionMock
      |> expect(:retrieve_page, fn "token", "page-error", _opts -> {:error, :timeout} end)

      assert {:error, :timeout} = Catalog.get_document("page-error", cache?: false)
    end

    test "handles block pagination errors by returning empty children" do
      page = %{
        "id" => "page-children",
        "url" => "https://notion.so/page-children",
        "created_time" => "2024-05-13T09:00:00Z",
        "last_edited_time" => "2024-05-13T10:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Children"}]}
        }
      }

      blocks = %{
        "results" => [
          %{
            "id" => "block-parent",
            "type" => "paragraph",
            "has_children" => true,
            "paragraph" => %{"rich_text" => [%{"plain_text" => "Parent"}]}
          }
        ],
        "has_more" => false,
        "next_cursor" => nil
      }

      NotionMock
      |> expect(:retrieve_page, fn "token", "page-children", _opts -> {:ok, page} end)
      |> expect(:retrieve_block_children, fn "token", "page-children", _opts -> {:ok, blocks} end)
      |> expect(:retrieve_block_children, fn "token", "block-parent", _opts ->
        {:error, :timeout}
      end)

      assert {:ok, detail} = Catalog.get_document("page-children", cache?: false)
      assert [%{children: []}] = detail.rendered_blocks
    end

    test "handles edge cases in block content processing" do
      page = %{
        "id" => "page-edge",
        "url" => "https://notion.so/page-edge",
        "created_time" => "2024-05-14T09:00:00Z",
        "last_edited_time" => "2024-05-14T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Edge Cases"}]}
        }
      }

      blocks_response = %{
        "results" => [
          %{
            "id" => "image-unknown",
            "type" => "image",
            "has_children" => false,
            "image" => %{
              "type" => "unknown",
              "unknown" => %{"url" => "https://example.com/unknown.png"},
              "caption" => [%{"plain_text" => "Unknown"}]
            }
          },
          %{
            "id" => "code-empty",
            "type" => "code",
            "has_children" => false,
            "code" => %{
              "language" => "elixir",
              "rich_text" => []
            }
          },
          %{
            "id" => "table-empty",
            "type" => "table",
            "has_children" => false,
            "table" => %{
              "has_column_header" => false,
              "has_row_header" => false,
              "table_width" => 1
            }
          }
        ],
        "has_more" => false,
        "next_cursor" => nil
      }

      NotionMock
      |> expect(:retrieve_page, fn "token", "page-edge", _opts -> {:ok, page} end)
      |> expect(:retrieve_block_children, fn "token", "page-edge", _opts ->
        {:ok, blocks_response}
      end)

      assert {:ok, detail} = Catalog.get_document("page-edge")

      [image, code, table] = detail.rendered_blocks

      assert image.type == :image
      assert image.source == nil
      assert image.caption == [%{annotations: %{}, href: nil, text: "Unknown", type: nil}]

      assert code.type == :code
      assert code.language == "elixir"
      assert code.plain_text == ""
      assert code.segments == []

      assert table.type == :table
      assert table.rows == []
      assert table.has_column_header? == false
      assert table.has_row_header? == false
      assert table.table_width == 1
    end

    test "normalizes bookmark blocks" do
      page = %{
        "id" => "page-bookmark",
        "url" => "https://notion.so/page-bookmark",
        "created_time" => "2024-05-14T09:00:00Z",
        "last_edited_time" => "2024-05-14T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Bookmark"}]}
        }
      }

      blocks_response = %{
        "results" => [
          %{
            "id" => "bookmark-1",
            "type" => "bookmark",
            "has_children" => false,
            "bookmark" => %{
              "url" => "https://example.com",
              "caption" => [%{"plain_text" => "Link"}]
            }
          }
        ],
        "has_more" => false,
        "next_cursor" => nil
      }

      NotionMock
      |> expect(:retrieve_page, fn "token", "page-bookmark", _opts -> {:ok, page} end)
      |> expect(:retrieve_block_children, fn "token", "page-bookmark", _opts ->
        {:ok, blocks_response}
      end)

      assert {:ok, detail} = Catalog.get_document("page-bookmark")

      [bookmark] = detail.rendered_blocks

      assert bookmark.type == :bookmark
      assert bookmark.url == "https://example.com"
      assert bookmark.caption == [%{annotations: %{}, href: nil, text: "Link", type: nil}]
    end

    test "get_document bypasses cache when cache? is false" do
      page = %{
        "id" => "page-no-cache",
        "url" => "https://notion.so/page-no-cache",
        "created_time" => "2024-05-01T09:00:00Z",
        "last_edited_time" => "2024-05-01T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-handbook"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "No Cache"}]}
        }
      }

      blocks_response = %{
        "results" => [
          %{
            "id" => "block-1",
            "type" => "paragraph",
            "has_children" => false,
            "paragraph" => %{"rich_text" => [%{"plain_text" => "No cache content"}]}
          }
        ],
        "has_more" => false,
        "next_cursor" => nil
      }

      NotionMock
      |> expect(:retrieve_page, fn "token", "page-no-cache", _opts -> {:ok, page} end)
      |> expect(:retrieve_block_children, fn "token", "page-no-cache", _opts ->
        {:ok, blocks_response}
      end)

      assert {:ok, detail} = Catalog.get_document("page-no-cache", cache?: false)
      assert detail.id == "page-no-cache"
      assert detail.title == "No Cache"
    end
  end

  describe "auto discover pages" do
    setup do
      Application.put_env(:dashboard_ssd, :integrations,
        notion_token: "token",
        notion_curated_database_ids: []
      )

      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        curated_collections: [],
        auto_discover?: true,
        auto_discover_mode: :pages,
        allowed_document_type_values: ["Wiki"],
        document_type_property_names: ["Type"],
        allow_documents_without_type?: false,
        auto_page_collection_id: "kb:auto:pages",
        auto_page_collection_name: "Wiki Pages"
      )

      CacheStore.reset()
      Notion.reset_circuits()
      :ok
    end

    test "returns wiki pages from Notion search" do
      page = %{
        "id" => "page-1",
        "url" => "https://notion.so/page-1",
        "last_edited_time" => "2024-06-01T12:00:00Z",
        "parent" => %{"type" => "workspace"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Onboarding Guide"}]},
          "Type" => %{"type" => "select", "select" => %{"name" => "Wiki"}}
        }
      }

      NotionMock
      |> expect(:search, fn "token", "", opts ->
        body = Keyword.fetch!(opts, :body)
        assert get_in(body, [:filter, :value]) == "page"
        assert get_in(body, [:sort, :timestamp]) == "last_edited_time"

        {:ok,
         %{
           "results" => [page],
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)

      assert {:ok, %{collections: [collection], errors: []}} =
               Catalog.list_collections(cache?: false)

      assert %Types.Collection{
               id: "kb:auto:pages",
               name: "Wiki Pages",
               document_count: 1
             } = collection

      assert {:ok, %{documents: [document], errors: []}} =
               Catalog.list_documents("kb:auto:pages", cache?: false)

      assert document.id == "page-1"
      assert document.title == "Onboarding Guide"
      assert document.collection_id == "kb:auto:pages"
    end

    test "paginates auto-discovered pages across cursors" do
      first_page = %{
        "results" => [
          %{
            "id" => "page-first",
            "url" => "https://notion.so/page-first",
            "last_edited_time" => "2024-06-06T09:00:00Z",
            "parent" => %{"type" => "workspace"},
            "properties" => %{
              "Name" => %{"type" => "title", "title" => [%{"plain_text" => "First"}]},
              "Type" => %{"type" => "select", "select" => %{"name" => "Wiki"}}
            }
          }
        ],
        "has_more" => true,
        "next_cursor" => "cursor-1"
      }

      second_page = %{
        "results" => [
          %{
            "id" => "page-second",
            "url" => "https://notion.so/page-second",
            "last_edited_time" => "2024-06-06T10:00:00Z",
            "parent" => %{"type" => "workspace"},
            "properties" => %{
              "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Second"}]},
              "Type" => %{"type" => "select", "select" => %{"name" => "Wiki"}}
            }
          }
        ],
        "has_more" => false,
        "next_cursor" => nil
      }

      NotionMock
      |> expect(:search, fn "token", "", opts ->
        body = Keyword.fetch!(opts, :body)
        refute Map.has_key?(body, :start_cursor)
        {:ok, first_page}
      end)
      |> expect(:search, fn "token", "", opts ->
        body = Keyword.fetch!(opts, :body)
        assert Map.get(body, :start_cursor) == "cursor-1"
        {:ok, second_page}
      end)

      assert {:ok, %{collections: [collection], errors: []}} =
               Catalog.list_collections(cache?: false)

      assert collection.document_count == 2

      assert {:ok, %{documents: docs, errors: []}} =
               Catalog.list_documents(collection.id, cache?: false)

      assert Enum.map(docs, & &1.id) == ["page-second", "page-first"]
    end

    test "paginates Notion page search across cursors" do
      first_batch = %{
        "results" => [
          %{
            "id" => "page-first",
            "url" => "https://notion.so/page-first",
            "last_edited_time" => "2024-06-06T09:00:00Z",
            "parent" => %{"type" => "workspace"},
            "properties" => %{
              "Name" => %{"type" => "title", "title" => [%{"plain_text" => "First"}]},
              "Type" => %{"type" => "select", "select" => %{"name" => "Wiki"}}
            }
          }
        ],
        "has_more" => true,
        "next_cursor" => "cursor-1"
      }

      second_batch = %{
        "results" => [
          %{
            "id" => "page-second",
            "url" => "https://notion.so/page-second",
            "last_edited_time" => "2024-06-06T10:00:00Z",
            "parent" => %{"type" => "workspace"},
            "properties" => %{
              "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Second"}]},
              "Type" => %{"type" => "select", "select" => %{"name" => "Wiki"}}
            }
          }
        ],
        "has_more" => false,
        "next_cursor" => nil
      }

      NotionMock
      |> expect(:search, fn "token", "", opts ->
        body = Keyword.fetch!(opts, :body)
        refute Map.has_key?(body, :start_cursor)
        {:ok, first_batch}
      end)
      |> expect(:search, fn "token", "", opts ->
        body = Keyword.fetch!(opts, :body)
        assert Map.get(body, :start_cursor) == "cursor-1"
        {:ok, second_batch}
      end)

      assert {:ok, %{collections: [collection], errors: []}} =
               Catalog.list_collections(cache?: false)

      assert collection.document_count == 2

      assert {:ok, %{documents: documents, errors: []}} =
               Catalog.list_documents(collection.id, cache?: false)

      assert Enum.map(documents, & &1.id) == ["page-second", "page-first"]
    end

    test "filters out pages with disallowed parents or type" do
      allowed_page = %{
        "id" => "page-allowed",
        "url" => "https://notion.so/page-allowed",
        "last_edited_time" => "2024-06-02T09:00:00Z",
        "parent" => %{"type" => "page_id", "page_id" => "parent-page"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Team Handbook"}]},
          "Type" => %{"type" => "select", "select" => %{"name" => "Wiki"}}
        }
      }

      blocked_page = %{
        "id" => "page-blocked",
        "url" => "https://notion.so/page-blocked",
        "last_edited_time" => "2024-06-02T10:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-tracker"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Daily Tasks"}]},
          "Type" => %{"type" => "select", "select" => %{"name" => "Task"}}
        }
      }

      atom_parent_page = %{
        "id" => "page-atom",
        "url" => "https://notion.so/page-atom",
        "last_edited_time" => "2024-06-02T11:00:00Z",
        "parent" => %{type: "page_id", page_id: "parent-page"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Atom"}]},
          "Type" => %{"type" => "select", "select" => %{"name" => "Wiki"}}
        }
      }

      NotionMock
      |> expect(:search, fn "token", "", _opts ->
        {:ok,
         %{
           "results" => [blocked_page, allowed_page, atom_parent_page],
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)

      assert {:ok, %{collections: [collection], errors: []}} =
               Catalog.list_collections(cache?: false)

      assert collection.document_count == 2

      assert {:ok, %{documents: documents, errors: []}} =
               Catalog.list_documents(collection.id, cache?: false)

      assert Enum.map(documents, & &1.id) == ["page-atom", "page-allowed"]
      assert Enum.map(documents, & &1.title) == ["Atom", "Team Handbook"]
    end

    test "restricts pages to include allowlist" do
      Application.put_env(:dashboard_ssd, :integrations,
        notion_token: "token",
        notion_curated_database_ids: ["28c54068269180b485eaff844489f9ba"]
      )

      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        curated_collections: [],
        auto_discover?: true,
        auto_discover_mode: :pages,
        allowed_document_type_values: ["Wiki"],
        document_type_property_names: ["Type"],
        allow_documents_without_type?: false
      )

      CacheStore.reset()
      Notion.reset_circuits()

      kept_page = %{
        "id" => "28c54068-2691-80b4-85ea-ff844489f9ba",
        "url" => "https://notion.so/page-keep",
        "last_edited_time" => "2024-06-03T09:00:00Z",
        "parent" => %{
          "type" => "page_id",
          "page_id" => "28c54068-2691-80b4-85ea-ff844489f9ba"
        },
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "KB Page"}]},
          "Type" => %{"type" => "select", "select" => %{"name" => "Wiki"}}
        }
      }

      other_page = %{
        "id" => "ffffffff-ffff-ffff-ffff-ffffffffffff",
        "url" => "https://notion.so/page-drop",
        "last_edited_time" => "2024-06-03T11:00:00Z",
        "parent" => %{
          "type" => "database_id",
          "database_id" => "ffffffff-ffff-ffff-ffff-ffffffffffff"
        },
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Other"}]},
          "Type" => %{"type" => "select", "select" => %{"name" => "Wiki"}}
        }
      }

      NotionMock
      |> expect(:search, fn "token", "", _opts ->
        {:ok,
         %{
           "results" => [kept_page, other_page],
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)

      assert {:ok, %{collections: [collection], errors: []}} =
               Catalog.list_collections(cache?: false)

      assert {:ok, %{documents: [document], errors: doc_errors}} =
               Catalog.list_documents(collection.id, cache?: false)

      assert doc_errors == []

      assert document.id == "28c54068269180b485eaff844489f9ba"
      assert document.title == "KB Page"
      assert collection.metadata[:include_ids] == ["28c54068269180b485eaff844489f9ba"]
    end

    test "excludes pages whose parents are on the blocklist" do
      Application.put_env(:dashboard_ssd, :integrations,
        notion_token: "token",
        notion_curated_database_ids: ["parent-include"]
      )

      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        curated_collections: [],
        auto_discover?: true,
        auto_discover_mode: :pages,
        allowed_document_type_values: ["Wiki"],
        document_type_property_names: ["Type"],
        allow_documents_without_type?: true,
        exclude_database_ids: ["parent-blocked"]
      )

      CacheStore.reset()
      Notion.reset_circuits()

      blocked = %{
        "id" => "page-blocked",
        "url" => "https://notion.so/page-blocked",
        "last_edited_time" => "2024-06-04T09:00:00Z",
        "parent" => %{"type" => "page_id", "page_id" => "parent-blocked"},
        "properties" => %{"Type" => %{"type" => "select", "select" => %{"name" => "Wiki"}}}
      }

      allowed = %{
        "id" => "page-allowed",
        "url" => "https://notion.so/page-allowed",
        "last_edited_time" => "2024-06-04T08:00:00Z",
        "parent" => %{"type" => "page_id", "page_id" => "parent-include"},
        "properties" => %{"Type" => %{"type" => "select", "select" => %{"name" => "Wiki"}}}
      }

      NotionMock
      |> expect(:search, fn "token", "", _opts ->
        {:ok,
         %{
           "results" => [blocked, allowed],
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)

      assert {:ok, %{collections: [collection], errors: []}} =
               Catalog.list_collections(cache?: false)

      assert {:ok, %{documents: [document], errors: []}} =
               Catalog.list_documents(collection.id, cache?: false)

      assert document.id == "page-allowed"
      assert collection.metadata[:exclude_ids] == ["parent-blocked"]
    end

    test "ignores pages with blank identifiers" do
      NotionMock
      |> expect(:search, fn "token", "", _opts ->
        {:ok,
         %{
           "results" => [
             %{
               "id" => "",
               "url" => "https://notion.so/ignore",
               "last_edited_time" => "2024-06-05T09:00:00Z",
               "parent" => %{"type" => "workspace"},
               "properties" => %{
                 "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Ignore"}]},
                 "Type" => %{"type" => "select", "select" => %{"name" => "Wiki"}}
               }
             },
             %{
               "id" => "page-keep",
               "url" => "https://notion.so/keep",
               "last_edited_time" => "2024-06-05T10:00:00Z",
               "parent" => %{"type" => "workspace"},
               "properties" => %{
                 "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Keep"}]},
                 "Type" => %{"type" => "select", "select" => %{"name" => "Wiki"}}
               }
             }
           ],
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)

      assert {:ok, %{collections: [collection], errors: []}} =
               Catalog.list_collections(cache?: false)

      assert collection.document_count == 1

      assert {:ok, %{documents: [document], errors: []}} =
               Catalog.list_documents(collection.id, cache?: false)

      assert document.id == "page-keep"
    end

    test "returns errors when Notion page search fails" do
      NotionMock
      |> expect(:search, fn "token", "", _opts -> {:error, :timeout} end)

      assert {:ok, %{collections: [], errors: [%{reason: :timeout}]}} =
               Catalog.list_collections(cache?: false)
    end

    test "list_documents surfaces errors from page fetch" do
      NotionMock
      |> expect(:search, fn "token", "", _opts -> {:error, :timeout} end)

      assert {:ok,
              %{documents: [], errors: [%{collection_id: "kb:auto:pages", reason: :timeout}]}} =
               Catalog.list_documents("kb:auto:pages", cache?: false)
    end
  end

  describe "allowed_document?/1 with atoms and numbers" do
    setup do
      prev_kb = Application.get_env(:dashboard_ssd, DashboardSSD.KnowledgeBase)

      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        allowed_document_type_values: [:wiki, 42],
        document_type_property_names: ["Type", :Status, 123],
        allow_documents_without_type?: false
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

    test "accepts select and status properties" do
      page = %{
        "properties" => %{
          "Type" => %{"type" => "select", "select" => %{"name" => "Wiki"}},
          "Status" => %{
            :type => :status,
            :status => %{name: "Wiki"}
          }
        }
      }

      assert Catalog.allowed_document?(page)
    end

    test "supports multi-select with atom keys and numeric values" do
      page = %{
        "properties" => %{
          "Type" => %{
            type: "multi_select",
            multi_select: [%{"name" => 123}, %{"name" => "Wiki"}]
          }
        }
      }

      assert Catalog.allowed_document?(page)
    end

    test "rejects documents without matching type" do
      page = %{
        "properties" => %{
          "Type" => %{"type" => "select", "select" => %{"name" => "Task"}}
        }
      }

      refute Catalog.allowed_document?(page)
    end

    test "allows documents without type when configured" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        allowed_document_type_values: ["wiki"],
        document_type_property_names: ["Type"],
        allow_documents_without_type?: true
      )

      assert Catalog.allowed_document?(%{"properties" => %{}})
    end

    test "excludes pages with parent identifiers in exclude_ids" do
      Application.put_env(:dashboard_ssd, :integrations,
        notion_token: "token",
        notion_curated_database_ids: []
      )

      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        curated_collections: [],
        auto_discover?: true,
        auto_discover_mode: :pages,
        exclude_database_ids: ["workspace"],
        allowed_document_type_values: ["Wiki"],
        document_type_property_names: ["Type"],
        allow_documents_without_type?: false
      )

      CacheStore.reset()
      Notion.reset_circuits()

      excluded_page = %{
        "id" => "page-excluded",
        "url" => "https://notion.so/page-excluded",
        "last_edited_time" => "2024-06-01T12:00:00Z",
        "parent" => %{"type" => "workspace"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Excluded"}]},
          "Type" => %{"type" => "select", "select" => %{"name" => "Wiki"}}
        }
      }

      included_page = %{
        "id" => "page-included",
        "url" => "https://notion.so/page-included",
        "last_edited_time" => "2024-06-01T13:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-other"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Included"}]},
          "Type" => %{"type" => "select", "select" => %{"name" => "Wiki"}}
        }
      }

      NotionMock
      |> expect(:search, fn "token", "", _opts ->
        {:ok,
         %{
           "results" => [excluded_page, included_page],
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)

      assert {:ok, %{documents: documents, errors: []}} =
               Catalog.list_documents("kb:auto:pages", cache?: false)

      assert Enum.map(documents, & &1.id) == ["page-included"]
    end

    test "excludes pages not in include_ids when include_ids is set" do
      Application.put_env(:dashboard_ssd, :integrations,
        notion_token: "token",
        notion_curated_database_ids: ["db-allowed"]
      )

      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        curated_collections: [],
        auto_discover?: true,
        auto_discover_mode: :pages,
        exclude_database_ids: [],
        allowed_document_type_values: ["Wiki"],
        document_type_property_names: ["Type"],
        allow_documents_without_type?: false
      )

      CacheStore.reset()
      Notion.reset_circuits()

      excluded_page = %{
        "id" => "page-excluded",
        "url" => "https://notion.so/page-excluded",
        "last_edited_time" => "2024-06-01T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-other"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Excluded"}]},
          "Type" => %{"type" => "select", "select" => %{"name" => "Wiki"}}
        }
      }

      included_page = %{
        "id" => "page-included",
        "url" => "https://notion.so/page-included",
        "last_edited_time" => "2024-06-01T13:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-allowed"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Included"}]},
          "Type" => %{"type" => "select", "select" => %{"name" => "Wiki"}}
        }
      }

      NotionMock
      |> expect(:search, fn "token", "", _opts ->
        {:ok,
         %{
           "results" => [excluded_page, included_page],
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)

      assert {:ok, %{documents: documents, errors: []}} =
               Catalog.list_documents("kb:auto:pages", cache?: false)

      assert Enum.map(documents, & &1.id) == ["page-included"]
    end

    test "filters out pages with invalid parent types" do
      Application.put_env(:dashboard_ssd, :integrations,
        notion_token: "token",
        notion_curated_database_ids: []
      )

      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        curated_collections: [],
        auto_discover?: true,
        auto_discover_mode: :pages,
        allowed_document_type_values: ["Wiki"],
        document_type_property_names: ["Type"],
        allow_documents_without_type?: false
      )

      CacheStore.reset()
      Notion.reset_circuits()

      valid_page = %{
        "id" => "page-valid",
        "url" => "https://notion.so/page-valid",
        "last_edited_time" => "2024-05-01T12:00:00Z",
        "parent" => %{"type" => "database_id", "database_id" => "db-valid"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Valid"}]},
          "Type" => %{"type" => "select", "select" => %{"name" => "Wiki"}}
        }
      }

      invalid_page = %{
        "id" => "page-invalid",
        "url" => "https://notion.so/page-invalid",
        "last_edited_time" => "2024-05-02T12:00:00Z",
        "parent" => %{"type" => "block_id", "block_id" => "block-123"},
        "properties" => %{
          "Name" => %{"type" => "title", "title" => [%{"plain_text" => "Invalid"}]},
          "Type" => %{"type" => "select", "select" => %{"name" => "Wiki"}}
        }
      }

      NotionMock
      |> expect(:search, fn "token", "", _opts ->
        {:ok,
         %{
           "results" => [invalid_page, valid_page],
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)

      assert {:ok, %{documents: documents, errors: []}} =
               Catalog.list_documents("kb:auto:pages", cache?: false)

      assert Enum.map(documents, & &1.id) == ["page-valid"]
    end
  end

  defp restore_env(%{notion_token: token, notion_api_key: api_key}) do
    set_env("NOTION_TOKEN", token)
    set_env("NOTION_API_KEY", api_key)
  end

  test "handles page collection discovery with custom settings" do
    Application.delete_env(:dashboard_ssd, :integrations)
    System.put_env("NOTION_TOKEN", "token")

    Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
      curated_collections: [],
      auto_discover_enabled: true,
      auto_discover_mode: :pages,
      auto_page_collection_name: "Custom Pages"
    )

    CacheStore.reset()
    Notion.reset_circuits()

    NotionMock
    |> expect(:search, fn "token", "", _opts ->
      {:ok, %{"results" => [], "has_more" => false}}
    end)

    assert {:ok, %{collections: [collection], errors: []}} = Catalog.list_collections()
    assert collection.name == "Custom Pages"
  end

  test "handles database_allowed with exclude_ids in auto discovery" do
    Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
      auto_discover?: true,
      exclude_database_ids: ["db-excluded"]
    )

    Application.put_env(:dashboard_ssd, :integrations, notion_token: "token")

    CacheStore.reset()
    Notion.reset_circuits()

    response = %{
      "results" => [
        %{
          "id" => "db-included",
          "title" => [%{"plain_text" => "Included"}],
          "description" => [],
          "last_edited_time" => "2024-05-01T12:00:00Z",
          "properties" => %{}
        },
        %{
          "id" => "db-excluded",
          "title" => [%{"plain_text" => "Excluded"}],
          "description" => [],
          "last_edited_time" => "2024-05-02T12:00:00Z",
          "properties" => %{}
        }
      ],
      "has_more" => false,
      "next_cursor" => nil
    }

    NotionMock
    |> expect(:list_databases, fn "token", _opts -> {:ok, response} end)

    assert {:ok, %{collections: [collection], errors: []}} = Catalog.list_collections()
    assert collection.id == "db-included"
  end

  test "handles paginate_databases error in auto discovery" do
    Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase, auto_discover?: true)
    Application.put_env(:dashboard_ssd, :integrations, notion_token: "token")

    CacheStore.reset()
    Notion.reset_circuits()

    NotionMock
    |> expect(:list_databases, fn "token", _opts -> {:error, :network_timeout} end)

    assert {:ok, %{collections: [], errors: [%{reason: :network_timeout}]}} =
             Catalog.list_collections()
  end

  describe "allowed_document?/1" do
    setup do
      Application.delete_env(:dashboard_ssd, DashboardSSD.KnowledgeBase)

      on_exit(fn ->
        Application.delete_env(:dashboard_ssd, DashboardSSD.KnowledgeBase)
      end)

      :ok
    end

    test "returns true when page has allowed type" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        document_type_property_names: ["Type"],
        allowed_document_type_values: ["Guide"],
        allow_documents_without_type?: false
      )

      page = %{
        "properties" => %{
          "Type" => %{
            "type" => "multi_select",
            "multi_select" => [%{"name" => "Guide"}]
          }
        }
      }

      assert Catalog.allowed_document?(page)
    end

    test "respects allow_documents_without_type? option" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        document_type_property_names: ["Type"],
        allowed_document_type_values: ["Guide"],
        allow_documents_without_type?: false
      )

      page = %{
        "properties" => %{
          "Type" => %{"type" => "multi_select", "multi_select" => []}
        }
      }

      refute Catalog.allowed_document?(page)
    end

    test "skips type filtering for exempt database ids" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        document_type_property_names: ["Type"],
        document_type_filter_exempt_ids: ["db-exempt"],
        allow_documents_without_type?: false
      )

      page = %{
        "parent" => %{"type" => "database_id", "database_id" => "db-exempt"},
        "properties" => %{}
      }

      assert Catalog.allowed_document?(page)
    end
  end

  defp set_env(key, nil), do: System.delete_env(key)
  defp set_env(key, value), do: System.put_env(key, value)
end
