defmodule DashboardSSD.Documents.NotionRenderer do
  @moduledoc """
  Converts Notion page content to HTML previews and cached download payloads.
  """
  alias DashboardSSD.Cache.SharedDocumentsCache

  defmodule RendererBehaviour do
    @callback render_html(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
    @callback render_download(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  end

  @doc """
  Renders HTML preview for the given Notion document ID using caching.
  """
  @spec render_html(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def render_html(page_id, opts \\ []) when is_binary(page_id) do
    SharedDocumentsCache.fetch_download_descriptor(cache_key(page_id, :html), fn ->
      case fetch_renderer().render_html(page_id, opts) do
        {:ok, html} -> {:ok, %{payload: html}}
        {:error, reason} -> {:error, reason}
      end
    end)
    |> unwrap_payload()
  end

  @doc """
  Renders a downloadable payload (PDF or zipped assets) for the Notion page.
  """
  @spec render_download(String.t(), keyword()) :: {:ok, %{binary => binary}} | {:error, term()}
  def render_download(page_id, opts \\ []) when is_binary(page_id) do
    SharedDocumentsCache.fetch_download_descriptor(cache_key(page_id, :download), fn ->
      fetch_renderer().render_download(page_id, opts)
    end)
    |> unwrap_payload()
  end

  defp fetch_renderer do
    Application.get_env(
      :dashboard_ssd,
      :notion_renderer,
      DashboardSSD.Documents.NotionRenderer.NoopRenderer
    )
  end

  defp cache_key(page_id, type), do: {:notion_renderer, page_id, type}

  defp unwrap_payload({:ok, %{payload: payload}}), do: {:ok, payload}
  defp unwrap_payload(other), do: other

  defmodule NoopRenderer do
    @behaviour RendererBehaviour

    @impl true
    def render_html(_page_id, _opts), do: {:error, :notion_renderer_not_configured}

    @impl true
    def render_download(_page_id, _opts), do: {:error, :notion_renderer_not_configured}
  end
end
