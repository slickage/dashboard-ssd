defmodule DashboardSSD.Documents.NotionRendererTest do
  use ExUnit.Case, async: true

  alias DashboardSSD.Documents.NotionRenderer

  defmodule StubRenderer do
    @behaviour DashboardSSD.Documents.NotionRenderer.RendererBehaviour

    @impl true
    def render_html(page_id, _opts), do: {:ok, "<p>#{page_id}</p>"}

    @impl true
    def render_download(page_id, _opts), do: {:ok, %{filename: page_id, data: "bin"}}
  end

  setup do
    Application.put_env(:dashboard_ssd, :notion_renderer, StubRenderer)
    :ok
  end

  test "render_html caches results" do
    assert {:ok, "<p>abc</p>"} = NotionRenderer.render_html("abc")
    assert {:ok, "<p>abc</p>"} = NotionRenderer.render_html("abc")
  end

  test "render_download proxies to renderer" do
    assert {:ok, %{filename: "xyz"}} = NotionRenderer.render_download("xyz")
  end
end
