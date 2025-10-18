defmodule DashboardSSDWeb.KbLive.Index do
  @moduledoc "Knowledge base search powered by Notion."
  use DashboardSSDWeb, :live_view

  alias DashboardSSD.Auth.Policy
  alias DashboardSSD.Integrations
  alias DashboardSSD.Integrations.Notion
  alias DashboardSSD.KnowledgeBase.{Activity, Cache, Catalog, Types}

  import DashboardSSDWeb.KbComponents

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, maybe_load_document_from_params(socket, params)}
  end

  @impl true
  def mount(params, _session, socket) do
    user = socket.assigns.current_user

    if Policy.can?(user, :read, :kb) do
      {collections, collection_errors} = load_collections()

      {selected_collection_id, documents_by_collection, document_errors, selected_document,
       selected_document_id, reader_error,
       expanded_collections} =
        preload_collections(collections)

      {recent_documents, recent_errors} = load_recent_documents(user)

      documents = documents_for_collection(documents_by_collection, selected_collection_id)

      socket =
        assign(socket,
          current_path: "/kb",
          page_title: "Knowledge Base",
          query: "",
          results: [],
          search_performed: false,
          search_loading: false,
          mobile_menu_open: false,
          collections: collections,
          collection_errors: collection_errors,
          selected_collection_id: selected_collection_id,
          document_errors: document_errors,
          documents_by_collection: documents_by_collection,
          documents: documents,
          selected_document: selected_document,
          selected_document_id: selected_document_id,
          reader_error: reader_error,
          reader_loading: false,
          recent_documents: recent_documents,
          recent_errors: recent_errors,
          expanded_collections: expanded_collections,
          search_dropdown_open: false,
          pending_document_id: nil
        )
        |> maybe_load_document_from_params(params)

      {:ok, socket}
    else
      {:ok,
       socket
       |> assign(:current_path, "/kb")
       |> put_flash(:error, "You don't have permission to access this page")
       |> redirect(to: ~p"/")}
    end
  end

  defp maybe_load_document_from_params(socket, %{"document_id" => document_id})
       when is_binary(document_id) do
    socket
    |> assign(:pending_document_id, document_id)
    |> assign(:reader_loading, true)
    |> assign(:selected_document_id, document_id)
    |> assign(:selected_document, nil)
    |> assign(:reader_error, nil)
    |> then(fn s ->
      send(self(), {:load_document, document_id, [source: :url]})
      s
    end)
  end

  defp maybe_load_document_from_params(socket, _params), do: socket

  @impl true
  def handle_event("typeahead_search", %{"query" => query}, socket) do
    query = String.trim(query || "")

    if query == "" do
      {:noreply,
       socket
       |> assign(:query, "")
       |> assign(:results, [])
       |> assign(:search_performed, false)
       |> assign(:search_dropdown_open, false)
       |> clear_flash(:error)}
    else
      case Integrations.notion_search(query,
             body: %{filter: %{property: "object", value: "page"}}
           ) do
        {:ok, %{"results" => results}} ->
          parsed = parse_results(results)

          {:noreply,
           socket
           |> assign(:query, query)
           |> assign(:results, parsed)
           |> assign(:search_performed, true)
           |> assign(:search_dropdown_open, true)
           |> clear_flash(:error)}

        {:error, {:missing_env, _env}} ->
          {:noreply,
           socket
           |> assign(:query, query)
           |> assign(:results, [])
           |> assign(:search_performed, true)
           |> assign(:search_dropdown_open, true)
           |> put_flash(:error, "Notion integration is not configured.")}

        {:error, reason} ->
          {:noreply,
           socket
           |> assign(:query, query)
           |> assign(:results, [])
           |> assign(:search_performed, true)
           |> assign(:search_dropdown_open, true)
           |> put_flash(:error, error_message(reason))}
      end
    end
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {:noreply,
     socket
     |> assign(:query, "")
     |> assign(:results, [])
     |> assign(:search_performed, false)
     |> assign(:search_dropdown_open, false)
     |> assign(:search_feedback, nil)
     |> clear_flash(:error)}
  end

  @impl true
  def handle_event("clear_search_key", %{"key" => key}, socket)
      when key in ["Enter", " ", "Space"] do
    handle_event("clear_search", %{}, socket)
  end

  @impl true
  def handle_event("clear_search_key", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("close_search_dropdown", _params, socket) do
    {:noreply, assign(socket, :search_dropdown_open, false)}
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
  def handle_event("toggle_collection", %{"id" => raw_id}, socket) do
    collection_id = blank_to_nil(raw_id)

    cond do
      is_nil(collection_id) ->
        {:noreply, socket}

      MapSet.member?(socket.assigns.expanded_collections, collection_id) ->
        {:noreply,
         assign(
           socket,
           :expanded_collections,
           MapSet.delete(socket.assigns.expanded_collections, collection_id)
         )}

      true ->
        {documents, document_errors} = load_documents(collection_id)

        # If the collection has no documents and no errors, remove it from the list
        if documents == [] and document_errors == [] and
             Map.has_key?(socket.assigns, :collections) do
          filtered = Enum.reject(socket.assigns[:collections] || [], &(&1.id == collection_id))

          {:noreply,
           socket
           |> assign(:collections, filtered)
           |> assign(:document_errors, document_errors_map(socket))}
        else
          documents_by_collection = documents_map(socket)
          existing_document_errors = document_errors_map(socket)

          socket =
            socket
            |> assign(
              :documents_by_collection,
              Map.put(documents_by_collection, collection_id, documents)
            )
            |> assign(
              :document_errors,
              put_document_errors(existing_document_errors, collection_id, document_errors)
            )
            |> assign(
              :expanded_collections,
              MapSet.put(socket.assigns.expanded_collections, collection_id)
            )
            |> assign(:selected_collection_id, collection_id)
            |> assign_documents(collection_id)

          {:noreply, socket}
        end
    end
  end

  @impl true
  def handle_event("select_collection", params, socket) do
    handle_event("toggle_collection", params, socket)
  end

  @impl true
  def handle_event("toggle_collection_key", %{"id" => id, "key" => key}, socket)
      when key in ["Enter", " ", "Space"] do
    handle_event("toggle_collection", %{"id" => id}, socket)
  end

  @impl true
  def handle_event("toggle_collection_key", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_document_key", %{"id" => id, "key" => key}, socket)
      when key in ["Enter", " ", "Space"] do
    handle_event("select_document", %{"id" => id}, socket)
  end

  @impl true
  def handle_event("select_document_key", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_document", %{"id" => document_id}, socket) do
    socket =
      socket
      |> assign(:selected_document_id, document_id)
      |> assign(:search_dropdown_open, false)

    {:noreply,
     socket
     |> push_patch(to: ~p"/kb?document_id=#{document_id}")
     |> start_document_load(document_id,
       source: :collection,
       collection_id: socket.assigns[:selected_collection_id]
     )}
  end

  @impl true
  def handle_event("open_search_result_key", %{"key" => key} = params, socket)
      when key in ["Enter", " ", "Space"] do
    params = Map.delete(params, "key")
    handle_event("open_search_result", params, socket)
  end

  @impl true
  def handle_event("open_search_result_key", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("open_search_result", %{"id" => document_id} = params, socket) do
    collection_id = params |> Map.get("collection") |> blank_to_nil()

    socket =
      socket
      |> assign(:selected_document_id, document_id)
      |> assign(:search_dropdown_open, false)

    {:noreply,
     socket
     |> push_patch(to: ~p"/kb?document_id=#{document_id}")
     |> start_document_load(document_id,
       source: :search,
       collection_id: collection_id
     )}
  end

  @impl true
  def handle_event("copy_share_link", %{"url" => url}, socket) do
    {:noreply,
     socket
     |> push_event("copy-to-clipboard", %{text: url})
     |> put_flash(:info, "Share link copied to clipboard")}
  end

  @impl true
  def handle_info({:load_document, document_id, opts}, socket) do
    if socket.assigns[:pending_document_id] != document_id do
      {:noreply, socket}
    else
      load_document_detail_with_cache_check(document_id)
      |> handle_document_load_result(socket, document_id, opts)
    end
  end

  @impl true
  def handle_info({:check_document_update, document_id, cached_last_updated}, socket) do
    # Only check if this document is still the selected one
    if socket.assigns[:selected_document_id] == document_id do
      case check_document_updated(document_id, cached_last_updated) do
        {:updated, new_document} ->
          # Update the cache and refresh the UI
          Cache.put(:collections, {:document_detail, document_id}, new_document)
          record_document_view(socket.assigns[:current_user], new_document)

          {:noreply,
           socket
           |> assign(:selected_document, new_document)
           |> assign(:reader_error, nil)}

        {:not_updated, _} ->
          # Document hasn't changed, do nothing
          {:noreply, socket}

        {:error, _reason} ->
          # Could not check for updates, silently ignore
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:search_result, query, result}, socket) do
    case result do
      {:ok, %{"results" => results}} ->
        parsed = parse_results(results)

        {:noreply,
         socket
         |> assign(:query, query)
         |> assign(:results, parsed)
         |> assign(:search_performed, true)
         |> assign(:search_dropdown_open, true)
         |> assign(:search_loading, false)
         |> clear_flash(:error)}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:query, query)
         |> assign(:results, [])
         |> assign(:search_performed, true)
         |> assign(:search_dropdown_open, true)
         |> assign(:search_loading, false)
         |> put_flash(:error, error_message(reason))}
    end
  end

  defp handle_document_load_result(result, socket, document_id, opts) do
    case result do
      {:cached, document} ->
        record_document_view(socket.assigns[:current_user], document)
        socket = finish_document_load(socket, document, opts)
        # Trigger background check for updates (only in non-test environments)
        unless Application.get_env(:dashboard_ssd, :test_env?, false) do
          send(self(), {:check_document_update, document_id, document.last_updated_at})
        end

        {:noreply, socket}

      {:fetched, document} ->
        record_document_view(socket.assigns[:current_user], document)
        {:noreply, finish_document_load(socket, document, opts)}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:pending_document_id, nil)
         |> assign(:reader_loading, false)
         |> assign(:reader_error, %{document_id: document_id, reason: reason})
         |> assign(:selected_document, nil)
         |> assign(:search_dropdown_open, false)}
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
        {filter_collections_on_load(collections), errors}

      {:error, reason} ->
        {[], [%{reason: reason}]}
    end
  end

  defp load_recent_documents(nil), do: {[], []}

  defp load_recent_documents(user) do
    case Activity.recent_documents(user) do
      {:ok, docs} -> {dedupe_recent_documents(docs), []}
      {:error, reason} -> {[], [%{reason: reason}]}
    end
  end

  defp preload_collections([]), do: {nil, %{}, %{}, nil, nil, nil, MapSet.new()}

  defp preload_collections([first | _]) do
    collection_id = first.id
    {documents, document_errors} = load_documents(collection_id)
    {selected_document, reader_error, selected_document_id} = preload_first_document(documents)

    documents_by_collection =
      if collection_id do
        %{collection_id => documents}
      else
        %{}
      end

    document_errors_map =
      if document_errors == [] do
        %{}
      else
        %{collection_id => document_errors}
      end

    expanded =
      if collection_id != nil and documents != [] do
        MapSet.new([collection_id])
      else
        MapSet.new()
      end

    {collection_id, documents_by_collection, document_errors_map, selected_document,
     selected_document_id, reader_error, expanded}
  end

  defp load_documents(nil), do: {[], []}

  defp load_documents(collection_id) do
    case Catalog.list_documents(collection_id) do
      {:ok, %{documents: documents, errors: errors}} -> {documents, errors}
      {:error, reason} -> {[], [%{collection_id: collection_id, reason: reason}]}
    end
  end

  defp put_document_errors(errors_map, key, []), do: Map.delete(errors_map, key || :general)

  defp put_document_errors(errors_map, key, errors),
    do: Map.put(errors_map, key || :general, errors)

  defp ensure_documents_loaded(socket, nil), do: socket

  defp ensure_documents_loaded(socket, collection_id) do
    documents_by_collection = documents_map(socket)

    if Map.has_key?(documents_by_collection, collection_id) do
      socket
    else
      {documents, errors} = load_documents(collection_id)
      updated_documents = Map.put(documents_by_collection, collection_id, documents)
      document_errors = document_errors_map(socket)

      socket
      |> assign(:documents_by_collection, updated_documents)
      |> assign(
        :document_errors,
        put_document_errors(document_errors, collection_id, errors)
      )
    end
  end

  defp ensure_collection_expanded(socket, nil), do: socket

  defp ensure_collection_expanded(socket, collection_id) do
    assign(
      socket,
      :expanded_collections,
      MapSet.put(expanded_collections(socket), collection_id)
    )
  end

  defp ensure_document_in_collection(socket, %Types.DocumentDetail{} = document) do
    collection_id = document.collection_id
    documents_by_collection = documents_map(socket)

    cond do
      is_nil(collection_id) ->
        socket

      not Map.has_key?(documents_by_collection, collection_id) ->
        socket

      Enum.any?(Map.get(documents_by_collection, collection_id, []), &(&1.id == document.id)) ->
        socket

      true ->
        summary =
          struct!(
            Types.DocumentSummary,
            id: document.id,
            collection_id: collection_id,
            title: document.title,
            summary: document.summary,
            tags: document.tags,
            owner: document.owner,
            share_url: document.share_url,
            last_updated_at: document.last_updated_at,
            synced_at: document.synced_at
          )

        updated =
          Map.update(documents_by_collection, collection_id, [summary], fn docs ->
            [summary | docs]
          end)

        assign(socket, :documents_by_collection, updated)
    end
  end

  defp documents_for_collection(_documents_by_collection, nil), do: []

  defp documents_for_collection(documents_by_collection, collection_id) do
    Map.get(documents_by_collection, collection_id, [])
  end

  defp documents_map(socket) do
    Map.get(socket.assigns, :documents_by_collection, %{})
  end

  defp document_errors_map(socket) do
    case Map.get(socket.assigns, :document_errors, %{}) do
      value when is_map(value) -> value
      _ -> %{}
    end
  end

  defp expanded_collections(socket) do
    case Map.get(socket.assigns, :expanded_collections) do
      %MapSet{} = set -> set
      _ -> MapSet.new()
    end
  end

  defp assign_documents(socket, nil) do
    docs =
      documents_map(socket)
      |> documents_for_collection(socket.assigns.selected_collection_id)

    assign(socket, :documents, docs)
  end

  defp assign_documents(socket, collection_id) do
    docs = documents_for_collection(documents_map(socket), collection_id)

    assign(socket, :documents, docs)
  end

  defp start_document_load(socket, document_id, opts) do
    send(self(), {:load_document, document_id, opts})

    socket
    |> assign(:pending_document_id, document_id)
    |> assign(:reader_loading, true)
    |> assign(:reader_error, nil)
  end

  defp finish_document_load(socket, document, opts) do
    {recent_documents, recent_errors} = refresh_recent_documents(socket, document)
    collection_hint = Keyword.get(opts, :collection_id)

    socket =
      socket
      |> ensure_documents_loaded(collection_hint)
      |> ensure_documents_loaded(document.collection_id)
      |> ensure_collection_expanded(collection_hint)
      |> ensure_collection_expanded(document.collection_id)
      |> ensure_document_in_collection(document)

    selected_collection_id =
      document.collection_id || collection_hint || socket.assigns.selected_collection_id

    socket
    |> assign(:pending_document_id, nil)
    |> assign(:reader_loading, false)
    |> assign(:selected_collection_id, selected_collection_id)
    |> assign(:selected_document, document)
    |> assign(:selected_document_id, document.id)
    |> assign(:reader_error, nil)
    |> assign(:query, "")
    |> assign(:results, [])
    |> assign(:search_performed, false)
    |> assign(:search_dropdown_open, false)
    |> assign(:recent_documents, recent_documents)
    |> assign(:recent_errors, recent_errors)
    |> assign(:search_feedback, nil)
    |> assign_documents(selected_collection_id)
  end

  defp dedupe_recent_documents(documents) when is_list(documents) do
    Enum.uniq_by(documents, & &1.document_id)
  end

  defp refresh_recent_documents(socket, %Types.DocumentDetail{} = document) do
    existing_recent = socket.assigns[:recent_documents] || []
    existing_errors = socket.assigns[:recent_errors] || []

    {fetched_docs, errors} = fetch_recent_documents(socket, existing_recent, existing_errors)

    updated =
      fetched_docs
      |> move_document_to_front(document, socket)
      |> dedupe_recent_documents()
      |> trim_recent_documents(5)

    {updated, errors}
  end

  defp recent_activity_entry(document, socket) do
    %Types.RecentActivity{
      id: nil,
      user_id: socket.assigns[:current_user] && socket.assigns.current_user.id,
      document_id: document.id,
      document_title: document.title,
      document_icon: document.icon,
      document_share_url: document.share_url,
      occurred_at: document.last_updated_at || DateTime.utc_now(),
      metadata: %{}
    }
  end

  defp fetch_recent_documents(socket, existing_recent, existing_errors) do
    case socket.assigns[:current_user] do
      nil ->
        {existing_recent, existing_errors}

      user ->
        case Activity.recent_documents(user) do
          {:ok, fetched} ->
            {dedupe_recent_documents(fetched), []}

          {:error, reason} ->
            {existing_recent, [%{reason: reason}]}
        end
    end
  end

  defp move_document_to_front(documents, document, socket) do
    entry =
      Enum.find(documents, &(&1.document_id == document.id)) ||
        recent_activity_entry(document, socket)

    rest = Enum.reject(documents, &(&1.document_id == document.id))
    [entry | rest]
  end

  defp trim_recent_documents(documents, count), do: Enum.take(documents, count)

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp preload_first_document([]), do: {nil, nil, nil}

  defp preload_first_document([document | _]) do
    case load_document_detail(document.id) do
      {:ok, detail} -> {detail, nil, document.id}
      {:error, reason} -> {nil, %{document_id: document.id, reason: reason}, nil}
    end
  end

  defp load_document_detail_with_cache_check(nil), do: {:error, :invalid_document}

  defp load_document_detail_with_cache_check(document_id) do
    cache_key = {:document_detail, document_id}

    case Cache.get(:collections, cache_key) do
      {:ok, document} ->
        {:cached, document}

      :miss ->
        case Catalog.get_document(document_id) do
          {:ok, document} -> {:fetched, document}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp load_document_detail(nil), do: {:error, :invalid_document}

  defp load_document_detail(document_id) do
    Catalog.get_document(document_id)
  end

  defp check_document_updated(document_id, cached_last_updated) do
    with {:ok, token} <- fetch_notion_token(),
         {:ok, page} <- Notion.retrieve_page(token, document_id) do
      notion_last_edited = parse_timestamp(Map.get(page, "last_edited_time"))

      if notion_last_edited && cached_last_updated &&
           DateTime.compare(notion_last_edited, cached_last_updated) == :gt do
        # Document has been updated, fetch the full document
        case Catalog.get_document(document_id, cache?: false) do
          {:ok, document} -> {:updated, document}
          {:error, reason} -> {:error, reason}
        end
      else
        {:not_updated, notion_last_edited}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_notion_token do
    config = Application.get_env(:dashboard_ssd, :integrations, [])

    token =
      cond do
        present?(Keyword.get(config, :notion_token)) ->
          Keyword.get(config, :notion_token)

        present?(System.get_env("NOTION_TOKEN")) ->
          System.get_env("NOTION_TOKEN")

        present?(System.get_env("NOTION_API_KEY")) ->
          System.get_env("NOTION_API_KEY")

        true ->
          nil
      end

    if present?(token) do
      {:ok, token}
    else
      {:error, {:missing_env, "NOTION_TOKEN"}}
    end
  end

  defp parse_timestamp(nil), do: nil

  defp parse_timestamp(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _offset} -> dt
      _ -> nil
    end
  end

  defp parse_timestamp(_), do: nil

  defp present?(value), do: not is_nil(value) and value != ""

  defp record_document_view(nil, _document), do: :ok

  defp record_document_view(user, document) do
    Activity.record_view(user, %{
      document_id: document.id,
      document_title: document.title,
      document_icon: document.icon,
      document_share_url: document.share_url
    })
  end

  defp format_reader_error(nil), do: nil

  defp format_reader_error(%{document_id: id, reason: reason}),
    do: "Unable to load #{id}: #{format_reason(reason)}"

  defp format_reader_error(reason), do: format_reason(reason)

  defp format_reason({:http_error, status, _}), do: "HTTP error #{status}"
  defp format_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_reason(reason), do: inspect(reason)

  defp filter_collections_on_load(collections) do
    if hide_empty_collections?() do
      Enum.reject(collections, fn col ->
        is_integer(col.document_count) and col.document_count == 0
      end)
    else
      collections
    end
  end

  defp hide_empty_collections? do
    Application.get_env(:dashboard_ssd, DashboardSSD.KnowledgeBase, [])
    |> Keyword.get(:hide_empty_collections, false)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-6 lg:gap-8">
      <section class="theme-card px-4 py-4 sm:px-6">
        <form
          phx-change="typeahead_search"
          phx-submit="typeahead_search"
          class="flex flex-col gap-3 sm:flex-row sm:items-center sm:gap-4"
          autocomplete="off"
        >
          <div class="relative flex-1" phx-click-away="close_search_dropdown">
            <input
              type="search"
              name="query"
              value={@query}
              placeholder="Search the knowledge base"
              autocomplete="off"
              phx-debounce="300"
              phx-keydown="close_search_dropdown"
              phx-key="escape"
              class="w-full rounded-full border border-theme-border bg-theme-surfaceMuted px-4 py-2 pr-10 text-sm text-theme-text placeholder:text-theme-muted focus:border-theme-primary focus:outline-none"
            />

            <div
              :if={@query != ""}
              phx-click="clear_search"
              phx-keydown="clear_search_key"
              role="button"
              tabindex="0"
              class="absolute inset-y-0 right-3 flex items-center text-theme-muted transition hover:text-theme-text focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-theme-primary/40 cursor-pointer"
            >
              <span class="sr-only">Clear search</span>
              <.icon name="hero-x-mark" class="h-4 w-4" />
            </div>

            <div
              :if={@search_dropdown_open and @results != []}
              class="absolute left-0 right-0 top-full z-20 mt-2 overflow-hidden rounded-xl border border-theme-border bg-theme-surface shadow-theme-soft"
            >
              <ul class="flex flex-col divide-y divide-theme-border">
                <%= for result <- @results do %>
                  <li>
                    <div
                      phx-click="open_search_result"
                      phx-value-id={result.id}
                      phx-value-collection={result.collection_id}
                      phx-keydown="open_search_result_key"
                      role="button"
                      tabindex="0"
                      class="flex w-full cursor-pointer items-start gap-3 px-4 py-3 text-left text-sm text-theme-text transition hover:bg-theme-surfaceRaised focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-theme-primary/30"
                    >
                      <span :if={result.icon} class="text-xl leading-none text-theme-text">
                        {result.icon}
                      </span>
                      <div class="flex flex-1 flex-col gap-1">
                        <span class="text-sm font-medium text-theme-text">
                          {result.title}
                        </span>
                        <p :if={result.last_edited} class="text-xs text-theme-muted">
                          Updated {result.last_edited}
                        </p>
                        <a
                          :if={result.url}
                          href={result.url}
                          class="text-xs text-theme-accent underline underline-offset-2"
                          target="_blank"
                          rel="noopener"
                        >
                          {result.url}
                        </a>
                      </div>
                    </div>
                  </li>
                <% end %>
              </ul>
            </div>

            <div
              :if={@search_dropdown_open and @search_performed and @results == [] and @query != ""}
              class="absolute left-0 right-0 top-full z-20 mt-2 rounded-xl border border-theme-border bg-theme-surface px-4 py-3 text-sm text-theme-muted"
            >
              No documents matched your search.
            </div>
          </div>
        </form>
      </section>

      <div class="flex flex-col gap-6 lg:grid lg:grid-cols-[minmax(0,320px)_minmax(0,1fr)] lg:items-start lg:gap-8">
        <aside class="order-1 flex flex-col gap-6 lg:order-1">
          <.collection_tree
            collections={@collections}
            collection_errors={@collection_errors}
            documents_by_collection={@documents_by_collection}
            document_errors={@document_errors}
            expanded_ids={@expanded_collections}
            selected_collection_id={@selected_collection_id}
            selected_document_id={@selected_document_id}
          />
          <.recent_activity_list
            documents={@recent_documents}
            errors={@recent_errors}
            selected_document_id={@selected_document_id}
            class="hidden lg:block"
          />
        </aside>

        <section class="order-2 lg:order-2">
          <div class="theme-card h-full min-h-[360px] px-4 py-4 sm:px-6 lg:min-h-[70vh]">
            <.document_viewer
              document={@selected_document}
              error={format_reader_error(@reader_error)}
              loading={@reader_loading}
              share_url={@selected_document && url(~p"/kb?document_id=#{@selected_document.id}")}
            />
          </div>
        </section>

        <.recent_activity_list
          documents={@recent_documents}
          errors={@recent_errors}
          selected_document_id={@selected_document_id}
          class="order-3 lg:hidden"
        />
      </div>
    </div>
    """
  end
end
