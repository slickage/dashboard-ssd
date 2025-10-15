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
  attr :empty_message, :string, default: "No curated collections are available yet."

  @doc false
  @spec collection_list(map()) :: Rendered.t()
  def collection_list(assigns) do
    ~H"""
    <section class="flex flex-col gap-3">
      <p :if={Enum.empty?(@collections)} class="text-sm text-theme-muted">
        {@empty_message}
      </p>

      <ul :if={Enum.any?(@collections)} class="flex flex-col gap-2">
        <%= for collection <- @collections do %>
          <% selected? = @selected_id == collection.id %>
          <li>
            <button
              type="button"
              phx-click="select_collection"
              phx-value-id={collection.id}
              class={collection_item_classes(selected?)}
            >
              <div class="flex flex-col gap-1 text-left">
                <span class="text-sm font-semibold text-theme-text">{collection.name}</span>
                <p :if={collection.description} class="text-xs text-theme-muted">
                  {collection.description}
                </p>
                <p :if={collection.last_document_updated_at} class="text-xs text-theme-muted">
                  Updated {format_datetime(collection.last_document_updated_at)}
                </p>
              </div>
              <span :if={not is_nil(collection.document_count)} class="text-xs text-theme-muted">
                {collection.document_count} docs
              </span>
            </button>
          </li>
        <% end %>
      </ul>
    </section>
    """
  end

  attr :documents, :list, default: []
  attr :selected_id, :any, default: nil
  attr :empty_message, :string, default: "No documents available yet."

  @doc false
  @spec document_list(map()) :: Rendered.t()
  def document_list(assigns) do
    ~H"""
    <section class="flex flex-col gap-3">
      <p :if={Enum.empty?(@documents)} class="text-sm text-theme-muted">
        {@empty_message}
      </p>

      <ul :if={Enum.any?(@documents)} class="flex flex-col gap-2">
        <%= for document <- @documents do %>
          <% selected? = @selected_id == document.id %>
          <li>
            <button
              type="button"
              phx-click="select_document"
              phx-value-id={document.id}
              class={document_item_classes(selected?)}
            >
              <div class="flex flex-col gap-2 text-left">
                <div class="flex flex-col gap-1">
                  <span class="text-sm font-medium text-theme-text">{document.title}</span>
                  <p :if={document.summary} class="text-xs text-theme-muted">
                    {document.summary}
                  </p>
                </div>

                <div :if={document.tags != []} class="flex flex-wrap gap-2">
                  <span
                    :for={tag <- document.tags}
                    class="inline-flex items-center rounded-full bg-white/10 px-2 py-0.5 text-xs text-white/80"
                  >
                    {tag}
                  </span>
                </div>

                <div class="flex flex-wrap items-center gap-3 text-xs text-theme-muted">
                  <span :if={document.owner}>Owner: {document.owner}</span>
                  <span :if={document.last_updated_at}>
                    Updated {format_datetime(document.last_updated_at)}
                  </span>
                  <span :if={document.synced_at}>
                    Synced {format_datetime(document.synced_at)}
                  </span>
                </div>

                <a
                  :if={document.share_url}
                  href={document.share_url}
                  class="text-xs text-theme-accent underline underline-offset-2"
                  target="_blank"
                  rel="noopener"
                >
                  Open in Notion
                </a>
              </div>
            </button>
          </li>
        <% end %>
      </ul>
    </section>
    """
  end

  attr :collections, :list, default: []
  attr :collection_errors, :list, default: []
  attr :documents_by_collection, :map, default: %{}
  attr :document_errors, :map, default: %{}
  attr :expanded_ids, :any, default: MapSet.new()
  attr :selected_collection_id, :any, default: nil
  attr :selected_document_id, :any, default: nil

  @doc false
  @spec collection_tree(map()) :: Rendered.t()
  def collection_tree(assigns) do
    ~H"""
    <section class="flex flex-col gap-3">
      <h3 class="text-xs font-semibold uppercase tracking-[0.16em] text-theme-muted">
        Collections
      </h3>

      <div
        :if={Enum.any?(@collection_errors)}
        class="rounded-md border border-amber-400/40 bg-amber-400/10 px-3 py-2 text-xs text-amber-200"
      >
        <p :for={error <- @collection_errors}>{format_error(error)}</p>
      </div>

      <% general_doc_errors = Map.get(@document_errors, :general, []) %>
      <div
        :if={general_doc_errors != []}
        class="rounded-md border border-amber-400/40 bg-amber-400/10 px-3 py-2 text-xs text-amber-200"
      >
        <p :for={error <- general_doc_errors}>{format_error(error)}</p>
      </div>

      <p
        :if={Enum.empty?(@collections) and Enum.empty?(@collection_errors)}
        class="text-sm text-theme-muted"
      >
        No curated collections are available yet.
      </p>
      <p
        :if={Enum.empty?(@collections) and Enum.empty?(@collection_errors)}
        class="text-sm text-theme-muted"
      >
        No documents are available in this collection yet.
      </p>

      <div
        :if={Enum.any?(@collections)}
        class="rounded-lg border border-theme-border bg-theme-surface"
      >
        <div class="max-h-[28rem] overflow-y-auto px-2 py-3">
          <ul class="flex flex-col gap-2">
            <%= for collection <- @collections do %>
              <% expanded? = MapSet.member?(@expanded_ids, collection.id) %>
              <% selected? = @selected_collection_id == collection.id %>
              <% documents = Map.get(@documents_by_collection, collection.id, []) %>
              <% doc_errors = Map.get(@document_errors, collection.id, []) %>
              <li class="flex flex-col gap-2">
                <button
                  type="button"
                  phx-click="toggle_collection"
                  phx-value-id={collection.id}
                  class={
                    [
                      "flex w-full items-center justify-between gap-3 rounded-lg border border-theme-border border-opacity-60 px-4 py-3 text-left text-sm text-theme-text transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-theme-primary/30 bg-theme-surfaceMuted cursor-pointer",
                      selected? && "border-theme-border text-theme-text",
                      not selected? && "hover:bg-theme-surfaceRaised"
                    ]
                    |> Enum.filter(& &1)
                  }
                  aria-expanded={expanded?}
                  phx-keydown="toggle_collection_key"
                >
                  <div class="flex items-start gap-2">
                    <span :if={collection.icon} class="mt-0.5 text-lg leading-none" aria-hidden="true">
                      {collection.icon}
                    </span>
                    <div class="flex flex-col text-theme-text">
                      <span class="text-sm font-semibold text-theme-text">{collection.name}</span>
                      <p :if={collection.description} class="text-xs text-theme-muted">
                        {collection.description}
                      </p>
                      <p :if={collection.last_document_updated_at} class="text-xs text-theme-muted">
                        Updated {format_datetime(collection.last_document_updated_at)}
                      </p>
                    </div>
                  </div>
                  <div class="flex items-center gap-2 text-xs uppercase tracking-wide text-theme-muted">
                    <span :if={not is_nil(collection.document_count)}>
                      {collection.document_count} docs
                    </span>
                    <span class="text-lg leading-none">{if expanded?, do: "-", else: "+"}</span>
                  </div>
                </button>

                <div
                  :if={doc_errors != []}
                  class="rounded-lg border border-amber-400/40 bg-amber-400/10 px-3 py-2 text-xs text-amber-200"
                >
                  <p :for={error <- doc_errors}>{format_error(error)}</p>
                </div>

                <ul
                  :if={expanded? and documents != []}
                  class="flex flex-col gap-1 border-l border-theme-border border-opacity-70 pl-3"
                >
                  <%= for document <- documents do %>
                    <% document_selected? = @selected_document_id == document.id %>
                    <li>
                      <button
                        type="button"
                        phx-click="select_document"
                        phx-value-id={document.id}
                        class={
                          [
                            "flex w-full flex-col gap-1 rounded-md border border-transparent px-3 py-2 text-left text-sm transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-theme-primary/30 cursor-pointer",
                            document_selected? &&
                              "bg-theme-primary text-theme-textActive border-theme-primary",
                            not document_selected? &&
                              "bg-theme-surface text-theme-text hover:bg-theme-surfaceRaised"
                          ]
                          |> Enum.filter(& &1)
                        }
                        phx-keydown="select_document_key"
                      >
                        <span class="text-sm font-medium text-theme-text">{document.title}</span>
                        <p :if={document.summary} class="text-xs text-theme-muted">
                          {document.summary}
                        </p>
                      </button>
                    </li>
                  <% end %>
                </ul>

                <p
                  :if={expanded? and documents == [] and doc_errors == []}
                  class="pl-2 text-xs text-theme-muted"
                >
                  No documents available yet.
                </p>
              </li>
            <% end %>
          </ul>
        </div>
      </div>
    </section>
    """
  end

  attr :document, Types.DocumentDetail
  attr :error, :string, default: nil
  attr :loading, :boolean, default: false

  @doc false
  @spec document_viewer(map()) :: Rendered.t()
  def document_viewer(assigns) do
    ~H"""
    <section class="flex flex-col gap-3">
      <h3 class="text-sm font-semibold uppercase tracking-[0.16em] text-theme-muted">
        Document
      </h3>

      <%= cond do %>
        <% @loading -> %>
          <div class="flex min-h-[200px] items-center justify-center gap-2 text-sm text-theme-muted">
            <svg
              class="h-4 w-4 animate-spin text-theme-muted"
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              role="img"
              aria-label="Loading"
            >
              <circle
                class="opacity-25"
                cx="12"
                cy="12"
                r="10"
                stroke="currentColor"
                stroke-width="4"
              />
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z" />
            </svg>
            <span>Loading document…</span>
          </div>
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
  attr :selected_document_id, :any, default: nil

  @spec recent_activity_list(map()) :: Rendered.t()
  def recent_activity_list(assigns) do
    ~H"""
    <section class="flex flex-col gap-2">
      <header class="flex items-center justify-between gap-2">
        <h3 class="text-xs font-semibold uppercase tracking-[0.16em] text-theme-muted">
          {@title}
        </h3>
      </header>

      <div
        :if={Enum.any?(@errors)}
        class="rounded-md border border-amber-400/40 bg-amber-400/10 px-3 py-2 text-xs text-amber-200"
      >
        <p :for={error <- @errors}>{format_error(error)}</p>
      </div>

      <ul :if={Enum.any?(@documents)} class="flex flex-col gap-2">
        <%= for doc <- @documents do %>
          <% title = doc.document_title || doc.document_id %>
          <li>
            <div
              phx-click="select_document"
              phx-value-id={doc.document_id}
              phx-keydown="select_document_key"
              role="button"
              tabindex="0"
              class="group flex w-full cursor-pointer flex-col gap-1 rounded-md border border-transparent px-3 py-2 text-left text-sm text-white/80 transition hover:bg-white/12 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/30"
            >
              <span class="font-medium text-white group-hover:text-theme-accent">{title}</span>
              <p class="text-xs uppercase tracking-wide text-theme-muted">
                Viewed {format_datetime(doc.occurred_at)}
              </p>
            </div>
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
          class={link_classes(segment) <> " underline text-theme-accent"}
          target="_blank"
          rel="noopener"
        >
          {String.trim(segment[:text] || "")}
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

  defp link_classes(segment) do
    annotations = Map.get(segment, :annotations, %{}) || %{}

    [
      annotations[:bold] && "font-semibold",
      annotations[:italic] && "italic",
      annotations[:strikethrough] && "line-through",
      annotations[:underline] && "underline",
      annotations[:code] && "kb-inline-code"
    ]
    |> Enum.filter(& &1)
    |> Enum.join(" ")
  end

  defp collection_item_classes(selected?) do
    [
      "flex w-full items-center justify-between gap-3 rounded-lg border border-theme-border border-opacity-60 px-4 py-3 text-left text-sm text-theme-text transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-theme-primary/30 bg-theme-surfaceMuted cursor-pointer",
      selected? && "border-theme-border text-theme-text",
      not selected? && "hover:bg-theme-surfaceRaised"
    ]
    |> Enum.filter(& &1)
    |> Enum.join(" ")
  end

  defp document_item_classes(selected?) do
    [
      "flex w-full flex-col gap-2 rounded-lg border border-transparent px-4 py-3 text-left text-sm transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-theme-primary/30 bg-theme-surface cursor-pointer",
      selected? && "border-theme-primary bg-theme-primary text-theme-textActive",
      not selected? && "hover:bg-theme-surfaceRaised"
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
