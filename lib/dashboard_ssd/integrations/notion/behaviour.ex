defmodule DashboardSSD.Integrations.Notion.Behaviour do
  @moduledoc """
  Behaviour definition for the Notion integration client to enable test stubbing.

    - Declares callback signatures consumed by `DashboardSSD.Integrations.Notion`.
  - Allows Mox/Test stubs to implement the behaviour in tests.
  - Documents the expected shape for tokens/options/responses.
  """

  @type token :: String.t()
  @type options :: keyword()

  @callback search(token(), String.t(), options()) :: {:ok, map()} | {:error, term()}
  @callback list_databases(token(), options()) :: {:ok, map()} | {:error, term()}
  @callback retrieve_page(token(), String.t(), options()) :: {:ok, map()} | {:error, term()}
  @callback query_database(token(), String.t(), options()) :: {:ok, map()} | {:error, term()}
  @callback retrieve_block_children(token(), String.t(), options()) ::
              {:ok, map()} | {:error, term()}
end
