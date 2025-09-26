defmodule DashboardSSDWeb.KbLive.Index do
  @moduledoc "Knowledge base search powered by Notion."
  use DashboardSSDWeb, :live_view

  alias DashboardSSD.Integrations

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Knowledge Base")
     |> assign(:query, "")
     |> assign(:results, [])
     |> assign(:search_performed, false)}
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

  defp parse_results(results) when is_list(results) do
    Enum.map(results, fn result ->
      %{
        id: Map.get(result, "id"),
        title: extract_title(result),
        url: Map.get(result, "url"),
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center justify-between">
        <h1 class="text-xl font-semibold">{@page_title}</h1>
      </div>

      <form phx-submit="search" class="flex flex-col gap-3 md:flex-row md:items-center">
        <input
          type="search"
          name="query"
          value={@query}
          placeholder="Search the knowledge base"
          class="flex-1 rounded border border-zinc-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
        <button
          type="submit"
          class="rounded bg-zinc-900 px-4 py-2 text-sm font-medium text-white hover:bg-zinc-800"
        >
          Search
        </button>
      </form>

      <%= cond do %>
        <% @results != [] -> %>
          <div class="space-y-4">
            <%= for result <- @results do %>
              <div class="rounded border p-4 hover:border-zinc-400">
                <div class="flex items-center gap-2 text-lg font-semibold text-zinc-900">
                  <span :if={result.icon} class="text-xl">{result.icon}</span>
                  <a href={result.url} class="hover:underline" target="_blank" rel="noopener">
                    {result.title}
                  </a>
                </div>
                <p :if={result.last_edited} class="mt-1 text-sm text-zinc-600">
                  Last updated: {result.last_edited}
                </p>
              </div>
            <% end %>
          </div>
        <% @search_performed -> %>
          <p class="text-center text-zinc-600">No Notion results matched your search.</p>
        <% true -> %>
          <p class="text-center text-zinc-600">
            Enter a keyword to search linked Notion documents.
          </p>
      <% end %>
    </div>
    """
  end
end
