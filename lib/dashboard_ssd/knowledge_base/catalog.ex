defmodule DashboardSSD.KnowledgeBase.Catalog do
  @moduledoc """
  Handles curated collection and document metadata sourced from Notion.
  """

  alias DashboardSSD.Integrations.Notion
  alias DashboardSSD.KnowledgeBase.{Cache, Types}

  @default_ttl :timer.minutes(5)
  @auto_default_page_size 50
  @cache_namespace :collections
  @default_page_collection_id "kb:auto:pages"
  @page_collection_source "search:pages"
  @page_parent_types MapSet.new(["page_id", "workspace", "database_id"])

  @typedoc "Options accepted by catalog queries."
  @type opt ::
          {:ttl, non_neg_integer()}
          | {:cache?, boolean()}
          | {:page_size, pos_integer()}
  @type opts :: [opt]

  @doc """
  Returns curated collections with computed freshness metadata.
  """
  @spec list_collections(opts()) ::
          {:ok, %{collections: [Types.Collection.t()], errors: list()}} | {:error, term()}
  def list_collections(opts \\ []) do
    with {:ok, token} <- fetch_token() do
      list_collections_with_token(token, opts)
    end
  end

  @doc """
  Lists documents for a given collection identifier.
  """
  @spec list_documents(Types.collection_id(), opts()) ::
          {:ok, %{documents: [Types.DocumentSummary.t()], errors: list()}} | {:error, term()}
  def list_documents(collection_id, opts \\ []) do
    with {:ok, token} <- fetch_token() do
      cache? = Keyword.get(opts, :cache?, true)
      ttl = Keyword.get(opts, :ttl, @default_ttl)
      cache_key = {:documents, collection_id}

      fetch_fun = fn -> fetch_documents_from_notion(token, collection_id, opts) end

      result =
        if cache? do
          Cache.fetch(@cache_namespace, cache_key, fetch_fun, ttl: ttl)
        else
          fetch_fun.()
        end

      case result do
        {:ok, documents} ->
          {:ok, %{documents: documents, errors: []}}

        {:error, reason} ->
          {:ok,
           %{
             documents: [],
             errors: [%{collection_id: collection_id, reason: reason}]
           }}
      end
    end
  end

  @doc false
  @spec allowed_document?(map()) :: boolean()
  def allowed_document?(page), do: include_document?(page)

  @doc """
  Fetches a full document payload, including rendered blocks.
  """
  @spec get_document(Types.document_id(), opts()) ::
          {:ok, Types.DocumentDetail.t()} | {:error, term()}
  def get_document(document_id, opts \\ []) do
    with {:ok, token} <- fetch_token() do
      cache? = Keyword.get(opts, :cache?, true)
      ttl = Keyword.get(opts, :ttl, @default_ttl)
      cache_key = {:document_detail, document_id}

      fetch_fun = fn -> fetch_document_from_notion(token, document_id, opts) end

      result =
        if cache? do
          Cache.fetch(@cache_namespace, cache_key, fetch_fun, ttl: ttl)
        else
          fetch_fun.()
        end

      result
    end
  end

  defp collection_strategy do
    curated = curated_collections()

    cond do
      curated != [] ->
        {:curated, curated}

      auto_discover_enabled?() ->
        {:auto, auto_discover_options()}

      true ->
        {:curated, []}
    end
  end

  defp list_collections_with_token(token, opts) do
    case collection_strategy() do
      {:curated, metas} ->
        build_curated_collections(token, metas, opts)

      {:auto, auto_opts} ->
        fetch_discovered_collections(token, Keyword.merge(auto_opts, opts))
    end
  end

  defp build_curated_collections(token, metas, opts) do
    {collections_acc, errors_acc} =
      Enum.reduce(metas, {[], []}, fn meta, {acc, err_acc} ->
        case fetch_collection(meta, token, opts) do
          {:ok, collection} ->
            {[collection | acc], err_acc}

          {:error, reason} ->
            id = meta_value(meta, "id")
            {acc, [%{collection_id: id, reason: reason} | err_acc]}
        end
      end)

    collections = Enum.reverse(collections_acc)
    errors = Enum.reverse(errors_acc)

    if collections == [] and auto_discover_enabled?() do
      auto_opts = Keyword.merge(auto_discover_options(), opts)

      case fetch_discovered_collections(token, auto_opts) do
        {:ok, %{collections: auto_collections, errors: auto_errors}} ->
          combined_errors = merge_errors(errors, auto_errors, auto_collections)
          {:ok, %{collections: auto_collections, errors: combined_errors}}
      end
    else
      {:ok,
       %{
         collections: collections,
         errors: errors
       }}
    end
  end

  defp fetch_discovered_collections(token, opts) do
    case Keyword.get(opts, :mode, :databases) do
      :pages -> fetch_discovered_pages(token, opts)
      _ -> fetch_discovered_databases(token, opts)
    end
  end

  defp fetch_discovered_databases(token, opts) do
    include_ids =
      opts
      |> Keyword.get(:include_ids, [])
      |> Enum.map(&normalize_id/1)
      |> MapSet.new()

    exclude_ids =
      opts
      |> Keyword.get(:exclude_ids, [])
      |> Enum.map(&normalize_id/1)
      |> MapSet.new()

    page_size = clamp_page_size(Keyword.get(opts, :page_size, @auto_default_page_size))
    ttl = Keyword.get(opts, :ttl, @default_ttl)

    cache_key =
      {:auto_discovered, Enum.sort(MapSet.to_list(include_ids)),
       Enum.sort(MapSet.to_list(exclude_ids)), page_size}

    case Cache.fetch(
           @cache_namespace,
           cache_key,
           fn ->
             with {:ok, databases} <- paginate_databases(token, page_size) do
               now = DateTime.utc_now()

               collections =
                 databases
                 |> Enum.filter(&database_allowed?(&1, include_ids, exclude_ids))
                 |> Enum.map(&build_collection_from_database(&1, now))

               {:ok, collections}
             end
           end,
           ttl: ttl
         ) do
      {:ok, collections} ->
        {:ok, %{collections: collections, errors: []}}

      {:error, reason} ->
        {:ok, %{collections: [], errors: [%{reason: reason}]}}
    end
  end

  defp fetch_discovered_pages(token, opts) do
    {cache_key, include_ids, exclude_ids, page_size, ttl, collection_id, name, description} =
      auto_page_cache_inputs(opts)

    case Cache.fetch(
           @cache_namespace,
           cache_key,
           fn ->
             compute_page_collection(
               token,
               include_ids,
               exclude_ids,
               page_size,
               collection_id,
               name,
               description
             )
           end,
           ttl: ttl
         ) do
      {:ok, %{collection: collection, documents: documents}} ->
        Cache.put(@cache_namespace, {:documents, collection.id}, documents, ttl)
        {:ok, %{collections: [collection], errors: []}}

      {:error, reason} ->
        {:ok, %{collections: [], errors: [%{reason: reason}]}}
    end
  end

  defp fetch_documents_from_notion(token, collection_id, opts) do
    cond do
      page_collection?(collection_id) ->
        fetch_documents_from_pages(token, opts)

      true ->
        page_size = clamp_page_size(Keyword.get(opts, :page_size, @auto_default_page_size))

        case paginate_database_pages(token, collection_id, page_size) do
          {:ok, pages} ->
            now = DateTime.utc_now()

            documents =
              pages
              |> Enum.filter(&allowed_document?/1)
              |> Enum.map(&build_document_summary(&1, collection_id, now))
              |> Enum.sort_by(&(&1.last_updated_at || now), {:desc, DateTime})

            {:ok, documents}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp fetch_document_from_notion(token, document_id, opts) do
    block_page_size = clamp_page_size(Keyword.get(opts, :block_page_size, 100))

    with {:ok, page} <- notion_client().retrieve_page(token, document_id, []),
         {:ok, blocks} <- paginate_blocks(token, document_id, block_page_size) do
      now = DateTime.utc_now()
      collection_id = page_database_id(page)
      detail = build_document_detail(page, collection_id, blocks, now, token, block_page_size)
      {:ok, detail}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_documents_from_pages(token, opts) do
    {cache_key, include_ids, exclude_ids, page_size, ttl, collection_id, name, description} =
      auto_page_cache_inputs(opts)

    case Cache.fetch(
           @cache_namespace,
           cache_key,
           fn ->
             compute_page_collection(
               token,
               include_ids,
               exclude_ids,
               page_size,
               collection_id,
               name,
               description
             )
           end,
           ttl: ttl
         ) do
      {:ok, %{documents: documents}} ->
        Cache.put(@cache_namespace, {:documents, collection_id}, documents, ttl)
        {:ok, documents}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp merge_errors(curated_errors, auto_errors, auto_collections) do
    curated_errors =
      if auto_collections != [] do
        Enum.reject(curated_errors, fn
          %{reason: {:http_error, 404, _}} -> true
          %{collection_id: _id, reason: {:http_error, 404, _}} -> true
          _ -> false
        end)
      else
        curated_errors
      end

    curated_errors ++ auto_errors
  end

  defp auto_page_cache_inputs(opts) do
    include_ids =
      opts
      |> Keyword.get(:include_ids, allowed_database_ids())
      |> Enum.map(&normalize_id/1)
      |> MapSet.new()

    exclude_ids =
      opts
      |> Keyword.get(:exclude_ids, excluded_database_ids())
      |> Enum.map(&normalize_id/1)
      |> MapSet.new()

    page_size = clamp_page_size(Keyword.get(opts, :page_size, auto_discover_page_size()))
    ttl = Keyword.get(opts, :ttl, auto_discover_ttl())

    collection_id =
      opts
      |> Keyword.get(:page_collection_id, page_collection_id())
      |> normalize_collection_id()

    name = Keyword.get(opts, :page_collection_name, page_collection_name())

    description =
      opts
      |> Keyword.get(:page_collection_description, page_collection_description())

    cache_key =
      {:auto_discovered_pages, Enum.sort(MapSet.to_list(include_ids)),
       Enum.sort(MapSet.to_list(exclude_ids)), page_size, collection_id}

    {cache_key, include_ids, exclude_ids, page_size, ttl, collection_id, name, description}
  end

  defp compute_page_collection(
         token,
         include_ids,
         exclude_ids,
         page_size,
         collection_id,
         name,
         description
       ) do
    with {:ok, pages} <- paginate_pages(token, page_size) do
      now = DateTime.utc_now()

      documents =
        pages
        |> Enum.filter(&page_parent_allowed?/1)
        |> Enum.filter(&page_allowed_scope?(&1, include_ids, exclude_ids))
        |> Enum.filter(&allowed_document?/1)
        |> Enum.map(&build_document_summary(&1, collection_id, now))
        |> Enum.sort_by(&(&1.last_updated_at || now), {:desc, DateTime})

      most_recent =
        documents
        |> Enum.map(& &1.last_updated_at)
        |> Enum.reject(&is_nil/1)
        |> Enum.max_by(&DateTime.to_unix/1, fn -> nil end)

      collection =
        %Types.Collection{
          id: collection_id,
          name: name,
          description: description,
          icon: nil,
          document_count: length(documents),
          last_document_updated_at: most_recent,
          last_synced_at: now,
          metadata:
            %{}
            |> maybe_put_map(:source, @page_collection_source)
            |> maybe_put_map(:include_ids, sorted_mapset_values(include_ids))
            |> maybe_put_map(:exclude_ids, sorted_mapset_values(exclude_ids))
            |> maybe_put_map(:parent_filter, Enum.sort(MapSet.to_list(@page_parent_types)))
        }

      {:ok, %{collection: collection, documents: documents}}
    end
  end

  defp paginate_pages(token, page_size), do: paginate_pages(token, page_size, nil, [])

  defp paginate_pages(token, page_size, start_cursor, acc) do
    body =
      %{
        filter: %{property: "object", value: "page"},
        sort: %{direction: "descending", timestamp: "last_edited_time"},
        page_size: page_size
      }
      |> maybe_put_map(:start_cursor, start_cursor)

    case notion_client().search(token, "", body: body) do
      {:ok, response} ->
        results = Map.get(response, "results", [])
        has_more = Map.get(response, "has_more", false)
        next_cursor = Map.get(response, "next_cursor")
        new_acc = acc ++ results

        if has_more and is_binary(next_cursor) do
          paginate_pages(token, page_size, next_cursor, new_acc)
        else
          {:ok, new_acc}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp page_parent_allowed?(page) do
    case page_parent_type(page) do
      nil -> false
      type -> MapSet.member?(@page_parent_types, type)
    end
  end

  defp page_allowed_scope?(page, include_ids, exclude_ids) do
    page_id = page_id(page) |> normalize_id()
    parent_id = page_parent_identifier(page)

    exclude_target? =
      fn value ->
        value != nil and value != "" and MapSet.member?(exclude_ids, normalize_id(value))
      end

    include_match? =
      fn value ->
        value != nil and value != "" and MapSet.member?(include_ids, normalize_id(value))
      end

    cond do
      page_id == "" -> false
      exclude_target?.(page_id) -> false
      exclude_target?.(parent_id) -> false
      MapSet.size(include_ids) == 0 -> true
      include_match?.(page_id) -> true
      include_match?.(parent_id) -> true
      true -> false
    end
  end

  defp sorted_mapset_values(%MapSet{} = set) do
    set
    |> MapSet.to_list()
    |> Enum.map(&normalize_id/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.sort()
    |> case do
      [] -> nil
      values -> values
    end
  end

  defp sorted_mapset_values(_), do: nil

  defp page_parent_type(page) do
    parent = Map.get(page, "parent") || Map.get(page, :parent)

    cond do
      is_map(parent) -> Map.get(parent, "type") || Map.get(parent, :type)
      true -> nil
    end
  end

  defp page_parent_identifier(page) do
    parent = Map.get(page, "parent") || Map.get(page, :parent)

    case parent do
      %{"type" => "page_id", "page_id" => id} -> normalize_id(id)
      %{type: "page_id", page_id: id} -> normalize_id(id)
      %{"type" => "database_id", "database_id" => id} -> normalize_id(id)
      %{type: "database_id", database_id: id} -> normalize_id(id)
      %{"type" => "workspace"} -> "workspace"
      %{type: "workspace"} -> "workspace"
      _ -> nil
    end
  end

  defp auto_discover_page_size do
    kb_config()
    |> Keyword.get(:auto_discover_page_size, @auto_default_page_size)
  end

  defp auto_discover_ttl do
    kb_config()
    |> Keyword.get(:auto_discover_ttl, @default_ttl)
  end

  defp auto_discover_mode do
    kb_config()
    |> Keyword.get(:auto_discover_mode, :databases)
  end

  defp page_collection_id do
    kb_config()
    |> Keyword.get(:auto_page_collection_id, @default_page_collection_id)
    |> normalize_collection_id()
  end

  defp page_collection_name do
    kb_config()
    |> Keyword.get(:auto_page_collection_name, "Wiki Pages")
  end

  defp page_collection_description do
    kb_config()
    |> Keyword.get(:auto_page_collection_description, nil)
  end

  defp normalize_collection_id(id) do
    id
    |> normalize_id()
    |> case do
      "" -> @default_page_collection_id
      value -> value
    end
  end

  defp page_collection?(collection_id) do
    normalize_collection_id(collection_id) == page_collection_id()
  end

  defp fetch_collection(meta, token, opts) do
    id = meta_value(meta, "id")
    cache? = Keyword.get(opts, :cache?, true)
    ttl = Keyword.get(opts, :ttl, @default_ttl)

    fetch_fun = fn -> fetch_collection_from_notion(meta, token, opts) end

    if cache? do
      Cache.fetch(@cache_namespace, id, fetch_fun, ttl: ttl)
    else
      fetch_fun.()
    end
  end

  defp fetch_collection_from_notion(meta, token, opts) do
    client = notion_client()
    id = meta_value(meta, "id")
    page_size = Keyword.get(opts, :page_size, 100)

    query_opts = [
      page_size: page_size,
      sorts: [
        %{
          "timestamp" => "last_edited_time",
          "direction" => "descending"
        }
      ]
    ]

    case client.query_database(token, id, query_opts) do
      {:ok, body} ->
        {:ok, build_collection(meta, body)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp paginate_database_pages(token, database_id, page_size),
    do: paginate_database_pages(token, database_id, page_size, nil, [])

  defp paginate_database_pages(token, database_id, page_size, start_cursor, acc) do
    query_opts =
      [
        page_size: page_size,
        sorts: [
          %{
            "timestamp" => "last_edited_time",
            "direction" => "descending"
          }
        ]
      ]
      |> maybe_put_kw(:start_cursor, start_cursor)

    case notion_client().query_database(token, database_id, query_opts) do
      {:ok, body} ->
        results = Map.get(body, "results", [])
        has_more = Map.get(body, "has_more", false)
        next_cursor = Map.get(body, "next_cursor")
        new_acc = acc ++ results

        if has_more and is_binary(next_cursor) do
          paginate_database_pages(token, database_id, page_size, next_cursor, new_acc)
        else
          {:ok, new_acc}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp paginate_blocks(token, block_id, page_size),
    do: paginate_blocks(token, block_id, page_size, nil, [])

  defp paginate_blocks(token, block_id, page_size, start_cursor, acc) do
    opts =
      [page_size: page_size]
      |> maybe_put_kw(:start_cursor, start_cursor)

    case notion_client().retrieve_block_children(token, block_id, opts) do
      {:ok, body} ->
        results = Map.get(body, "results", [])
        has_more = Map.get(body, "has_more", false)
        next_cursor = Map.get(body, "next_cursor")
        new_acc = acc ++ results

        if has_more and is_binary(next_cursor) do
          paginate_blocks(token, block_id, page_size, next_cursor, new_acc)
        else
          {:ok, new_acc}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_document_summary(page, collection_id, synced_at) do
    page_collection_id = page_database_id(page) || collection_id

    %Types.DocumentSummary{
      id: normalize_id(page_id(page)),
      collection_id: normalize_id(page_collection_id),
      title: page_title(page),
      summary: page_summary(page),
      tags: page_tags(page),
      owner: page_owner(page),
      share_url: page_url(page),
      last_updated_at: parse_timestamp(Map.get(page, "last_edited_time")),
      synced_at: synced_at,
      metadata:
        %{}
        |> maybe_put_map(:created_time, Map.get(page, "created_time"))
        |> maybe_put_map(:last_edited_time, Map.get(page, "last_edited_time"))
    }
  end

  defp build_document_detail(page, collection_id, blocks, synced_at, token, block_page_size) do
    page_collection_id = page_database_id(page) || collection_id

    %Types.DocumentDetail{
      id: normalize_id(page_id(page)),
      collection_id: normalize_id(page_collection_id),
      title: page_title(page),
      summary: page_summary(page),
      owner: page_owner(page),
      share_url: page_url(page),
      last_updated_at: parse_timestamp(Map.get(page, "last_edited_time")),
      synced_at: synced_at,
      tags: page_tags(page),
      metadata:
        %{}
        |> maybe_put_map(:created_time, Map.get(page, "created_time"))
        |> maybe_put_map(:last_edited_time, Map.get(page, "last_edited_time")),
      rendered_blocks: normalize_blocks(token, blocks, block_page_size)
    }
  end

  defp normalize_blocks(token, blocks, page_size) do
    Enum.map(blocks, &normalize_block(token, &1, page_size))
  end

  defp normalize_block(token, block, page_size) do
    type = Map.get(block, "type")
    data = Map.get(block, type, %{})

    children =
      if Map.get(block, "has_children") do
        case paginate_blocks(token, Map.get(block, "id"), page_size) do
          {:ok, child_blocks} -> normalize_blocks(token, child_blocks, page_size)
          {:error, _} -> []
        end
      else
        []
      end

    base = %{
      id: Map.get(block, "id"),
      type: type |> to_string() |> String.to_atom(),
      children: children
    }

    case type do
      "paragraph" ->
        Map.put(base, :segments, segments_from_rich_text(Map.get(data, "rich_text", [])))

      "heading_1" ->
        base
        |> Map.put(:level, 1)
        |> Map.put(:segments, segments_from_rich_text(Map.get(data, "rich_text", [])))

      "heading_2" ->
        base
        |> Map.put(:level, 2)
        |> Map.put(:segments, segments_from_rich_text(Map.get(data, "rich_text", [])))

      "heading_3" ->
        base
        |> Map.put(:level, 3)
        |> Map.put(:segments, segments_from_rich_text(Map.get(data, "rich_text", [])))

      "bulleted_list_item" ->
        base
        |> Map.put(:style, :bullet)
        |> Map.put(:segments, segments_from_rich_text(Map.get(data, "rich_text", [])))

      "numbered_list_item" ->
        base
        |> Map.put(:style, :numbered)
        |> Map.put(:segments, segments_from_rich_text(Map.get(data, "rich_text", [])))

      "quote" ->
        base
        |> Map.put(:segments, segments_from_rich_text(Map.get(data, "rich_text", [])))

      "callout" ->
        base
        |> Map.put(:segments, segments_from_rich_text(Map.get(data, "rich_text", [])))
        |> Map.put(:icon, Map.get(data, "icon"))

      "code" ->
        segments = segments_from_rich_text(Map.get(data, "rich_text", []))
        plain_text = Enum.map_join(segments, "", &Map.get(&1, :text, ""))

        base
        |> Map.put(:segments, segments)
        |> Map.put(:language, Map.get(data, "language"))
        |> Map.put(:plain_text, plain_text)

      "divider" ->
        base

      "image" ->
        image_source =
          case Map.get(data, "type") do
            "external" -> get_in(data, ["external", "url"])
            "file" -> get_in(data, ["file", "url"])
            _ -> nil
          end

        base
        |> Map.put(:source, image_source)
        |> Map.put(:caption, segments_from_rich_text(Map.get(data, "caption", [])))

      "table" ->
        rows =
          children
          |> Enum.filter(&match?(%{type: :table_row}, &1))

        base
        |> Map.put(:children, [])
        |> Map.put(:rows, rows)
        |> Map.put(:has_column_header?, Map.get(data, "has_column_header", false))
        |> Map.put(:has_row_header?, Map.get(data, "has_row_header", false))
        |> Map.put(:table_width, Map.get(data, "table_width"))

      "table_row" ->
        cells =
          data
          |> Map.get("cells", [])
          |> Enum.map(&segments_from_rich_text/1)

        base
        |> Map.put(:cells, cells)
        |> Map.put(:children, [])

      _ ->
        Map.merge(base, %{type: :unsupported, raw_type: type})
    end
  end

  defp build_collection(meta, body) do
    now = DateTime.utc_now()
    results = Map.get(body, "results", [])

    document_count =
      case Map.get(body, "total") do
        total when is_integer(total) -> total
        _ -> Enum.count(results)
      end

    last_updated =
      results
      |> Enum.map(&parse_timestamp(&1["last_edited_time"]))
      |> Enum.reject(&is_nil/1)
      |> Enum.max_by(&DateTime.to_unix/1, fn -> nil end)

    %Types.Collection{
      id: meta_value(meta, "id"),
      name: meta_value(meta, "name") || meta_value(meta, :id),
      description: meta_value(meta, "description"),
      icon: meta_value(meta, "icon"),
      document_count: document_count,
      last_document_updated_at: last_updated,
      last_synced_at: now,
      metadata: collection_metadata(meta)
    }
  end

  defp parse_timestamp(nil), do: nil

  defp parse_timestamp(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _offset} -> dt
      _ -> nil
    end
  end

  defp parse_timestamp(_), do: nil

  defp curated_collections do
    config = kb_config()
    from_config = Keyword.get(config, :curated_collections, [])
    defaults = Keyword.get(config, :default_curated_database_ids, [])

    base =
      cond do
        from_config != [] ->
          from_config

        defaults != [] ->
          Enum.map(defaults, fn id ->
            normalized = normalize_id(id)
            %{"id" => normalized, "name" => normalized}
          end)

        true ->
          []
      end

    allowed_ids = allowed_database_ids() |> MapSet.new()
    excluded_ids = excluded_database_ids() |> MapSet.new()

    base
    |> Enum.map(&normalize_meta/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(fn meta ->
      id = meta_value(meta, "id") |> normalize_id()
      allow? = MapSet.size(allowed_ids) == 0 or MapSet.member?(allowed_ids, id)
      valid_id = id != ""
      allow? and valid_id and not MapSet.member?(excluded_ids, id)
    end)
  end

  defp kb_config do
    Application.get_env(:dashboard_ssd, DashboardSSD.KnowledgeBase, [])
  end

  defp auto_discover_enabled? do
    kb_config()
    |> Keyword.get(:auto_discover?, true)
  end

  defp auto_discover_options do
    [
      include_ids: allowed_database_ids(),
      exclude_ids: excluded_database_ids(),
      ttl: auto_discover_ttl(),
      page_size: auto_discover_page_size(),
      mode: auto_discover_mode(),
      page_collection_id: page_collection_id(),
      page_collection_name: page_collection_name(),
      page_collection_description: page_collection_description()
    ]
  end

  defp allowed_database_ids do
    Application.get_env(:dashboard_ssd, :integrations, [])
    |> Keyword.get(:notion_curated_database_ids, [])
    |> Enum.map(&normalize_id/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp excluded_database_ids do
    kb_config()
    |> Keyword.get(:exclude_database_ids, [])
    |> Enum.map(&normalize_id/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_meta(%{} = meta), do: meta

  defp normalize_meta(meta) when is_list(meta) do
    Enum.into(meta, %{})
  end

  defp normalize_meta(_), do: nil

  defp normalize_id(nil), do: ""

  defp normalize_id(id) when is_binary(id) do
    trimmed = String.trim(id)

    if Regex.match?(~r/^[0-9a-fA-F-]{32,}$/, trimmed) do
      trimmed
      |> String.replace("-", "")
      |> String.downcase()
    else
      String.downcase(trimmed)
    end
  end

  defp normalize_id(id) when is_atom(id), do: normalize_id(Atom.to_string(id))
  defp normalize_id(id), do: normalize_id(to_string(id))

  defp paginate_databases(token, page_size), do: paginate_databases(token, page_size, nil, [])

  defp paginate_databases(token, page_size, start_cursor, acc) do
    request_opts =
      [page_size: page_size]
      |> maybe_put_kw(:start_cursor, start_cursor)

    case notion_client().list_databases(token, request_opts) do
      {:ok, body} ->
        results = database_results(body)
        has_more = database_has_more(body)
        next_cursor = database_next_cursor(body)
        new_acc = acc ++ results

        if has_more and is_binary(next_cursor) do
          paginate_databases(token, page_size, next_cursor, new_acc)
        else
          {:ok, new_acc}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp database_allowed?(database, include_ids, exclude_ids) do
    id = database_id(database)

    cond do
      is_nil(id) or id == "" ->
        false

      MapSet.member?(exclude_ids, id) ->
        false

      MapSet.size(include_ids) == 0 ->
        true

      true ->
        MapSet.member?(include_ids, id)
    end
  end

  defp include_document?(page) do
    allowed_types = allowed_document_type_values()

    if MapSet.size(allowed_types) == 0 do
      true
    else
      page_types = page_type_values(page)

      cond do
        Enum.any?(page_types, &MapSet.member?(allowed_types, &1)) ->
          true

        page_types == [] ->
          allow_documents_without_type?()

        true ->
          false
      end
    end
  end

  defp allowed_document_type_values do
    kb_config()
    |> Keyword.get(:allowed_document_type_values, [])
    |> Enum.map(&normalize_type_value/1)
    |> Enum.reject(&(&1 == ""))
    |> MapSet.new()
  end

  defp document_type_property_names do
    kb_config()
    |> Keyword.get(:document_type_property_names, [])
    |> Enum.map(&normalize_property_key/1)
    |> Enum.reject(&(&1 == ""))
    |> MapSet.new()
  end

  defp allow_documents_without_type? do
    kb_config()
    |> Keyword.get(:allow_documents_without_type?, true)
  end

  defp page_type_values(page) do
    properties =
      page_properties(page)
      |> Enum.map(fn
        {key, value} when is_atom(key) -> {Atom.to_string(key), value}
        {key, value} -> {key, value}
      end)

    property_names = document_type_property_names()

    properties
    |> Enum.filter(fn {name, _property} ->
      MapSet.size(property_names) == 0 or
        MapSet.member?(property_names, normalize_property_key(name))
    end)
    |> Enum.flat_map(fn {_name, property} -> property_type_values(property) end)
    |> Enum.map(&normalize_type_value/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp property_type_values(property) when is_map(property) do
    type = Map.get(property, "type") || Map.get(property, :type)

    case type do
      "select" ->
        property
        |> select_property_value(["select", :select])
        |> select_option_names()

      "status" ->
        property
        |> select_property_value(["status", :status])
        |> status_option_name()

      "multi_select" ->
        property
        |> select_property_value(["multi_select", :multi_select])
        |> multi_select_option_names()

      _ ->
        []
    end
  end

  defp property_type_values(_), do: []

  defp select_option_names(%{"name" => name}) when is_binary(name), do: [name]
  defp select_option_names(%{name: name}) when is_binary(name), do: [name]
  defp select_option_names(_), do: []

  defp status_option_name(%{"name" => name}) when is_binary(name), do: [name]
  defp status_option_name(%{name: name}) when is_binary(name), do: [name]
  defp status_option_name(_), do: []

  defp multi_select_option_names(list) when is_list(list) do
    list
    |> Enum.map(&select_option_names/1)
    |> List.flatten()
  end

  defp multi_select_option_names(_), do: []

  defp select_property_value(property, keys) do
    Enum.find_value(keys, fn key -> Map.get(property, key) end)
  end

  defp normalize_type_value(nil), do: ""

  defp normalize_type_value(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.downcase()
  end

  defp normalize_type_value(value) when is_atom(value),
    do: value |> Atom.to_string() |> normalize_type_value()

  defp normalize_type_value(value) when is_number(value),
    do: value |> to_string() |> normalize_type_value()

  defp normalize_type_value(_), do: ""

  defp normalize_property_key(nil), do: ""

  defp normalize_property_key(key) when is_binary(key) do
    key
    |> String.trim()
    |> String.downcase()
  end

  defp normalize_property_key(key) when is_atom(key),
    do: key |> Atom.to_string() |> normalize_property_key()

  defp normalize_property_key(_), do: ""

  defp build_collection_from_database(database, synced_at) do
    id = database_id(database)

    %Types.Collection{
      id: id,
      name: default_collection_name(plain_text(database_title_raw(database)), id),
      description: plain_text(database_description_raw(database)),
      icon: database_icon_value(database_icon_raw(database)),
      document_count: nil,
      last_document_updated_at: parse_timestamp(database_last_edited_raw(database)),
      last_synced_at: synced_at,
      metadata:
        %{}
        |> maybe_put_map(:url, database_url(database))
        |> maybe_put_map(:created_time, database_created_time(database))
        |> maybe_put_map(:last_edited_time, database_last_edited_raw(database))
        |> maybe_put_map(:archived, database_archived(database))
        |> maybe_put_map(:parent, database_parent(database))
        |> maybe_put_map(:properties, database_properties(database))
    }
  end

  defp database_id(%{"id" => id}), do: normalize_id(id)
  defp database_id(%{id: id}), do: normalize_id(id)
  defp database_id(_), do: nil

  defp database_title_raw(%{"title" => title}) when is_list(title), do: title
  defp database_title_raw(%{title: title}) when is_list(title), do: title
  defp database_title_raw(_), do: []

  defp database_description_raw(%{"description" => description}) when is_list(description),
    do: description

  defp database_description_raw(%{description: description}) when is_list(description),
    do: description

  defp database_description_raw(_), do: []

  defp database_icon_raw(%{"icon" => icon}), do: icon
  defp database_icon_raw(%{icon: icon}), do: icon
  defp database_icon_raw(_), do: nil

  defp database_last_edited_raw(%{"last_edited_time" => ts}), do: ts
  defp database_last_edited_raw(%{last_edited_time: ts}), do: ts
  defp database_last_edited_raw(_), do: nil

  defp database_url(%{"url" => url}), do: url
  defp database_url(%{url: url}), do: url
  defp database_url(_), do: nil

  defp database_created_time(%{"created_time" => ts}), do: ts
  defp database_created_time(%{created_time: ts}), do: ts
  defp database_created_time(_), do: nil

  defp database_archived(%{"archived" => archived}), do: archived
  defp database_archived(%{archived: archived}), do: archived
  defp database_archived(_), do: nil

  defp database_parent(%{"parent" => parent}), do: parent
  defp database_parent(%{parent: parent}), do: parent
  defp database_parent(_), do: nil

  defp database_properties(%{"properties" => props}), do: props
  defp database_properties(%{properties: props}), do: props
  defp database_properties(_), do: nil

  defp database_icon_value(nil), do: nil
  defp database_icon_value(%{"emoji" => emoji}) when is_binary(emoji), do: emoji

  defp database_icon_value(%{"type" => "emoji", "emoji" => emoji}) when is_binary(emoji),
    do: emoji

  defp database_icon_value(%{"type" => "file", "file" => %{"url" => url}}) when is_binary(url),
    do: url

  defp database_icon_value(%{"type" => "external", "external" => %{"url" => url}})
       when is_binary(url),
       do: url

  defp database_icon_value(_), do: nil

  defp database_results(%{"results" => results}) when is_list(results), do: results
  defp database_results(%{results: results}) when is_list(results), do: results
  defp database_results(_), do: []

  defp database_has_more(%{"has_more" => has_more}) when is_boolean(has_more), do: has_more
  defp database_has_more(%{has_more: has_more}) when is_boolean(has_more), do: has_more
  defp database_has_more(_), do: false

  defp database_next_cursor(%{"next_cursor" => cursor}), do: cursor
  defp database_next_cursor(%{next_cursor: cursor}), do: cursor
  defp database_next_cursor(_), do: nil

  defp plain_text(list) when is_list(list) do
    list
    |> Enum.map_join(" ", fn
      %{"plain_text" => text} when is_binary(text) -> text
      %{plain_text: text} when is_binary(text) -> text
      _ -> ""
    end)
    |> String.trim()
    |> case do
      "" -> nil
      text -> text
    end
  end

  defp plain_text(_), do: nil

  defp default_collection_name(nil, id), do: id
  defp default_collection_name("", id), do: id
  defp default_collection_name(name, _id), do: name

  defp clamp_page_size(size) when is_integer(size) and size > 0 do
    min(size, 100)
  end

  defp clamp_page_size(_), do: @auto_default_page_size

  defp notion_client do
    Application.get_env(:dashboard_ssd, :notion_client, Notion)
  end

  defp segments_from_rich_text(rich_text) when is_list(rich_text) do
    Enum.map(rich_text, fn segment ->
      annotations = Map.get(segment, "annotations", %{})

      %{
        text: Map.get(segment, "plain_text") || Map.get(segment, :plain_text) || "",
        href: Map.get(segment, "href"),
        annotations: normalize_annotations(annotations),
        type: Map.get(segment, "type")
      }
    end)
  end

  defp segments_from_rich_text(_), do: []

  defp normalize_annotations(annotations) when is_map(annotations) do
    Enum.reduce(annotations, %{}, fn {key, value}, acc ->
      Map.put(acc, key |> to_string() |> String.to_atom(), value)
    end)
  end

  defp normalize_annotations(_), do: %{}

  defp page_id(%{"id" => id}), do: id
  defp page_id(%{id: id}), do: id
  defp page_id(_), do: nil

  defp page_url(%{"url" => url}), do: url
  defp page_url(%{url: url}), do: url
  defp page_url(_), do: nil

  defp page_properties(%{"properties" => props}) when is_map(props), do: props
  defp page_properties(%{properties: props}) when is_map(props), do: props
  defp page_properties(_), do: %{}

  defp page_title(page) do
    page_properties(page)
    |> Enum.find_value(fn {_name, property} ->
      case Map.get(property, "type") do
        "title" ->
          property
          |> Map.get("title", [])
          |> rich_text_plain()

        _ ->
          nil
      end
    end)
    |> case do
      nil -> "Untitled"
      "" -> "Untitled"
      title -> title
    end
  end

  defp page_summary(page) do
    candidates = [
      property_summary(page, "Summary"),
      property_summary(page, "Description"),
      first_rich_text_property(page)
    ]

    candidates
    |> Enum.find_value(&snippet/1)
  end

  defp property_summary(page, key) do
    page_properties(page)
    |> Map.get(key)
    |> case do
      %{"type" => "rich_text", "rich_text" => rich_text} -> rich_text_plain(rich_text)
      %{type: "rich_text", rich_text: rich_text} -> rich_text_plain(rich_text)
      _ -> nil
    end
  end

  defp first_rich_text_property(page) do
    page_properties(page)
    |> Enum.find_value(fn {_name, property} ->
      case Map.get(property, "type") do
        "rich_text" ->
          property
          |> Map.get("rich_text", [])
          |> rich_text_plain()

        _ ->
          nil
      end
    end)
  end

  defp rich_text_plain(rich_text) when is_list(rich_text) do
    rich_text
    |> Enum.map(fn
      %{"plain_text" => text} -> text
      %{plain_text: text} -> text
      _ -> ""
    end)
    |> Enum.join("")
    |> String.trim()
    |> case do
      "" -> nil
      text -> text
    end
  end

  defp rich_text_plain(_), do: nil

  defp snippet(nil), do: nil

  defp snippet(text) when is_binary(text) do
    trimmed = String.trim(text)

    case trimmed do
      "" ->
        nil

      content ->
        if String.length(content) > 200 do
          String.slice(content, 0, 197) <> "..."
        else
          content
        end
    end
  end

  defp page_tags(page) do
    page_properties(page)
    |> Enum.find_value(fn {_name, property} ->
      case Map.get(property, "type") do
        "multi_select" ->
          property
          |> Map.get("multi_select", [])
          |> Enum.map(&Map.get(&1, "name"))
          |> Enum.reject(&is_nil/1)

        _ ->
          nil
      end
    end)
    |> case do
      nil -> []
      tags -> tags
    end
  end

  defp page_owner(page) do
    case owner_from_properties(page_properties(page)) do
      nil ->
        page
        |> Map.get("last_edited_by")
        |> owner_from_user()
        |> case do
          nil -> "Unknown"
          owner -> owner
        end

      owner ->
        owner
    end
  end

  defp owner_from_properties(properties) do
    properties
    |> Enum.find_value(fn {_name, property} ->
      case Map.get(property, "type") do
        "people" ->
          property
          |> Map.get("people", [])
          |> Enum.map(&owner_from_user/1)
          |> Enum.reject(&is_nil/1)
          |> case do
            [] -> nil
            names -> Enum.join(names, ", ")
          end

        _ ->
          nil
      end
    end)
  end

  defp owner_from_user(%{"name" => name}) when is_binary(name) and name != "", do: name
  defp owner_from_user(%{name: name}) when is_binary(name) and name != "", do: name
  defp owner_from_user(_), do: nil

  defp page_database_id(%{"parent" => %{"type" => "database_id", "database_id" => id}}),
    do: normalize_id(id)

  defp page_database_id(%{parent: %{"type" => "database_id", "database_id" => id}}),
    do: normalize_id(id)

  defp page_database_id(_), do: nil

  defp maybe_put_map(map, _key, nil), do: map
  defp maybe_put_map(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_kw(list, _key, nil), do: list
  defp maybe_put_kw(list, key, value), do: Keyword.put(list, key, value)

  defp fetch_token do
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

  defp present?(value), do: not is_nil(value) and value != ""

  defp meta_value(meta, key) when is_map(meta) do
    Map.get(meta, key) || Map.get(meta, to_string(key)) || lookup_alternate_key(meta, key)
  end

  defp meta_value(meta, key) when is_list(meta) do
    meta
    |> Enum.into(%{})
    |> meta_value(key)
  end

  defp meta_value(_meta, _key), do: nil

  @spec lookup_alternate_key(map(), String.t() | atom()) :: term() | nil
  defp lookup_alternate_key(meta, key) when is_binary(key) do
    Enum.find_value(meta, fn
      {atom_key, value} when is_atom(atom_key) ->
        if Atom.to_string(atom_key) == key, do: value, else: nil

      _ ->
        nil
    end)
  end

  defp lookup_alternate_key(meta, key) when is_atom(key) do
    string_key = Atom.to_string(key)

    Enum.find_value(meta, fn
      {string_key_candidate, value} when is_binary(string_key_candidate) ->
        if string_key_candidate == string_key, do: value, else: nil

      _ ->
        nil
    end)
  end

  defp collection_metadata(meta) when is_map(meta) do
    meta
    |> Enum.into(%{})
    |> Map.drop(["id", "name", "description", "icon", :id, :name, :description, :icon])
  end

  defp collection_metadata(meta) when is_list(meta) do
    meta
    |> Enum.into(%{})
    |> collection_metadata()
  end

  defp collection_metadata(_), do: %{}
end
