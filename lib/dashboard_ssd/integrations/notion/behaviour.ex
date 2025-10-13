defmodule DashboardSSD.Integrations.Notion.Behaviour do
  @moduledoc """
  Behaviour definition for the Notion integration client to enable test stubbing.
  """

  @type token :: String.t()

  @callback search(token(), String.t()) :: {:ok, map()} | {:error, term()}
end
