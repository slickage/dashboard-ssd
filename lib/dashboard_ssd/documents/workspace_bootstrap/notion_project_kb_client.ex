defmodule DashboardSSD.Documents.WorkspaceBootstrap.NotionProjectKBClient do
  @moduledoc """
  Workspace bootstrap adapter that mirrors Drive templates into a Notion hierarchy.

  The hierarchy is:

      Projects KB (database) -> Client page -> Project page -> Project KB page

  Content is rendered from our Markdown templates into a handful of Notion blocks.
  """
  @behaviour DashboardSSD.Documents.WorkspaceBootstrap.NotionClient

  alias DashboardSSD.Clients.Client
  alias DashboardSSD.Projects.Project
  require Logger

  @impl true
  def upsert_page(%Project{client: %Client{name: client_name}} = project, section, template, opts) do
    with {:ok, token} <- notion_token(opts),
         {:ok, root_database_id} <- root_database_id(opts),
         {:ok, _db} <- notion(opts).retrieve_database(token, root_database_id, []),
         {:ok, client_page} <-
           ensure_client_entry(token, root_database_id, client_name, opts),
         {:ok, project_page} <-
           ensure_child_page(token, client_page["id"], project.name, opts),
         {:ok, doc_page} <-
           ensure_child_page(token, project_page["id"], doc_page_title(project), opts),
         :ok <- replace_doc_content(token, doc_page["id"], template, opts) do
      {:ok, doc_page}
    else
      {:error, reason} = error ->
        Logger.error(
          "Notion bootstrap failed for project=#{project.id} section=#{section.id} reason=#{inspect(reason)}"
        )

        error
    end
  end

  def upsert_page(%Project{}, _section, _template, _opts), do: {:error, :project_client_missing}

  defp notion(opts) do
    Keyword.get(opts, :notion_client) ||
      Application.get_env(:dashboard_ssd, :notion_client, DashboardSSD.Integrations.Notion)
  end

  defp ensure_client_entry(token, database_id, client_name, opts) do
    case notion(opts).query_database(token, database_id,
           filter: %{
             property: "Name",
             title: %{equals: client_name}
           }
         ) do
      {:ok, %{"results" => [page | _]}} ->
        {:ok, page}

      {:ok, %{"results" => []}} ->
        create_page(token, %{database_id: database_id}, client_name, opts)

      other ->
        other
    end
  end

  defp ensure_child_page(token, parent_id, title, opts) do
    case find_child_page(token, parent_id, title, opts) do
      {:ok, %{"id" => _} = page} ->
        {:ok, page}

      {:not_found, _} ->
        create_page(token, %{page_id: parent_id}, title, opts)

      error ->
        error
    end
  end

  defp find_child_page(token, parent_id, title, opts) do
    with {:ok, blocks} <- list_child_pages(token, parent_id, [], opts),
         %{"id" => id} = page when not is_nil(id) <-
           Enum.find(blocks, fn
             %{"type" => "child_page", "child_page" => %{"title" => ^title}} -> true
             _ -> false
           end) do
      {:ok, page}
    else
      nil -> {:not_found, :child_page_missing}
      {:error, _} = error -> error
    end
  end

  defp list_child_pages(token, parent_id, acc, opts) do
    case notion(opts).retrieve_block_children(token, parent_id, []) do
      {:ok, %{"results" => results, "has_more" => true, "next_cursor" => cursor}} ->
        list_child_pages(token, parent_id, acc ++ results, opts, cursor)

      {:ok, %{"results" => results}} ->
        {:ok, acc ++ results}

      other ->
        other
    end
  end

  defp list_child_pages(token, parent_id, acc, opts, cursor) do
    case notion(opts).retrieve_block_children(token, parent_id, start_cursor: cursor) do
      {:ok, %{"results" => results, "has_more" => true, "next_cursor" => next_cursor}} ->
        list_child_pages(token, parent_id, acc ++ results, opts, next_cursor)

      {:ok, %{"results" => results}} ->
        {:ok, acc ++ results}

      other ->
        other
    end
  end

  defp create_page(token, parent, title, opts) do
    attrs = %{
      parent: parent,
      properties: %{
        "Name" => %{
          "title" => [
            %{
              "text" => %{"content" => title}
            }
          ]
        }
      }
    }

    notion(opts).create_page(token, attrs, opts)
  end

  defp replace_doc_content(token, page_id, template, opts) do
    with {:ok, blocks} <- list_blocks(token, page_id, opts),
         :ok <- delete_blocks(token, blocks, opts),
         {:ok, _} <-
           notion(opts).append_block_children(
             token,
             page_id,
             markdown_to_blocks(template),
             opts
           ) do
      :ok
    end
  end

  defp list_blocks(token, page_id, opts) do
    case notion(opts).retrieve_block_children(token, page_id, opts) do
      {:ok, %{"results" => results, "has_more" => true, "next_cursor" => cursor}} ->
        collect_blocks(token, page_id, results, cursor, opts)

      {:ok, %{"results" => results}} ->
        {:ok, results}

      other ->
        other
    end
  end

  defp collect_blocks(token, page_id, acc, cursor, opts) do
    case notion(opts).retrieve_block_children(token, page_id, start_cursor: cursor) do
      {:ok, %{"results" => results, "has_more" => true, "next_cursor" => next_cursor}} ->
        collect_blocks(token, page_id, acc ++ results, next_cursor, opts)

      {:ok, %{"results" => results}} ->
        {:ok, acc ++ results}

      other ->
        other
    end
  end

  defp delete_blocks(_token, [], _opts), do: :ok

  defp delete_blocks(token, blocks, opts) do
    blocks
    |> Enum.map(&Map.get(&1, "id"))
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce_while(:ok, fn id, :ok ->
      case notion(opts).delete_block(token, id, opts) do
        {:ok, _} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp markdown_to_blocks(nil), do: [paragraph_block(" ")]

  defp markdown_to_blocks(content) when is_list(content),
    do: markdown_to_blocks(List.to_string(content))

  defp markdown_to_blocks(content) when is_binary(content) do
    content
    |> String.split(~r/\r?\n/, trim: false)
    |> Enum.reduce({[], []}, &accumulate_line/2)
    |> finalize_paragraphs()
    |> case do
      [] -> [paragraph_block(String.trim(content))]
      blocks -> blocks
    end
  end

  defp accumulate_line("", {blocks, current}), do: {append_paragraph(blocks, current), []}

  defp accumulate_line(line, {blocks, current}) do
    cond do
      String.starts_with?(line, "### ") ->
        {append_paragraph(blocks, current) ++
           [heading_block(3, String.trim_leading(line, "### "))], []}

      String.starts_with?(line, "## ") ->
        {append_paragraph(blocks, current) ++
           [heading_block(2, String.trim_leading(line, "## "))], []}

      String.starts_with?(line, "# ") ->
        {append_paragraph(blocks, current) ++ [heading_block(1, String.trim_leading(line, "# "))],
         []}

      String.starts_with?(line, "- ") ->
        text = line |> String.trim_leading("- ") |> String.trim()

        {append_paragraph(blocks, current) ++ [bullet_block(text)], []}

      String.starts_with?(line, "> ") ->
        quote =
          line
          |> String.trim_leading("> ")
          |> String.trim()

        {append_paragraph(blocks, current) ++ [quote_block(quote)], []}

      true ->
        {blocks, current ++ [String.trim_trailing(line)]}
    end
  end

  defp finalize_paragraphs({blocks, current}) do
    append_paragraph(blocks, current)
  end

  defp append_paragraph(blocks, []), do: blocks

  defp append_paragraph(blocks, lines) do
    text =
      lines
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n")
      |> String.trim()

    if text == "" do
      blocks
    else
      blocks ++ [paragraph_block(text)]
    end
  end

  defp paragraph_block(text) do
    %{
      "object" => "block",
      "type" => "paragraph",
      "paragraph" => %{
        "rich_text" => [rich_text(text)]
      }
    }
  end

  defp heading_block(level, text) when level in 1..3 do
    type = "heading_#{level}"

    %{
      "object" => "block",
      "type" => type,
      type => %{"rich_text" => [rich_text(text)]}
    }
  end

  defp bullet_block(text) do
    %{
      "object" => "block",
      "type" => "bulleted_list_item",
      "bulleted_list_item" => %{
        "rich_text" => [rich_text(text)]
      }
    }
  end

  defp quote_block(text) do
    %{
      "object" => "block",
      "type" => "quote",
      "quote" => %{"rich_text" => [rich_text(text)]}
    }
  end

  defp rich_text(text) do
    %{
      "type" => "text",
      "text" => %{"content" => String.slice(text, 0, 2000)},
      "plain_text" => String.slice(text, 0, 2000),
      "annotations" => %{
        "bold" => false,
        "italic" => false,
        "strikethrough" => false,
        "underline" => false,
        "code" => false,
        "color" => "default"
      }
    }
  end

  defp doc_page_title(%Project{name: name}), do: "#{name} Knowledge Base"

  defp notion_token(opts) do
    integrations_config = Application.get_env(:dashboard_ssd, :integrations, [])

    token =
      cond do
        present?(opts[:notion_token]) ->
          opts[:notion_token]

        present?(config_token(shared_notion_config())) ->
          config_token(shared_notion_config())

        present?(Keyword.get(integrations_config, :notion_token)) ->
          Keyword.get(integrations_config, :notion_token)

        present?(System.get_env("NOTION_TOKEN")) ->
          System.get_env("NOTION_TOKEN")

        present?(System.get_env("NOTION_API_KEY")) ->
          System.get_env("NOTION_API_KEY")

        true ->
          nil
      end

    if present?(token), do: {:ok, token}, else: {:error, {:missing_env, "NOTION_TOKEN"}}
  end

  defp present?(value), do: is_binary(value) and String.trim(value) != ""

  defp root_database_id(opts) do
    env_id = opts[:projects_kb_parent_id] || System.get_env("NOTION_PROJECTS_KB_PARENT_ID")
    shared_config = shared_notion_config()
    parent_id = config_parent_id(shared_config)

    cond do
      present?(env_id) ->
        {:ok, env_id}

      present?(parent_id) ->
        {:ok, parent_id}

      true ->
        {:error, :missing_projects_kb_parent_id}
    end
  end

  defp shared_notion_config do
    case Application.get_env(:dashboard_ssd, :shared_documents_integrations) do
      %{notion: config} -> config
      list when is_list(list) -> Keyword.get(list, :notion)
      _ -> nil
    end
  end

  defp config_token(config) when is_list(config), do: Keyword.get(config, :token)
  defp config_token(%{} = config), do: Map.get(config, :token)
  defp config_token(_), do: nil

  defp config_parent_id(config) when is_list(config),
    do: Keyword.get(config, :projects_kb_parent_id)

  defp config_parent_id(%{} = config), do: Map.get(config, :projects_kb_parent_id)
  defp config_parent_id(_), do: nil
end
