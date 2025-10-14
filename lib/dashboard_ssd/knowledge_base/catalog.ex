defmodule DashboardSSD.KnowledgeBase.Catalog do
  @moduledoc """
  Handles curated collection and document metadata sourced from Notion.

  This module is currently a scaffold and will be expanded throughout the
  Knowledge Base feature workstream.
  """

  alias DashboardSSD.KnowledgeBase.Types

  @typedoc "Options accepted by catalog queries."
  @type opt :: {:include_stale?, boolean()} | {:limit, pos_integer()} | {:cache?, boolean()}
  @type opts :: [opt]

  @doc """
  Returns curated collections with computed freshness metadata.

  Initially returns a not-implemented placeholder until Phase 3 work fills it in.
  """
  @spec list_collections(opts()) :: {:ok, [Types.Collection.t()]} | {:error, term()}
  def list_collections(_opts \\ []) do
    {:error, :not_implemented}
  end

  @doc """
  Lists documents for a given collection identifier.
  """
  @spec list_documents(Types.collection_id(), opts()) ::
          {:ok, [Types.DocumentSummary.t()]} | {:error, term()}
  def list_documents(_collection_id, _opts \\ []) do
    {:error, :not_implemented}
  end

  @doc """
  Fetches a full document payload, including rendered blocks.
  """
  @spec get_document(Types.document_id(), opts()) ::
          {:ok, Types.DocumentDetail.t()} | {:error, term()}
  def get_document(_document_id, _opts \\ []) do
    {:error, :not_implemented}
  end
end
