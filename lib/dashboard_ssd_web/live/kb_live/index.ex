defmodule DashboardSSDWeb.KbLive.Index do
  @moduledoc "Knowledge base search powered by Notion."
  use DashboardSSDWeb, :live_view

  alias DashboardSSD.Auth.Policy
  alias DashboardSSD.Integrations

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if Policy.can?(user, :read, :kb) do
      {:ok,
       socket
       |> assign(:current_path, "/kb")
       |> assign(:page_title, "Knowledge Base")
       |> assign(:query, "")
       |> assign(:results, [])
       |> assign(:search_performed, false)
       |> assign(:mobile_menu_open, false)}
    else
      {:ok,
       socket
       |> assign(:current_path, "/kb")
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
    <div class="max-w-screen-2xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex flex-col gap-8">
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
                <div class="theme-card px-5 py-4 transition hover:border-white/20 hover:bg-white/5">
                  <div class="flex flex-wrap items-start gap-3">
                    <span :if={result.icon} class="text-2xl leading-none">{result.icon}</span>
                    <div class="flex flex-1 flex-col gap-1">
                      <a
                        href={result.url}
                        class="text-lg font-semibold text-white transition hover:text-theme-accent"
                        target="_blank"
                        rel="noopener"
                      >
                        {result.title}
                      </a>
                      <p
                        :if={result.last_edited}
                        class="text-xs uppercase tracking-[0.16em] text-theme-muted"
                      >
                        Last updated {result.last_edited}
                      </p>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% @search_performed -> %>
            <div class="theme-card px-6 py-8 text-center text-sm text-theme-muted">
              No Notion results matched your search.
            </div>
          <% true -> %>
            <div class="theme-card px-6 py-8 text-center text-sm text-theme-muted">
              Enter a keyword to search linked Notion documents.
            </div>
        <% end %>
      </div>
    </div>
    """
  end
end
