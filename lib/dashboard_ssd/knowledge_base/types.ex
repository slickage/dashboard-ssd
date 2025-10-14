defmodule DashboardSSD.KnowledgeBase.Types do
  @moduledoc """
  Shared structs and type definitions for the Knowledge Base context.
  """

  @typedoc "Unique identifier for a curated Notion collection (database ID)."
  @type collection_id :: String.t()

  @typedoc "Unique identifier for a Notion document (page ID)."
  @type document_id :: String.t()

  @typedoc "Supported search data sources."
  @type search_source :: :cache | :notion

  @typedoc "Normalized Notion block payload rendered in the LiveView."
  @type rendered_block :: map()

  defmodule Collection do
    @moduledoc "Represents high-level metadata for a curated collection."
    @enforce_keys [:id, :name]
    defstruct [
      :id,
      :name,
      :description,
      :icon,
      :document_count,
      :last_synced_at,
      :last_document_updated_at,
      metadata: %{}
    ]

    @type t :: %__MODULE__{
            id: DashboardSSD.KnowledgeBase.Types.collection_id(),
            name: String.t(),
            description: String.t() | nil,
            icon: String.t() | nil,
            document_count: non_neg_integer() | nil,
            last_synced_at: DateTime.t() | nil,
            last_document_updated_at: DateTime.t() | nil,
            metadata: map()
          }
  end

  defmodule DocumentSummary do
    @moduledoc "Lightweight document metadata used for listings and search results."
    @enforce_keys [:id, :collection_id, :title]
    defstruct [
      :id,
      :collection_id,
      :title,
      :summary,
      :owner,
      :share_url,
      :last_updated_at,
      :synced_at,
      tags: [],
      metadata: %{}
    ]

    @type t :: %__MODULE__{
            id: DashboardSSD.KnowledgeBase.Types.document_id(),
            collection_id: DashboardSSD.KnowledgeBase.Types.collection_id(),
            title: String.t(),
            summary: String.t() | nil,
            tags: [String.t()],
            owner: String.t() | nil,
            share_url: String.t() | nil,
            last_updated_at: DateTime.t() | nil,
            synced_at: DateTime.t() | nil,
            metadata: map()
          }
  end

  defmodule DocumentDetail do
    @moduledoc "Extends document summaries with rendered Notion blocks for the reader view."
    @enforce_keys [:id, :collection_id, :title, :rendered_blocks]
    defstruct [
      :id,
      :collection_id,
      :title,
      :summary,
      :owner,
      :share_url,
      :last_updated_at,
      :synced_at,
      rendered_blocks: [],
      tags: [],
      metadata: %{},
      source: :cache
    ]

    @type t :: %__MODULE__{
            id: DashboardSSD.KnowledgeBase.Types.document_id(),
            collection_id: DashboardSSD.KnowledgeBase.Types.collection_id(),
            title: String.t(),
            summary: String.t() | nil,
            tags: [String.t()],
            owner: String.t() | nil,
            share_url: String.t() | nil,
            last_updated_at: DateTime.t() | nil,
            synced_at: DateTime.t() | nil,
            rendered_blocks: [DashboardSSD.KnowledgeBase.Types.rendered_block()],
            metadata: map(),
            source: DashboardSSD.KnowledgeBase.Types.search_source()
          }
  end

  defmodule RecentActivity do
    @moduledoc "Represents the latest documents a user has viewed."
    @enforce_keys [:user_id, :document_id, :occurred_at]
    defstruct [
      :id,
      :user_id,
      :document_id,
      :document_title,
      :document_share_url,
      :occurred_at,
      metadata: %{}
    ]

    @type t :: %__MODULE__{
            id: Ecto.UUID.t() | nil,
            user_id: term(),
            document_id: DashboardSSD.KnowledgeBase.Types.document_id(),
            document_title: String.t() | nil,
            document_share_url: String.t() | nil,
            occurred_at: DateTime.t(),
            metadata: map()
          }
  end

  defmodule SearchResult do
    @moduledoc "Represents an individual search hit for the knowledge base."
    @enforce_keys [:document]
    defstruct [
      :document,
      :collection,
      :score,
      matched_terms: [],
      snippets: [],
      source: :cache
    ]

    @type t :: %__MODULE__{
            document: DashboardSSD.KnowledgeBase.Types.DocumentSummary.t(),
            collection: DashboardSSD.KnowledgeBase.Types.Collection.t() | nil,
            matched_terms: [String.t()],
            snippets: [String.t()],
            score: float() | nil,
            source: DashboardSSD.KnowledgeBase.Types.search_source()
          }
  end

  @doc "Enumerates permissible search sources."
  @spec search_source_values() :: [search_source()]
  def search_source_values, do: [:cache, :notion]
end
