defmodule DashboardSSD.KnowledgeBase.CatalogTest do
  use ExUnit.Case, async: false

  import Mox

  alias DashboardSSD.Integrations.{Notion, NotionMock}
  alias DashboardSSD.KnowledgeBase.{Cache, Catalog, Types}

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
      Cache.reset()
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

    Cache.reset()
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

    test "falls back to default curated ids when metadata missing" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        default_curated_database_ids: ["db-default"]
      )

      Application.put_env(:dashboard_ssd, :integrations,
        notion_token: "token",
        notion_curated_database_ids: ["db-default"]
      )

      Cache.reset()
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

      Cache.reset()
      Notion.reset_circuits()

      NotionMock
      |> expect(:query_database, fn "token", "db-atom", _opts ->
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

      Cache.reset()
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
      Cache.reset()
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

      Cache.reset()
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

      Cache.reset()
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

      Cache.reset()
      Notion.reset_circuits()

      NotionMock
      |> expect(:query_database, fn "token", "db-allowed", _opts ->
        {:ok, %{"results" => [], "has_more" => false}}
      end)

      assert {:ok, %{collections: [collection], errors: []}} = Catalog.list_collections()
      assert collection.id == "db-allowed"
    end

    test "bypasses cached collections when cache? option false" do
      Cache.reset()
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

      Cache.reset()
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

      Cache.reset()
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

      Cache.reset()
      Notion.reset_circuits()

      response = %{
        "results" => [
          %{
            "id" => "db-auto",
            "title" => [%{"plain_text" => "Auto DB"}],
            "description" => [%{"plain_text" => "Auto Description"}],
            "icon" => %{"emoji" => "📗"},
            "last_edited_time" => "2024-05-01T12:00:00Z",
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

      Cache.reset()
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

      Cache.reset()
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

      Cache.reset()
      Notion.reset_circuits()

      NotionMock
      |> expect(:list_databases, fn "token", _opts -> {:error, :timeout} end)

      assert {:ok, %{collections: [], errors: [%{reason: :timeout}]}} = Catalog.list_collections()
    end

    test "auto discovery enriches metadata and handles external icons" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase, auto_discover?: true)
      Application.put_env(:dashboard_ssd, :integrations, notion_token: "token")

      Cache.reset()
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

    test "auto discovery clamps configured page size to Notion limits" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        auto_discover?: true,
        auto_discover_page_size: 250
      )

      Application.put_env(:dashboard_ssd, :integrations, notion_token: "token")

      Cache.reset()
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

      Cache.reset()
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

    test "returns an empty set when auto discovery is disabled and no curated data exists" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase, auto_discover?: false)
      Application.put_env(:dashboard_ssd, :integrations, notion_token: "token")

      Cache.reset()
      Notion.reset_circuits()

      assert {:ok, %{collections: [], errors: []}} = Catalog.list_collections()
    end

    test "handles file icons, atom keys, and blank titles from Notion responses" do
      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        auto_discover?: true,
        auto_discover_page_size: :invalid
      )

      Application.put_env(:dashboard_ssd, :integrations, notion_token: "token")

      Cache.reset()
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

      Cache.reset()
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

      Cache.reset()
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
  end

  describe "list_documents/2" do
    test "returns document summaries for a collection" do
      Cache.reset()
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
      assert summary.collection_id == "db-handbook"
    end

    test "excludes documents whose type is not allowlisted" do
      Cache.reset()
      Notion.reset_circuits()

      Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
        curated_collections: [
          %{"id" => "db-handbook", "name" => "Company Handbook"}
        ],
        allowed_document_type_values: ["Wiki"],
        document_type_property_names: ["Type"],
        allow_documents_without_type?: false
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

      assert {:ok, %{documents: [], errors: []}} = Catalog.list_documents("db-handbook")
    end

    test "returns errors when query fails" do
      NotionMock
      |> expect(:query_database, fn "token", "db-fail", _opts ->
        {:error, :timeout}
      end)

      assert {:ok, %{documents: [], errors: [%{collection_id: "db-fail", reason: :timeout}]}} =
               Catalog.list_documents("db-fail")
    end
  end

  describe "get_document/2" do
    setup do
      Cache.reset()
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

      Cache.reset()
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

      assert {:ok, %{collections: [collection], errors: []}} = Catalog.list_collections()

      assert %Types.Collection{
               id: "kb:auto:pages",
               name: "Wiki Pages",
               document_count: 1
             } = collection

      assert {:ok, %{documents: [document], errors: []}} = Catalog.list_documents("kb:auto:pages")
      assert document.id == "page-1"
      assert document.title == "Onboarding Guide"
      assert document.collection_id == "kb:auto:pages"
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

      NotionMock
      |> expect(:search, fn "token", "", _opts ->
        {:ok,
         %{
           "results" => [blocked_page, allowed_page],
           "has_more" => false,
           "next_cursor" => nil
         }}
      end)

      assert {:ok, %{collections: [collection], errors: []}} = Catalog.list_collections()
      assert collection.document_count == 1

      assert {:ok, %{documents: [document], errors: []}} = Catalog.list_documents(collection.id)
      assert document.id == "page-allowed"
      assert document.title == "Team Handbook"
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

      Cache.reset()
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

      assert {:ok, %{collections: [collection], errors: []}} = Catalog.list_collections()
      assert {:ok, %{documents: [document], errors: []}} = Catalog.list_documents(collection.id)
      assert document.id == "28c54068269180b485eaff844489f9ba"
      assert document.title == "KB Page"
    end
  end

  defp restore_env(%{notion_token: token, notion_api_key: api_key}) do
    set_env("NOTION_TOKEN", token)
    set_env("NOTION_API_KEY", api_key)
  end

  defp set_env(key, nil), do: System.delete_env(key)
  defp set_env(key, value), do: System.put_env(key, value)
end
