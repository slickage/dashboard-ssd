defmodule DashboardSSD.KnowledgeBase.Search do
  @moduledoc """
  Coordinates knowledge base search across cached metadata and the Notion API.

  Implementation will follow in later phases; this module currently provides
  the public API contract for upcoming work.
  """

  alias DashboardSSD.KnowledgeBase.Types

  @typedoc "Options for search queries."
  @type opt ::
          {:limit, pos_integer()}
          | {:source_priority, [Types.search_source()]}
          | {:include_empty_collections?, boolean()}
          | {:user_id, term()}

  @doc """
  Executes a knowledge base search for the supplied term.
  """
  @spec search(String.t(), [opt()]) :: {:ok, [Types.SearchResult.t()]} | {:error, term()}
  def search(_term, _opts \\ []) do
    {:error, :not_implemented}
  end
end
