defmodule DashboardSSDWeb.KbLive.Index do
  @moduledoc "Knowledge base search powered by Notion."
  use DashboardSSDWeb, :live_view

  alias DashboardSSD.Auth.Policy
  alias DashboardSSD.Integrations
  alias DashboardSSD.KnowledgeBase.{Activity, Catalog}
  alias DashboardSSDWeb.CodeHighlighter

  import DashboardSSDWeb.KbComponents

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if Policy.can?(user, :read, :kb) do
      {collections, collection_errors} = load_collections()

      {selected_collection_id, documents, document_errors, selected_document,
       selected_document_id,
       reader_error} =
        preload_collections(collections)

      {recent_documents, recent_errors} = load_recent_documents(user)

      {:ok,
       assign(socket,
         current_path: "/kb",
         page_title: "Knowledge Base",
         query: "",
         results: [],
         search_performed: false,
         mobile_menu_open: false,
         collections: collections,
         collection_errors: collection_errors,
         selected_collection_id: selected_collection_id,
         documents: documents,
         document_errors: document_errors,
         selected_document: selected_document,
         selected_document_id: selected_document_id,
         reader_error: reader_error,
         recent_documents: recent_documents,
         recent_errors: recent_errors,
         code_stylesheet: CodeHighlighter.stylesheet()
       )}
    else
      {:ok,
       socket
       |> assign(:current_path, "/kb")
       |> assign(:code_stylesheet, CodeHighlighter.stylesheet())
       |> put_flash(:error, "You don't have permission to access this page")
       |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    query = String.trim(query || "")

    if query == "" do
      {:noreply,
       socket
       |> assign(:query, "")
       |> assign(:results, [])
       |> assign(:search_performed, false)
       |> put_flash(:error, "Enter a search term to look up Notion content.")}
    else
      case Integrations.notion_search(query) do
        {:ok, %{"results" => results}} ->
          parsed = parse_results(results)

          {:noreply,
           socket
           |> assign(:query, query)
           |> assign(:results, parsed)
           |> assign(:search_performed, true)
           |> clear_flash(:error)}

        {:error, {:missing_env, _env}} ->
          {:noreply,
           socket
           |> assign(:query, query)
           |> assign(:results, [])
           |> assign(:search_performed, true)
           |> put_flash(:error, "Notion integration is not configured.")}

        {:error, reason} ->
          {:noreply,
           socket
           |> assign(:query, query)
           |> assign(:results, [])
           |> assign(:search_performed, true)
           |> put_flash(:error, error_message(reason))}
      end
    end
  end

  @impl true
  def handle_event("toggle_mobile_menu", _params, socket) do
    {:noreply, assign(socket, mobile_menu_open: !socket.assigns.mobile_menu_open)}
  end

  @impl true
  def handle_event("close_mobile_menu", _params, socket) do
    {:noreply, assign(socket, mobile_menu_open: false)}
  end

  @impl true
  def handle_event("select_collection", %{"id" => collection_id}, socket) do
    {documents, document_errors} = load_documents(collection_id)
    {selected_document, reader_error, selected_document_id} = preload_first_document(documents)

    {:noreply,
     socket
     |> assign(:selected_collection_id, collection_id)
     |> assign(:documents, documents)
     |> assign(:document_errors, document_errors)
     |> assign(:selected_document, selected_document)
     |> assign(:selected_document_id, selected_document_id)
     |> assign(:reader_error, reader_error)}
  end

  @impl true
  def handle_event("select_document", %{"id" => document_id}, socket) do
    case load_document_detail(document_id) do
      {:ok, document} ->
        record_document_view(socket.assigns[:current_user], document)
        {recent_documents, recent_errors} = load_recent_documents(socket.assigns[:current_user])

        {:noreply,
         socket
         |> assign(:selected_document, document)
         |> assign(:selected_document_id, document_id)
         |> assign(:reader_error, nil)
         |> assign(:recent_documents, recent_documents)
         |> assign(:recent_errors, recent_errors)}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:reader_error, %{document_id: document_id, reason: reason})
         |> assign(:selected_document, nil)
         |> assign(:selected_document_id, nil)}
    end
  end

  @impl true
  def handle_event("open_search_result", %{"id" => document_id} = params, socket) do
    collection_id = Map.get(params, "collection")

    {selected_collection_id, documents, document_errors} =
      cond do
        is_nil(collection_id) or collection_id == "" ->
          {socket.assigns.selected_collection_id, socket.assigns.documents,
           socket.assigns.document_errors}

        collection_id == socket.assigns.selected_collection_id ->
          {collection_id, socket.assigns.documents, socket.assigns.document_errors}

        true ->
          {docs, errs} = load_documents(collection_id)
          {collection_id, docs, errs}
      end

    case load_document_detail(document_id) do
      {:ok, document} ->
        record_document_view(socket.assigns[:current_user], document)
        {recent_documents, recent_errors} = load_recent_documents(socket.assigns[:current_user])

        {:noreply,
         socket
         |> assign(:selected_collection_id, selected_collection_id)
         |> assign(:documents, documents)
         |> assign(:document_errors, document_errors)
         |> assign(:selected_document, document)
         |> assign(:selected_document_id, document_id)
         |> assign(:reader_error, nil)
         |> assign(:recent_documents, recent_documents)
         |> assign(:recent_errors, recent_errors)}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:selected_collection_id, selected_collection_id)
         |> assign(:documents, documents)
         |> assign(:document_errors, document_errors)
         |> assign(:selected_document, nil)
         |> assign(:selected_document_id, nil)
         |> assign(:reader_error, %{document_id: document_id, reason: reason})}
    end
  end

  defp parse_results(results) when is_list(results) do
    results
    |> Enum.filter(&Catalog.allowed_document?/1)
    |> Enum.map(fn result ->
      %{
        id: Map.get(result, "id"),
        title: extract_title(result),
        url: Map.get(result, "url"),
        collection_id: extract_collection_id(result),
        last_edited: format_last_edited(result["last_edited_time"]),
        icon: extract_icon(result)
      }
    end)
  end

  defp extract_title(%{"properties" => props}) when is_map(props) do
    props
    |> Enum.find_value(fn {_name, value} ->
      case value do
        %{"type" => "title", "title" => title} ->
          extract_plain_text(title)

        %{"type" => "rich_text", "rich_text" => rich} ->
          extract_plain_text(rich)

        _ ->
          nil
      end
    end)
    |> default_title()
  end

  defp extract_title(%{"title" => title}) when is_list(title) do
    extract_plain_text(title) |> default_title()
  end

  defp extract_title(_), do: "Untitled"

  defp extract_plain_text(list) when is_list(list) do
    list
    |> Enum.map_join(" ", &(&1["plain_text"] || ""))
    |> String.trim()
    |> case do
      "" -> nil
      text -> text
    end
  end

  defp extract_plain_text(_), do: nil

  defp default_title(nil), do: "Untitled"
  defp default_title(title), do: title

  defp extract_icon(%{"icon" => %{"emoji" => emoji}}) when is_binary(emoji), do: emoji
  defp extract_icon(%{"icon" => %{"type" => "emoji", "emoji" => emoji}}), do: emoji
  defp extract_icon(_), do: nil

  defp extract_collection_id(%{"parent" => %{"type" => "database_id", "database_id" => id}}),
    do: id

  defp extract_collection_id(%{parent: %{type: "database_id", database_id: id}}), do: id
  defp extract_collection_id(_), do: nil

  defp format_last_edited(nil), do: nil

  defp format_last_edited(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _offset} -> Calendar.strftime(dt, "%Y-%m-%d %H:%M")
      _ -> nil
    end
  end

  defp error_message({:http_error, status, _body}), do: "Notion API returned status #{status}."

  defp error_message(reason) when is_atom(reason),
    do: "Unable to reach Notion (#{inspect(reason)})."

  defp error_message(reason), do: "Unable to reach Notion (#{inspect(reason)})."

  defp load_collections do
    case Catalog.list_collections() do
      {:ok, %{collections: collections, errors: errors}} ->
        {collections, errors}

      {:error, reason} ->
        {[], [%{reason: reason}]}
    end
  end

  defp load_recent_documents(nil), do: {[], []}

  defp load_recent_documents(user) do
    case Activity.recent_documents(user) do
      {:ok, docs} -> {docs, []}
      {:error, reason} -> {[], [%{reason: reason}]}
    end
  end

  defp preload_collections([]), do: {nil, [], [], nil, nil, nil}

  defp preload_collections([first | _]) do
    collection_id = first.id
    {documents, document_errors} = load_documents(collection_id)
    {selected_document, reader_error, selected_document_id} = preload_first_document(documents)

    {collection_id, documents, document_errors, selected_document, selected_document_id,
     reader_error}
  end

  defp load_documents(nil), do: {[], []}

  defp load_documents(collection_id) do
    case Catalog.list_documents(collection_id) do
      {:ok, %{documents: documents, errors: errors}} -> {documents, errors}
      {:error, reason} -> {[], [%{collection_id: collection_id, reason: reason}]}
    end
  end

  defp preload_first_document([]), do: {nil, nil, nil}

  defp preload_first_document([document | _]) do
    case load_document_detail(document.id) do
      {:ok, detail} -> {detail, nil, document.id}
      {:error, reason} -> {nil, %{document_id: document.id, reason: reason}, nil}
    end
  end

  defp load_document_detail(nil), do: {:error, :invalid_document}

  defp load_document_detail(document_id) do
    Catalog.get_document(document_id)
  end

  defp record_document_view(nil, _document), do: :ok

  defp record_document_view(user, document) do
    Activity.record_view(user, %{
      document_id: document.id,
      document_title: document.title,
      document_share_url: document.share_url
    })
  end

  defp format_collection_error(%{collection_id: id, reason: reason}),
    do: "#{id}: #{format_reason(reason)}"

  defp format_collection_error(%{reason: reason}), do: format_reason(reason)
  defp format_collection_error(other), do: inspect(other)

  defp format_document_error(%{collection_id: id, reason: reason}),
    do: "#{id}: #{format_reason(reason)}"

  defp format_document_error(%{reason: reason}), do: format_reason(reason)
  defp format_document_error(other), do: inspect(other)

  defp format_reader_error(nil), do: nil

  defp format_reader_error(%{document_id: id, reason: reason}),
    do: "Unable to load #{id}: #{format_reason(reason)}"

  defp format_reader_error(reason), do: format_reason(reason)

  defp format_reason({:http_error, status, _}), do: "HTTP error #{status}"
  defp format_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_reason(reason), do: inspect(reason)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-8">
      <style :if={@code_stylesheet} type="text/css" data-kb-code-style="true">
        <%= @code_stylesheet %>
      </style>
      <div class="grid gap-6 lg:grid-cols-[minmax(0,280px)_minmax(0,340px)_minmax(0,1fr)]">
        <div class="space-y-4">
          <.collection_list collections={@collections} selected_id={@selected_collection_id} />

          <%= if @collection_errors != [] do %>
            <div class="rounded-md border border-amber-400/40 bg-amber-400/10 px-3 py-2 text-sm text-amber-200">
              <p :for={error <- @collection_errors}>{format_collection_error(error)}</p>
            </div>
          <% end %>
        </div>

        <div class="space-y-4">
          <.document_list documents={@documents} selected_id={@selected_document_id} />

          <%= if @document_errors != [] do %>
            <div class="rounded-md border border-amber-400/40 bg-amber-400/10 px-3 py-2 text-sm text-amber-200">
              <p :for={error <- @document_errors}>{format_document_error(error)}</p>
            </div>
          <% end %>
        </div>

        <div class="space-y-4">
          <.document_viewer document={@selected_document} error={format_reader_error(@reader_error)} />
        </div>
      </div>

      <.recent_activity_list documents={@recent_documents} errors={@recent_errors} />

      <div class="theme-card px-4 py-4 sm:px-6">
        <form phx-submit="search" class="flex flex-col gap-3 sm:flex-row sm:items-center sm:gap-4">
          <div class="flex flex-1 items-center gap-3">
            <input
              type="search"
              name="query"
              value={@query}
              placeholder="Search the knowledge base"
              class="w-full rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm text-white placeholder:text-theme-muted focus:border-white/30 focus:outline-none"
            />
          </div>
          <button
            type="submit"
            class="inline-flex items-center justify-center rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm font-medium text-white transition hover:border-white/20 hover:bg-white/10"
          >
            Search
          </button>
        </form>
      </div>

      <%= cond do %>
        <% @results != [] -> %>
          <div class="flex flex-col gap-4">
            <%= for result <- @results do %>
              <button
                type="button"
                phx-click="open_search_result"
                phx-value-id={result.id}
                phx-value-collection={result.collection_id}
                class="w-full text-left theme-card px-5 py-4 transition hover:border-white/20 hover:bg-white/5"
              >
                <div class="flex flex-wrap items-start gap-3">
                  <span :if={result.icon} class="text-2xl leading-none">{result.icon}</span>
                  <div class="flex flex-1 flex-col gap-1">
                    <p class="text-lg font-semibold text-white">{result.title}</p>
                    <p :if={result.last_edited} class="text-xs text-theme-muted">
                      Updated {result.last_edited}
                      <span :if={result.collection_id} class="ml-2">
                        • Collection {result.collection_id}
                      </span>
                    </p>
                  </div>
                  <div>
                    <a
                      href={result.url}
                      class="text-sm text-theme-accent underline"
                      target="_blank"
                      rel="noopener"
                    >
                      Open in Notion
                    </a>
                  </div>
                </div>
              </button>
            <% end %>
          </div>
        <% @search_performed and @results == [] -> %>
          <div class="rounded-md border border-white/10 bg-white/5 px-4 py-3 text-sm text-theme-muted">
            No documents matched your search.
          </div>
        <% true -> %>
          <div class="text-sm text-theme-muted">
            Enter a search term above to explore everything inside the knowledge base.
          </div>
      <% end %>
    </div>
    """
  end
end
