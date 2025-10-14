defmodule DashboardSSDWeb.KbComponents do
  @moduledoc """
  Function components used by the Knowledge Base experience.
  """

  use Phoenix.Component

  alias DashboardSSD.KnowledgeBase.Types
  alias DashboardSSDWeb.CodeHighlighter
  alias Phoenix.LiveView.Rendered

  attr :collections, :list, default: []
  attr :errors, :list, default: []
  attr :title, :string, default: "Curated Collections"

  @spec collection_overview(map()) :: Rendered.t()
  def collection_overview(assigns) do
    ~H"""
    <section class="flex flex-col gap-4">
      <div class="flex items-center justify-between">
        <h2 class="text-lg font-semibold text-white">{@title}</h2>
        <span :if={Enum.any?(@collections)} class="text-sm text-theme-muted">
          {Enum.count(@collections)} collections
        </span>
      </div>

      <div
        :if={Enum.any?(@errors)}
        class="rounded-md border border-red-500/40 bg-red-500/10 px-4 py-3 text-sm text-red-200"
      >
        <ul class="list-disc pl-4">
          <%= for error <- @errors do %>
            <li>{format_error(error)}</li>
          <% end %>
        </ul>
      </div>

      <div :if={Enum.any?(@collections)} class="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        <%= for collection <- @collections do %>
          <.collection_card collection={collection} />
        <% end %>
      </div>

      <p :if={Enum.empty?(@collections) and Enum.empty?(@errors)} class="text-sm text-theme-muted">
        No curated collections are available yet.
      </p>
    </section>
    """
  end

  attr :collections, :list, default: []
  attr :selected_id, :any, default: nil

  @doc false
  @spec collection_list(map()) :: Rendered.t()
  def collection_list(assigns) do
    ~H"""
    <section class="flex flex-col gap-3">
      <h3 class="text-sm font-semibold uppercase tracking-[0.16em] text-theme-muted">
        Collections
      </h3>

      <%= if Enum.empty?(@collections) do %>
        <p class="text-sm text-theme-muted">
          No curated collections are available yet.
        </p>
      <% else %>
        <ul class="flex flex-col gap-3">
          <%= for collection <- @collections do %>
            <li>
              <button
                type="button"
                phx-click="select_collection"
                phx-value-id={collection.id}
                class={
                  [
                    "w-full text-left rounded-lg border px-4 py-3 transition",
                    "border-white/10 bg-white/5 hover:border-white/20",
                    @selected_id == collection.id && "border-theme-accent bg-theme-accent/10"
                  ]
                  |> Enum.filter(& &1)
                }
              >
                <div class="flex flex-col gap-1">
                  <div class="flex items-start justify-between gap-2">
                    <div class="flex items-center gap-2">
                      <span :if={collection.icon} class="text-xl leading-none">
                        {collection.icon}
                      </span>
                      <span class="text-base font-semibold text-white">{collection.name}</span>
                    </div>
                    <span :if={not is_nil(collection.document_count)} class="theme-pill">
                      {collection.document_count} docs
                    </span>
                  </div>
                  <p :if={collection.description} class="text-sm text-theme-muted">
                    {collection.description}
                  </p>
                  <p :if={collection.last_document_updated_at} class="text-xs text-theme-muted">
                    Updated {format_datetime(collection.last_document_updated_at)}
                  </p>
                </div>
              </button>
            </li>
          <% end %>
        </ul>
      <% end %>
    </section>
    """
  end

  attr :documents, :list, default: []
  attr :selected_id, :any, default: nil

  @doc false
  @spec document_list(map()) :: Rendered.t()
  def document_list(assigns) do
    ~H"""
    <section class="flex flex-col gap-3">
      <h3 class="text-sm font-semibold uppercase tracking-[0.16em] text-theme-muted">
        Documents
      </h3>

      <%= if Enum.empty?(@documents) do %>
        <p class="text-sm text-theme-muted">
          No documents are available in this collection yet.
        </p>
      <% else %>
        <ul class="flex flex-col gap-3">
          <%= for document <- @documents do %>
            <li>
              <button
                type="button"
                phx-click="select_document"
                phx-value-id={document.id}
                class={
                  [
                    "w-full text-left rounded-lg border px-4 py-3 transition",
                    "border-white/10 bg-white/5 hover:border-white/20",
                    @selected_id == document.id && "border-theme-accent bg-theme-accent/10"
                  ]
                  |> Enum.filter(& &1)
                }
              >
                <div class="flex flex-col gap-1">
                  <p class="text-base font-semibold text-white">{document.title}</p>
                  <p :if={document.summary} class="text-sm text-theme-muted">
                    {document.summary}
                  </p>
                  <div class="flex flex-wrap items-center gap-2 text-xs text-theme-muted">
                    <span>Owner: {document.owner || "Unknown"}</span>
                    <span :if={document.last_updated_at}>
                      • Updated {format_datetime(document.last_updated_at)}
                    </span>
                  </div>
                  <div :if={document.tags != []} class="flex flex-wrap gap-2">
                    <span
                      :for={tag <- document.tags}
                      class="inline-flex items-center rounded-full bg-white/10 px-2 py-0.5 text-xs text-white/80"
                    >
                      {tag}
                    </span>
                  </div>
                </div>
              </button>
            </li>
          <% end %>
        </ul>
      <% end %>
    </section>
    """
  end

  attr :document, Types.DocumentDetail
  attr :error, :string, default: nil

  @doc false
  @spec document_viewer(map()) :: Rendered.t()
  def document_viewer(assigns) do
    ~H"""
    <section class="flex flex-col gap-3">
      <h3 class="text-sm font-semibold uppercase tracking-[0.16em] text-theme-muted">
        Document
      </h3>

      <%= cond do %>
        <% @error -> %>
          <div class="rounded-md border border-red-500/40 bg-red-500/10 px-3 py-2 text-sm text-red-200">
            {@error}
          </div>
        <% is_nil(@document) -> %>
          <p class="text-sm text-theme-muted">
            Select a document to start reading.
          </p>
        <% true -> %>
          <article class="flex flex-col gap-6">
            <header class="border-b border-white/10 pb-3">
              <h1 class="text-2xl font-semibold text-white">{@document.title}</h1>
              <div class="mt-2 flex flex-wrap items-center gap-4 text-sm text-theme-muted">
                <span>Owner: {@document.owner || "Unknown"}</span>
                <span :if={@document.last_updated_at}>
                  Updated {format_datetime(@document.last_updated_at)}
                </span>
                <a
                  :if={@document.share_url}
                  href={@document.share_url}
                  class="text-theme-accent underline"
                  target="_blank"
                  rel="noopener"
                >
                  View in Notion
                </a>
              </div>
              <div :if={@document.tags != []} class="mt-2 flex flex-wrap gap-2">
                <span
                  :for={tag <- @document.tags}
                  class="inline-flex items-center rounded-full bg-white/10 px-2 py-0.5 text-xs text-white/80"
                >
                  {tag}
                </span>
              </div>
            </header>

            <div class="flex flex-col gap-4">
              <%= for block <- @document.rendered_blocks do %>
                <.kb_block block={block} />
              <% end %>
            </div>
          </article>
      <% end %>
    </section>
    """
  end

  attr :documents, :list, default: []
  attr :errors, :list, default: []
  attr :title, :string, default: "Recently Viewed"

  @spec recent_activity_list(map()) :: Rendered.t()
  def recent_activity_list(assigns) do
    ~H"""
    <section class="flex flex-col gap-3">
      <h3 class="text-sm font-semibold uppercase tracking-[0.16em] text-theme-muted">
        {@title}
      </h3>

      <ul :if={Enum.any?(@documents)} class="flex flex-col gap-3">
        <%= for doc <- @documents do %>
          <li class="theme-card px-4 py-3">
            <.recent_activity_entry document={doc} />
          </li>
        <% end %>
      </ul>

      <p :if={Enum.empty?(@documents)} class="text-sm text-theme-muted">
        You have not opened any documents recently.
      </p>
    </section>
    """
  end

  attr :collection, Types.Collection, required: true

  defp collection_card(assigns) do
    ~H"""
    <article class="theme-card h-full px-4 py-4 sm:px-5 sm:py-5">
      <div class="flex flex-col gap-2">
        <div class="flex items-start justify-between gap-3">
          <div class="flex flex-col gap-1">
            <h3 class="text-lg font-semibold text-white">{@collection.name}</h3>
            <p :if={@collection.description} class="text-sm text-theme-muted">
              {@collection.description}
            </p>
          </div>
          <span :if={not is_nil(@collection.document_count)} class="theme-pill">
            {@collection.document_count} docs
          </span>
        </div>

        <p :if={@collection.last_document_updated_at} class="text-xs text-theme-muted">
          Updated {format_datetime(@collection.last_document_updated_at)}
        </p>
      </div>
    </article>
    """
  end

  attr :document, Types.RecentActivity, required: true

  defp recent_activity_entry(assigns) do
    title = assigns.document.document_title || assigns.document.document_id
    url = assigns.document.document_share_url

    assigns =
      assigns
      |> assign(:title, title)
      |> assign(:url, url)

    ~H"""
    <div class="flex flex-col gap-1">
      <%= if @url do %>
        <a
          href={@url}
          class="text-sm font-medium text-white transition hover:text-theme-accent"
          target="_blank"
          rel="noopener"
        >
          {@title}
        </a>
      <% else %>
        <span class="text-sm font-medium text-white">{@title}</span>
      <% end %>
      <p class="text-xs text-theme-muted">
        Viewed {format_datetime(@document.occurred_at)}
      </p>
    </div>
    """
  end

  attr :block, :map, required: true

  @doc false
  @spec kb_block(map()) :: Rendered.t()
  def kb_block(assigns) do
    ~H"""
    <%= case @block.type do %>
      <% :heading_1 -> %>
        <h2 class="text-xl font-semibold text-white"><.kb_rich_text segments={@block.segments} /></h2>
      <% :heading_2 -> %>
        <h3 class="text-lg font-semibold text-white"><.kb_rich_text segments={@block.segments} /></h3>
      <% :heading_3 -> %>
        <h4 class="text-base font-semibold text-white">
          <.kb_rich_text segments={@block.segments} />
        </h4>
      <% :paragraph -> %>
        <p class="text-sm leading-relaxed text-white/90">
          <.kb_rich_text segments={@block.segments} />
        </p>
      <% :bulleted_list_item -> %>
        <div class="pl-6 text-sm leading-relaxed text-white/90">
          <div class="flex items-start gap-2">
            <span class="pt-1 text-xs">•</span>
            <span><.kb_rich_text segments={@block.segments} /></span>
          </div>
        </div>
      <% :numbered_list_item -> %>
        <div class="pl-6 text-sm leading-relaxed text-white/90">
          <div class="flex items-start gap-2">
            <span class="pt-1 text-xs">•</span>
            <span><.kb_rich_text segments={@block.segments} /></span>
          </div>
        </div>
      <% :quote -> %>
        <blockquote class="border-l-4 border-white/20 pl-4 italic text-white/80">
          <.kb_rich_text segments={@block.segments} />
        </blockquote>
      <% :callout -> %>
        <div class="flex gap-3 rounded-md border border-white/10 bg-white/5 px-3 py-3 text-sm text-white/90">
          <span :if={@block.icon} class="text-lg leading-none">{icon_to_string(@block.icon)}</span>
          <div class="flex-1"><.kb_rich_text segments={@block.segments} /></div>
        </div>
      <% :code -> %>
        <% language = @block[:language] %>
        <% code_text =
          @block[:plain_text] || Enum.map_join(@block[:segments] || [], "", &Map.get(&1, :text, "")) %>
        <% highlighted = CodeHighlighter.highlight(code_text, language) %>
        <div class="kb-code-block">
          <div :if={language} class="kb-code-header">
            {language}
          </div>
          <pre class="kb-code-pre"><code class={"kb-code language-" <> CodeHighlighter.css_language(language)}><%= highlighted %></code></pre>
        </div>
      <% :divider -> %>
        <hr class="border-white/10" />
      <% :image -> %>
        <figure class="flex flex-col gap-2">
          <img :if={@block.source} src={@block.source} class="max-w-full rounded-md" />
          <figcaption :if={@block.caption != []} class="text-xs text-theme-muted">
            <.kb_rich_text segments={@block.caption} />
          </figcaption>
        </figure>
      <% :table -> %>
        <% rows = Map.get(@block, :rows, @block.children || []) %>
        <% column_header? = Map.get(@block, :has_column_header?, false) %>
        <% row_header? = Map.get(@block, :has_row_header?, false) %>
        <div class="overflow-x-auto rounded-lg border border-white/10 bg-white/5">
          <table class="w-full border-collapse text-sm text-white/90">
            <tbody>
              <%= for {row, row_index} <- Enum.with_index(rows) do %>
                <% cells = Map.get(row, :cells, []) %>
                <tr class="border-b border-white/10 last:border-b-0">
                  <%= for {cell_segments, cell_index} <- Enum.with_index(cells) do %>
                    <% is_header =
                      (column_header? and row_index == 0) or (row_header? and cell_index == 0) %>
                    <%= if is_header do %>
                      <th class="border border-white/10 bg-white/10 px-3 py-2 text-left font-semibold text-white">
                        <.kb_rich_text segments={cell_segments} />
                      </th>
                    <% else %>
                      <td class="border border-white/10 px-3 py-2 text-white/90">
                        <.kb_rich_text segments={cell_segments} />
                      </td>
                    <% end %>
                  <% end %>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% :unsupported -> %>
        <div class="text-xs text-theme-muted italic">
          Unsupported block ({@block.raw_type})
        </div>
    <% end %>

    <div :if={@block.children != []} class="mt-2 flex flex-col gap-2">
      <%= for child <- @block.children do %>
        <.kb_block block={child} />
      <% end %>
    </div>
    """
  end

  attr :segments, :list, default: []

  @doc false
  @spec kb_rich_text(map()) :: Rendered.t()
  def kb_rich_text(assigns) do
    ~H"""
    <%= for segment <- @segments do %>
      <%= if segment[:href] do %>
        <a
          href={segment.href}
          class={segment_classes(segment) <> " underline text-theme-accent"}
          target="_blank"
          rel="noopener"
        >
          {segment[:text] || ""}
        </a>
      <% else %>
        <span class={segment_classes(segment)}>{segment[:text] || ""}</span>
      <% end %>
    <% end %>
    """
  end

  defp format_datetime(nil), do: "n/a"

  defp format_datetime(%DateTime{} = dt) do
    dt
    |> DateTime.truncate(:second)
    |> Calendar.strftime("%Y-%m-%d %H:%M")
  end

  defp format_datetime(%NaiveDateTime{} = ndt) do
    ndt
    |> NaiveDateTime.truncate(:second)
    |> Calendar.strftime("%Y-%m-%d %H:%M")
  end

  defp segment_classes(segment) do
    annotations = Map.get(segment, :annotations, %{}) || %{}

    [
      "whitespace-pre-wrap",
      annotations[:bold] && "font-semibold",
      annotations[:italic] && "italic",
      annotations[:strikethrough] && "line-through",
      annotations[:underline] && "underline",
      annotations[:code] && "kb-inline-code"
    ]
    |> Enum.filter(& &1)
    |> Enum.join(" ")
  end

  defp icon_to_string(%{"emoji" => emoji}), do: emoji
  defp icon_to_string(%{emoji: emoji}), do: emoji
  defp icon_to_string(_), do: "💡"

  defp format_error(%{collection_id: id, reason: reason}) do
    "#{id}: #{friendly_reason(reason)}"
  end

  defp format_error(reason), do: friendly_reason(reason)

  defp friendly_reason({:missing_env, env}), do: "Missing environment variable #{env}"
  defp friendly_reason({:http_error, status, _body}), do: "HTTP error #{status}"
  defp friendly_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp friendly_reason(reason), do: inspect(reason)
end
