#!/usr/bin/env elixir

# Minimal script to list databases visible to a Notion integration token.
# Usage:
#   NOTION_TOKEN=... mix run scripts/notion_list_databases.exs
#   # or
#   NOTION_API_KEY=... mix run scripts/notion_list_databases.exs

token =
  System.get_env("NOTION_TOKEN") ||
    System.get_env("NOTION_API_KEY") ||
    raise "Set NOTION_TOKEN or NOTION_API_KEY before running this script"

{:ok, _} = Application.ensure_all_started(:ssl)
{:ok, _} = Application.ensure_all_started(:inets)
{:ok, _} = Application.ensure_all_started(:jason)

defmodule NotionBare do
  @api "https://api.notion.com/v1/search"
  @version "2022-06-28"

  def list_databases(token) do
    do_list(token, nil, [])
  end

  defp do_list(token, cursor, acc) do
    payload =
      %{
        filter: %{property: "object", value: "database"},
        page_size: 100
      }
      |> maybe_put(:start_cursor, cursor)

    case request(token, payload) do
      {:ok, %{"results" => results, "has_more" => true, "next_cursor" => next}} ->
        do_list(token, next, acc ++ results)

      {:ok, %{"results" => results}} ->
        {:ok, acc ++ results}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp request(token, body) do
    url = String.to_charlist(@api)
    payload = Jason.encode!(body)

    headers =
      [
        {"content-type", "application/json"},
        {"authorization", "Bearer #{token}"},
        {"Notion-Version", @version}
      ]
      |> Enum.map(fn {key, value} -> {String.to_charlist(key), String.to_charlist(value)} end)

    request = {url, headers, ~c"application/json", payload}

    case :httpc.request(:post, request, [], []) do
      {:ok, {{_, status, _}, _resp_headers, resp_body}} ->
        if status in 200..299 do
          case Jason.decode(resp_body) do
            {:ok, decoded} -> {:ok, decoded}
            {:error, _} -> {:error, %{status: status, body: resp_body}}
          end
        else
          {:error, %{status: status, body: parse_error(resp_body)}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp parse_error(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> decoded
      _ -> body
    end
  end
end

case NotionBare.list_databases(token) do
  {:ok, databases} ->
    IO.puts("Database count: #{length(databases)}")

    Enum.each(databases, fn db ->
      id = Map.get(db, "id")

      title =
        db
        |> Map.get("title", [])
        |> Enum.map(&Map.get(&1, "plain_text", ""))
        |> Enum.join("")
        |> case do
          "" -> id
          value -> value
        end

      url = Map.get(db, "url")
      IO.puts("* #{title} (#{id})")
      if url, do: IO.puts("  #{url}")
    end)

  {:error, reason} ->
    IO.puts("Failed to list databases:")
    IO.inspect(reason)
end
