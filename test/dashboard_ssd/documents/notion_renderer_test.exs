defmodule DashboardSSD.Documents.NotionRendererTest do
  use ExUnit.Case, async: false

  alias DashboardSSD.Documents.NotionRenderer

  defmodule StubRenderer do
    @behaviour DashboardSSD.Documents.NotionRenderer.RendererBehaviour

    @impl true
    def render_html(page_id, _opts), do: {:ok, "<p>#{page_id}</p>"}

    @impl true
    def render_download(page_id, _opts), do: {:ok, %{filename: page_id, data: "bin"}}
  end

  defmodule CountingRenderer do
    @behaviour DashboardSSD.Documents.NotionRenderer.RendererBehaviour

    @impl true
    def render_html(page_id, _opts) do
      send(self(), {:render_html, page_id})
      {:ok, "<p>#{page_id}</p>"}
    end

    @impl true
    def render_download(page_id, _opts) do
      send(self(), {:render_download, page_id})
      {:ok, %{filename: page_id, data: "bin"}}
    end
  end

  defmodule ErrorRenderer do
    @behaviour DashboardSSD.Documents.NotionRenderer.RendererBehaviour

    @impl true
    def render_html(_page_id, _opts), do: {:error, :renderer_boom}

    @impl true
    def render_download(_page_id, _opts), do: {:error, :renderer_boom}
  end

  setup do
    previous = Application.get_env(:dashboard_ssd, :notion_renderer)
    Application.put_env(:dashboard_ssd, :notion_renderer, StubRenderer)

    on_exit(fn ->
      if is_nil(previous) do
        Application.delete_env(:dashboard_ssd, :notion_renderer)
      else
        Application.put_env(:dashboard_ssd, :notion_renderer, previous)
      end
    end)

    :ok
  end

  test "render_html caches results" do
    assert {:ok, "<p>abc</p>"} = NotionRenderer.render_html("abc")
    assert {:ok, "<p>abc</p>"} = NotionRenderer.render_html("abc")
  end

  test "render_download proxies to renderer" do
    assert {:ok, %{filename: "xyz"}} = NotionRenderer.render_download("xyz")
  end

  test "render_html returns renderer errors" do
    Application.put_env(:dashboard_ssd, :notion_renderer, ErrorRenderer)
    assert {:error, :renderer_boom} = NotionRenderer.render_html("missing")
  end

  test "render_download returns renderer errors" do
    Application.put_env(:dashboard_ssd, :notion_renderer, ErrorRenderer)
    assert {:error, :renderer_boom} = NotionRenderer.render_download("missing")
  end

  test "render_download caches payloads" do
    Application.put_env(:dashboard_ssd, :notion_renderer, CountingRenderer)

    assert {:ok, _} = NotionRenderer.render_download("cache-me")
    assert_receive {:render_download, "cache-me"}

    assert {:ok, _} = NotionRenderer.render_download("cache-me")
    refute_receive {:render_download, "cache-me"}
  end

  test "render_html reports missing renderer when not configured" do
    Application.delete_env(:dashboard_ssd, :notion_renderer)
    assert {:error, :notion_renderer_not_configured} = NotionRenderer.render_html("page-id")
  end

  test "render_download reports missing renderer when not configured" do
    Application.delete_env(:dashboard_ssd, :notion_renderer)
    assert {:error, :notion_renderer_not_configured} = NotionRenderer.render_download("page-id")
  end
end
