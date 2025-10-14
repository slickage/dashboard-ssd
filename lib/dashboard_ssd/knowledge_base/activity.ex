defmodule DashboardSSD.KnowledgeBase.Activity do
  @moduledoc """
  Persists and retrieves knowledge base activity (e.g., recently viewed documents).

  The concrete implementation will be introduced in subsequent tasks once the
  surrounding infrastructure is ready.
  """

  alias DashboardSSD.KnowledgeBase.Types

  @typedoc "Options for recording a view."
  @type record_opt :: {:metadata, map()} | {:timestamp, DateTime.t()}

  @typedoc "Options for recent document lookups."
  @type recent_opt :: {:limit, pos_integer()} | {:include_deleted?, boolean()}

  @doc """
  Records a knowledge base view event.
  """
  @spec record_view(map(), map(), [record_opt()]) :: :ok | {:error, term()}
  def record_view(_user_attrs, _document_attrs, _opts \\ []) do
    {:error, :not_implemented}
  end

  @doc """
  Fetches recently viewed documents for a user.
  """
  @spec recent_documents(term(), [recent_opt()]) ::
          {:ok, [Types.RecentActivity.t()]} | {:error, term()}
  def recent_documents(_user_id, _opts \\ []) do
    {:error, :not_implemented}
  end
end
