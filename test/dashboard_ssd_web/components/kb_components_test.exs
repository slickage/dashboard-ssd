defmodule DashboardSSDWeb.KbComponentsTest do
  use DashboardSSDWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias DashboardSSD.KnowledgeBase.Types
  alias DashboardSSDWeb.KbComponents

  test "recent_activity_list renders document entries" do
    activity = %Types.RecentActivity{
      user_id: 1,
      document_id: "page-1",
      document_title: "Welcome to the Handbook",
      document_share_url: "https://example.com/page-1",
      occurred_at: ~U[2024-05-01 12:00:00Z],
      metadata: %{}
    }

    html =
      render_component(&KbComponents.recent_activity_list/1,
        documents: [activity],
        errors: []
      )

    assert html =~ "Welcome to the Handbook"
    assert html =~ "Viewed 2024-05-01 12:00"
    refute html =~ "Notion"
  end

  test "recent_activity_list renders empty state" do
    html = render_component(&KbComponents.recent_activity_list/1, documents: [], errors: [])
    assert html =~ "You have not opened any documents recently."
  end

  test "collection_tree renders expanded documents and highlights selection" do
    collections = [
      %Types.Collection{
        id: "db-a",
        name: "A",
        description: "Alpha docs",
        document_count: 2,
        last_document_updated_at: ~U[2024-05-01 12:00:00Z]
      },
      %Types.Collection{
        id: "db-b",
        name: "B",
        description: nil,
        document_count: 0,
        last_document_updated_at: nil
      }
    ]

    documents = %{
      "db-a" => [
        struct!(Types.DocumentSummary,
          id: "page-1",
          collection_id: "db-a",
          title: "Welcome",
          summary: "Intro",
          owner: "Jane",
          last_updated_at: ~U[2024-05-01 12:00:00Z]
        )
      ]
    }

    html =
      render_component(&KbComponents.collection_tree/1,
        collections: collections,
        collection_errors: [],
        documents_by_collection: documents,
        document_errors: %{},
        expanded_ids: MapSet.new(["db-a"]),
        selected_collection_id: "db-a",
        selected_document_id: "page-1"
      )

    assert html =~ "Alpha docs"
    assert html =~ "Welcome"
    assert html =~ "phx-value-id=\"page-1\""
    assert html =~ "border-theme-border"
  end

  test "collection_tree surfaces document errors" do
    collections = [
      %Types.Collection{
        id: "db-a",
        name: "A",
        description: nil,
        document_count: 0,
        last_document_updated_at: nil
      }
    ]

    document_errors = %{"db-a" => [%{collection_id: "db-a", reason: :timeout}]}

    html =
      render_component(&KbComponents.collection_tree/1,
        collections: collections,
        collection_errors: [],
        documents_by_collection: %{},
        document_errors: document_errors,
        expanded_ids: MapSet.new(["db-a"]),
        selected_collection_id: nil,
        selected_document_id: nil
      )

    assert html =~ "timeout"
    refute html =~ "No documents available yet."
  end

  test "document_viewer renders blocks" do
    document =
      struct!(Types.DocumentDetail,
        id: "page-1",
        collection_id: "db-a",
        title: "Welcome",
        summary: nil,
        owner: "Jane",
        tags: ["Tag"],
        share_url: "https://example.com",
        last_updated_at: ~U[2024-05-01 12:00:00Z],
        synced_at: ~U[2024-05-01 12:05:00Z],
        rendered_blocks: [
          %{type: :heading_1, segments: [%{text: "Intro", annotations: %{}}], children: []},
          %{type: :paragraph, segments: [%{text: "Hello", annotations: %{}}], children: []},
          %{
            type: :code,
            language: "elixir",
            segments: [%{text: "IO.inspect(:ok)", annotations: %{code: false}}],
            children: []
          },
          %{
            type: :table,
            has_column_header?: true,
            has_row_header?: false,
            rows: [
              %{
                type: :table_row,
                cells: [
                  [%{text: "Column A", annotations: %{}}],
                  [%{text: "Column B", annotations: %{}}]
                ],
                children: []
              },
              %{
                type: :table_row,
                cells: [
                  [%{text: "Foo", annotations: %{}}],
                  [%{text: "Bar", annotations: %{}}]
                ],
                children: []
              }
            ],
            children: []
          }
        ]
      )

    html = render_component(&KbComponents.document_viewer/1, document: document)

    assert html =~ "Welcome"
    assert html =~ "Intro"
    assert html =~ "Hello"
    assert html =~ "<span class=\"nc\">IO</span>"
    assert html =~ "kb-code-block"
    assert html =~ "language-elixir"
    assert html =~ "<table"
    assert html =~ "Column A"
  end

  test "kb_block renders bulleted list with proper indentation" do
    block = %{
      type: :bulleted_list_item,
      segments: [%{text: "Item 1", annotations: %{}}],
      children: []
    }

    html = render_component(&KbComponents.kb_block/1, block: block, level: 0)

    assert html =~ "pl-6"
    assert html =~ "•"
    assert html =~ "Item 1"
  end

  test "kb_block renders nested bulleted list with increased indentation" do
    parent_block = %{
      type: :bulleted_list_item,
      segments: [%{text: "Parent", annotations: %{}}],
      children: [
        %{
          type: :bulleted_list_item,
          segments: [%{text: "Child", annotations: %{}}],
          children: []
        }
      ]
    }

    html = render_component(&KbComponents.kb_block/1, block: parent_block, level: 0)

    assert html =~ "pl-6"
    assert html =~ "Parent"
    assert html =~ "pl-12"
    assert html =~ "Child"
  end

  test "kb_block renders numbered list with sequential numbering" do
    block = %{
      type: :numbered_list_item,
      segments: [%{text: "First item", annotations: %{}}],
      children: []
    }

    html = render_component(&KbComponents.kb_block/1, block: block, level: 0, number: 1)

    assert html =~ "1."
    assert html =~ "First item"
  end

  test "kb_block assigns numbers to nested numbered lists" do
    parent_block = %{
      type: :numbered_list_item,
      segments: [%{text: "First", annotations: %{}}],
      children: [
        %{
          type: :numbered_list_item,
          segments: [%{text: "Second", annotations: %{}}],
          children: []
        },
        %{
          type: :numbered_list_item,
          segments: [%{text: "Third", annotations: %{}}],
          children: []
        }
      ]
    }

    html = render_component(&KbComponents.kb_block/1, block: parent_block, level: 0, number: 1)

    assert html =~ "1."
    assert html =~ "First"
    assert html =~ "1."
    assert html =~ "Second"
    assert html =~ "2."
    assert html =~ "Third"
  end

  test "kb_block handles mixed list types with proper numbering reset" do
    parent_block = %{
      type: :bulleted_list_item,
      segments: [%{text: "Bullet", annotations: %{}}],
      children: [
        %{
          type: :numbered_list_item,
          segments: [%{text: "Numbered 1", annotations: %{}}],
          children: []
        },
        %{
          type: :numbered_list_item,
          segments: [%{text: "Numbered 2", annotations: %{}}],
          children: []
        },
        %{
          type: :bulleted_list_item,
          segments: [%{text: "Sub bullet", annotations: %{}}],
          children: [
            %{
              type: :numbered_list_item,
              segments: [%{text: "Reset to 1", annotations: %{}}],
              children: []
            }
          ]
        }
      ]
    }

    html = render_component(&KbComponents.kb_block/1, block: parent_block, level: 0)

    assert html =~ "•"
    assert html =~ "Bullet"
    assert html =~ "1."
    assert html =~ "Numbered 1"
    assert html =~ "2."
    assert html =~ "Numbered 2"
    assert html =~ "Sub bullet"
    assert html =~ "1."
    assert html =~ "Reset to 1"
  end
end
