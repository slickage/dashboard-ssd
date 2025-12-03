defmodule DashboardSSDWeb.KbComponents do
  @moduledoc """
  Function components used by the Knowledge Base experience.

    - Renders collection/document navigation lists and action menus for the KB.
  - Provides icon helpers that gracefully handle SVGs, remote images, and emoji fallbacks.
  - Wraps CodeHighlighter to display Notion code blocks inside LiveView templates.
  """

  use DashboardSSDWeb, :html

  alias DashboardSSD.KnowledgeBase.Types
  alias DashboardSSDWeb.CodeHighlighter
  alias Phoenix.LiveView.Rendered

  attr :icon, :string
  attr :size, :string, default: "sm"

  @spec document_icon(map()) :: Rendered.t()
  def document_icon(assigns) do
    ~H"""
    <%= if @icon do %>
      <%= cond do %>
        <% String.starts_with?(@icon, "http") -> %>
          <%= if String.ends_with?(@icon, ".svg") do %>
            <embed
              src={@icon}
              type="image/svg+xml"
              class={image_classes(@size)}
              width="16"
              height="16"
              alt="Document icon"
            />
          <% else %>
            <img
              src={@icon}
              class={image_classes(@size)}
              width="16"
              height="16"
              crossorigin="anonymous"
              alt="Document icon"
            />
          <% end %>
        <% true -> %>
          <span class={text_classes(@size)}>{@icon}</span>
      <% end %>
    <% end %>
    """
  end

  defp image_classes("lg"), do: "w-6 h-6 inline-block"
  defp image_classes(_), do: "w-4 h-4 inline-block"

  defp text_classes("lg"), do: "text-2xl"
  defp text_classes(_), do: "text-sm"

  attr :collections, :list, default: []
  attr :collection_errors, :list, default: []
  attr :documents_by_collection, :map, default: %{}
  attr :document_errors, :map, default: %{}
  attr :expanded_ids, :any, default: MapSet.new()
  attr :selected_collection_id, :any, default: nil
  attr :selected_document_id, :any, default: nil
  attr :key, :any, default: nil

  @doc """
  Renders an expandable tree view of collections and their documents.

  ## Assigns

  - `collections` - List of collection structs
  - `collection_errors` - List of collection-level errors
  - `documents_by_collection` - Map of collection IDs to document lists
  - `document_errors` - Map of collection IDs to document error lists
  - `expanded_ids` - Set of expanded collection IDs
  - `selected_collection_id` - ID of selected collection
  - `selected_document_id` - ID of selected document
  """
  @spec collection_tree(map()) :: Rendered.t()
  def collection_tree(assigns) do
    ~H"""
    <section class="flex flex-col gap-3">
      <h3 class="text-xs font-semibold uppercase tracking-[0.16em] text-theme-muted">
        Collections
      </h3>

      <%= if Enum.any?(@collection_errors) do %>
        <%= if badge_only_errors?(@collection_errors) do %>
          <div class="text-xs">
            <p :for={error <- @collection_errors}>{format_error(error)}</p>
          </div>
        <% else %>
          <div class="rounded-md border border-amber-400/40 bg-amber-400/10 px-3 py-2 text-xs text-amber-200">
            <p :for={error <- @collection_errors}>{format_error(error)}</p>
          </div>
        <% end %>
      <% end %>

      <% general_doc_errors = Map.get(@document_errors, :general, []) %>
      <%= if general_doc_errors != [] do %>
        <%= if badge_only_errors?(general_doc_errors) do %>
          <div class="text-xs">
            <p :for={error <- general_doc_errors}>{format_error(error)}</p>
          </div>
        <% else %>
          <div class="rounded-md border border-amber-400/40 bg-amber-400/10 px-3 py-2 text-xs text-amber-200">
            <p :for={error <- general_doc_errors}>{format_error(error)}</p>
          </div>
        <% end %>
      <% end %>

      <p :if={Enum.empty?(@collections)} class="text-sm text-theme-muted">
        No curated collections are available yet.
      </p>
      <p :if={Enum.empty?(@collections)} class="text-sm text-theme-muted">
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
                  aria-label={"Toggle #{collection.name} collection"}
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
                        aria-label={"Select #{document.title} document"}
                        phx-keydown="select_document_key"
                      >
                        <div class="flex items-center gap-2">
                          <.document_icon icon={document.icon} />
                          <span class="text-sm font-medium text-theme-text">{document.title}</span>
                        </div>
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
  attr :share_url, :string, default: nil

  @doc """
  Renders a document viewer with content blocks and metadata.

  ## Assigns

  - `document` - DocumentDetail struct to display
  - `error` - Error message if document failed to load
  - `loading` - Whether the document is currently loading
  - `share_url` - URL for sharing the document
  """
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
              <h1 class="text-2xl font-semibold text-white flex items-center gap-3">
                <.document_icon icon={@document.icon} size="lg" />
                <span>{@document.title}</span>
              </h1>
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
                <a
                  :if={@share_url}
                  href="#"
                  phx-click="copy_share_link"
                  phx-value-url={@share_url}
                  class="text-theme-accent underline"
                >
                  Copy URL
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
              <%= for entry <- assign_numbers(@document.rendered_blocks) do %>
                <.kb_block block={entry.block} level={0} number={entry.number} />
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
  attr :class, :string, default: ""

  @spec recent_activity_list(map()) :: Rendered.t()
  def recent_activity_list(assigns) do
    ~H"""
    <section class={["flex flex-col gap-2", @class]}>
      <header class="flex items-center justify-between gap-2">
        <h3 class="text-xs font-semibold uppercase tracking-[0.16em] text-theme-muted">
          {@title}
        </h3>
      </header>

      <%= if Enum.any?(@errors) do %>
        <%= if badge_only_errors?(@errors) do %>
          <div class="text-xs">
            <p :for={error <- @errors}>{format_error(error)}</p>
          </div>
        <% else %>
          <div class="rounded-md border border-amber-400/40 bg-amber-400/10 px-3 py-2 text-xs text-amber-200">
            <p :for={error <- @errors}>{format_error(error)}</p>
          </div>
        <% end %>
      <% end %>

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
              aria-label={"Select #{title} document"}
              class="group flex w-full cursor-pointer flex-col gap-1 rounded-md border border-transparent px-3 py-2 text-left text-sm text-white/80 transition hover:bg-white/12 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/30"
            >
              <div class="flex items-center gap-2">
                <.document_icon icon={doc.document_icon} />
                <span class="font-medium text-white group-hover:text-theme-accent">{title}</span>
              </div>
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

  attr :block, :map, required: true
  attr :level, :integer, default: 0
  attr :number, :integer, default: nil

  @doc """
  Renders a Notion block with appropriate HTML styling.

  Supports various block types including headings, paragraphs, lists, quotes, code blocks, images, and tables.
  """
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
        <p
          class="text-sm leading-relaxed text-white/90"
          style={if @level > 0, do: indent_style(@level)}
        >
          <.kb_rich_text segments={@block.segments} />
        </p>
      <% :bulleted_list_item -> %>
        <div class="text-sm leading-relaxed text-white/90" style={indent_style(@level)}>
          <div class="flex items-start gap-2">
            <span class="pt-1 text-xs">•</span>
            <span><.kb_rich_text segments={@block.segments} /></span>
          </div>
        </div>
      <% :numbered_list_item -> %>
        <div class="text-sm leading-relaxed text-white/90" style={indent_style(@level)}>
          <div class="flex items-start gap-2">
            <span class="pt-1 text-xs">{@number || 1}.</span>
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
          <pre class="kb-code-pre"><code class={"highlight kb-code language-" <> CodeHighlighter.css_language(language)}><%= highlighted %></code></pre>
        </div>
      <% :divider -> %>
        <hr class="border-white/10" />
      <% :image -> %>
        <figure class="flex flex-col gap-2">
          <img
            :if={@block.source}
            src={@block.source}
            class="max-w-full rounded-md"
            alt="Document image"
          />
          <figcaption :if={@block.caption != []} class="text-xs text-theme-muted">
            <.kb_rich_text segments={@block.caption} />
          </figcaption>
        </figure>
      <% :bookmark -> %>
        <div class="flex flex-col gap-2">
          <a
            href={@block.url}
            target="_blank"
            rel="noopener noreferrer"
            class="text-blue-400 hover:text-blue-300 underline"
          >
            {@block.url}
          </a>
          <div :if={@block.caption != []} class="text-xs text-theme-muted">
            <.kb_rich_text segments={@block.caption} />
          </div>
        </div>
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
      <% :link_to_page -> %>
        <% fallback_label =
          @block.segments
          |> Enum.map(&String.trim(&1[:text] || ""))
          |> Enum.join(" ")
          |> String.trim() %>
        <% resolved_label =
          cond do
            is_binary(@block.target_title) and String.trim(@block.target_title) != "" ->
              String.trim(@block.target_title)

            fallback_label != "" ->
              fallback_label

            true ->
              if @block.target_type == "database_id",
                do: "Open linked database",
                else: "Open linked page"
          end %>
        <div class="flex flex-wrap items-center gap-2 text-sm" style={indent_style(@level)}>
          <%= cond do %>
            <% @block.target_type == "page_id" and is_binary(@block.target_id) and @block.target_id != "" -> %>
              <.link
                patch={~p"/kb?document_id=#{@block.target_id}"}
                class="inline-flex items-center gap-2 text-theme-accent underline"
              >
                <.document_icon :if={@block.target_icon} icon={@block.target_icon} size="sm" />
                <span>{resolved_label}</span>
              </.link>
            <% @block.target_type == "database_id" and is_binary(@block.target_id) and @block.target_id != "" -> %>
              <span class="inline-flex items-center gap-2 text-xs text-theme-muted">
                <.document_icon :if={@block.target_icon} icon={@block.target_icon} size="sm" />
                <span>Linked database: {@block.target_id}</span>
              </span>
            <% true -> %>
              <span class="text-xs text-theme-muted">{resolved_label}</span>
          <% end %>
        </div>
      <% :unsupported -> %>
        <div class="text-xs text-theme-muted italic">
          Unsupported block ({@block.raw_type})
        </div>
    <% end %>

    <div :if={@block.children != []} class="mt-2 flex flex-col gap-2">
      <%= for child <- assign_numbers_to_children(@block.children) do %>
        <.kb_block block={child.block} level={@level + 1} number={child.number} />
      <% end %>
    </div>
    """
  end

  attr :segments, :list, default: []

  @doc """
  Renders rich text segments with formatting annotations.

  Supports bold, italic, strikethrough, underline, code, and links.
  """
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

  defp icon_to_string(%{"emoji" => emoji}), do: emoji
  defp icon_to_string(%{emoji: emoji}), do: emoji
  defp icon_to_string(_), do: "💡"

  defp badge_only_errors?(errors) when is_list(errors) do
    Enum.all?(errors, fn
      %{reason: {:missing_env, _}} -> true
      {:missing_env, _} -> true
      _ -> false
    end)
  end

  defp format_error(%{collection_id: id, reason: reason}) do
    "#{id}: #{friendly_reason(reason)}"
  end

  defp format_error(%{reason: reason}), do: friendly_reason(reason)

  defp format_error(reason), do: friendly_reason(reason)

  defp friendly_reason({:missing_env, env}),
    do:
      Phoenix.HTML.raw(
        ~s(<span class="theme-badge theme-badge-warning">Missing environment variable #{env}</span>)
      )

  defp friendly_reason({:http_error, status, _body}), do: "HTTP error #{status}"
  defp friendly_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp friendly_reason(reason), do: inspect(reason)

  defp indent_style(level) do
    px = 24 + max(level, 0) * 18
    "padding-left: #{px}px;"
  end

  defp assign_numbers(blocks) do
    {result, _} =
      Enum.reduce(blocks, {[], nil}, fn block, {acc, counter} ->
        if block.type == :numbered_list_item do
          new_counter = (counter || 0) + 1
          {[%{block: block, number: new_counter} | acc], new_counter}
        else
          {[%{block: block, number: nil} | acc], nil}
        end
      end)

    Enum.reverse(result)
  end

  defp assign_numbers_to_children(children) do
    {result, _} =
      Enum.reduce(children, {[], nil}, fn child, {acc, counter} ->
        if child.type == :numbered_list_item do
          new_counter = (counter || 0) + 1
          {[%{block: child, number: new_counter} | acc], new_counter}
        else
          {[%{block: child, number: nil} | acc], nil}
        end
      end)

    Enum.reverse(result)
  end
end
