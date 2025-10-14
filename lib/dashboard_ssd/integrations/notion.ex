defmodule DashboardSSD.Integrations.Notion do
  @moduledoc """
  Notion API client used by the Knowledge Base feature set.

  Provides convenience wrappers around Notion's search, database query, and block
  retrieval endpoints with retry and rudimentary circuit-breaker support to
  respect upstream rate limits.
  """

  @behaviour DashboardSSD.Integrations.Notion.Behaviour
  alias DashboardSSD.KnowledgeBase.Instrumentation
  use Tesla

  @base "https://api.notion.com"
  @version "2022-06-28"
  @default_retry_opts [
    max_attempts: 3,
    retry_statuses: [429, 500, 502, 503],
    base_backoff_ms: 200,
    max_backoff_ms: 1_500,
    circuit_cooldown_ms: 5_000
  ]
  @retry_keys Keyword.keys(@default_retry_opts) ++ [:sleep, :time_provider, :circuit_breaker_key]
  @circuit_namespace {:dashboard_ssd, :notion_circuit}
  @circuit_keys_key {:dashboard_ssd, :notion_circuit_keys}

  plug Tesla.Middleware.BaseUrl, @base

  plug Tesla.Middleware.Headers, [
    {"content-type", "application/json"},
    {"Notion-Version", @version}
  ]

  plug Tesla.Middleware.JSON

  @doc """
  Search Notion pages or databases with an optional set of overrides.

  Options:

    * `:body` - map payload appended to the default `%{query: term}` body.
    * Retry/circuit options (see module docs).
  """
  @spec search(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def search(token, query), do: search(token, query, [])

  @impl true
  @spec search(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def search(token, query, opts) do
    body = Map.merge(%{query: query}, Keyword.get(opts, :body, %{}))

    request_opts =
      opts
      |> Keyword.put(:body, body)
      |> Keyword.put_new(:circuit_breaker_key, :search)
      |> Keyword.put_new(:operation, :search)

    request_json(:post, "/v1/search", token, request_opts)
  end

  @impl true
  @doc """
  Query a curated Notion database by ID.

  Supported options:

    * `:filter` - map filter payload
    * `:sorts` - list of sort descriptors
    * `:page_size` - integer (max 100)
    * `:start_cursor` - pagination cursor
    * Retry/circuit options (see module docs)
  """
  @spec query_database(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def query_database(token, database_id, opts \\ []) do
    body =
      %{}
      |> maybe_put_map(:filter, Keyword.get(opts, :filter))
      |> maybe_put_map(:sorts, Keyword.get(opts, :sorts))
      |> maybe_put_map(:page_size, Keyword.get(opts, :page_size))
      |> maybe_put_map(:start_cursor, Keyword.get(opts, :start_cursor))

    request_opts =
      opts
      |> Keyword.put(:body, body)
      |> Keyword.put_new(:circuit_breaker_key, {:database_query, database_id})
      |> Keyword.put_new(:operation, :query_database)

    request_json(:post, "/v1/databases/#{database_id}/query", token, request_opts)
  end

  @impl true
  @doc """
  Retrieve block children for a Notion block/page.

  Options:

    * `:page_size` - integer (max 100)
    * `:start_cursor` - pagination cursor
    * Retry/circuit options (see module docs)
  """
  @spec retrieve_block_children(String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def retrieve_block_children(token, block_id, opts \\ []) do
    query =
      []
      |> maybe_put_kw(:page_size, Keyword.get(opts, :page_size))
      |> maybe_put_kw(:start_cursor, Keyword.get(opts, :start_cursor))

    request_opts =
      opts
      |> Keyword.put(:query, query)
      |> Keyword.put_new(:circuit_breaker_key, {:block_children, block_id})
      |> Keyword.put_new(:operation, :retrieve_block_children)

    request_json(:get, "/v1/blocks/#{block_id}/children", token, request_opts)
  end

  # -- Request helpers -------------------------------------------------------

  defp request_json(method, path, token, opts) do
    {retry_opts, http_opts_kw} = Keyword.split(opts, @retry_keys)
    retry_opts = normalize_retry_opts(path, retry_opts)

    {operation, http_opts_kw} =
      Keyword.pop(http_opts_kw, :operation, default_operation(method, path))

    http_opts = %{
      body: Keyword.get(http_opts_kw, :body),
      query: Keyword.get(http_opts_kw, :query, []),
      headers: Keyword.get(http_opts_kw, :headers, [])
    }

    with {:ok, env} <- request_with_retry(method, path, token, http_opts, retry_opts, operation) do
      {:ok, env.body}
    end
  end

  defp request_with_retry(method, path, token, http_opts, retry_opts, operation, attempt \\ 1) do
    key = Keyword.fetch!(retry_opts, :circuit_breaker_key)
    time_provider = Keyword.get(retry_opts, :time_provider, &System.monotonic_time/1)

    with :ok <- ensure_circuit_closed(key, time_provider) do
      metadata = build_metadata(method, path, attempt)

      result =
        Instrumentation.with_request_span(operation, metadata, fn ->
          execute_request(method, path, token, http_opts)
        end)

      handle_request_result(result,
        method: method,
        path: path,
        token: token,
        http_opts: http_opts,
        retry_opts: retry_opts,
        operation: operation,
        attempt: attempt,
        key: key,
        time_provider: time_provider
      )
    end
  end

  defp execute_request(:get, path, token, http_opts) do
    headers = authorized_headers(token, http_opts.headers)

    case get(path, headers: headers, query: http_opts.query) do
      {:ok, %Tesla.Env{status: status, body: body} = env} when status in 200..299 ->
        {:ok, %{env | body: body}}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp execute_request(:post, path, token, http_opts) do
    headers = authorized_headers(token, http_opts.headers)
    body = http_opts.body || %{}

    case post(path, body, headers: headers, query: http_opts.query) do
      {:ok, %Tesla.Env{status: status, body: body} = env} when status in 200..299 ->
        {:ok, %{env | body: body}}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp authorized_headers(token, extra) do
    [{"authorization", "Bearer #{token}"} | extra]
  end

  defp ensure_circuit_closed(key, time_provider) do
    now = current_time_ms(time_provider)

    case :persistent_term.get(circuit_key(key), :closed) do
      {:open, resume_at} when resume_at > now ->
        {:error, {:circuit_open, resume_at}}

      {:open, _expired} ->
        close_circuit(key)
        :ok

      _ ->
        :ok
    end
  rescue
    ArgumentError ->
      :ok
  end

  defp open_circuit(key, retry_opts, time_provider) do
    cooldown = Keyword.fetch!(retry_opts, :circuit_cooldown_ms)
    resume_at = current_time_ms(time_provider) + cooldown
    :persistent_term.put(circuit_key(key), {:open, resume_at})
    track_circuit_key(key)
  end

  defp close_circuit(key) do
    :persistent_term.put(circuit_key(key), :closed)
    track_circuit_key(key)
  end

  defp circuit_key(key), do: {@circuit_namespace, key}

  defp retry?(status, attempt, retry_opts) do
    statuses = Keyword.fetch!(retry_opts, :retry_statuses)
    max_attempts = Keyword.fetch!(retry_opts, :max_attempts)
    status in statuses and attempt < max_attempts
  end

  defp backoff_ms(attempt, retry_opts) do
    base = Keyword.fetch!(retry_opts, :base_backoff_ms)
    max = Keyword.fetch!(retry_opts, :max_backoff_ms)
    computed = trunc(base * :math.pow(2, attempt - 1))
    min(computed, max)
  end

  defp normalize_retry_opts(path, retry_opts) do
    retry_opts =
      retry_opts
      |> Keyword.put_new(:circuit_breaker_key, {:request, path})

    Keyword.merge(@default_retry_opts, retry_opts)
  end

  defp current_time_ms(fun) when is_function(fun, 1), do: fun.(:millisecond)
  defp current_time_ms(fun) when is_function(fun, 0), do: fun.()

  defp build_metadata(method, path, attempt) do
    %{method: method, path: path, attempt: attempt}
  end

  defp default_operation(_method, path) do
    cond do
      String.ends_with?(path, "/search") -> :search
      String.contains?(path, "/databases/") -> :query_database
      String.contains?(path, "/blocks/") -> :retrieve_block_children
      true -> :request
    end
  end

  defp maybe_put_map(map, _key, nil), do: map
  defp maybe_put_map(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_kw(list, _key, nil), do: list
  defp maybe_put_kw(list, key, value), do: Keyword.put(list, key, value)

  defp handle_request_result({:ok, env}, context) do
    close_circuit(context[:key])
    {:ok, env}
  end

  defp handle_request_result({:error, {:http_error, status, _} = error}, context) do
    retry_opts = context[:retry_opts]
    attempt = context[:attempt]

    if retry?(status, attempt, retry_opts) do
      backoff_ms = backoff_ms(attempt, retry_opts)
      sleep_fun = Keyword.get(retry_opts, :sleep, &Process.sleep/1)
      sleep_fun.(backoff_ms)

      request_with_retry(
        context[:method],
        context[:path],
        context[:token],
        context[:http_opts],
        retry_opts,
        context[:operation],
        attempt + 1
      )
    else
      if status in Keyword.get(retry_opts, :retry_statuses) do
        open_circuit(context[:key], retry_opts, context[:time_provider])
      end

      {:error, error}
    end
  end

  defp handle_request_result({:error, reason}, _context), do: {:error, reason}

  def reset_circuits do
    keys = :persistent_term.get(@circuit_keys_key, MapSet.new())

    Enum.each(keys, fn key ->
      :persistent_term.erase(circuit_key(key))
    end)

    :persistent_term.put(@circuit_keys_key, MapSet.new())
    :ok
  rescue
    ArgumentError -> :ok
  end

  defp track_circuit_key(key) do
    keys = :persistent_term.get(@circuit_keys_key, MapSet.new())
    :persistent_term.put(@circuit_keys_key, MapSet.put(keys, key))
  rescue
    ArgumentError -> :persistent_term.put(@circuit_keys_key, MapSet.new([key]))
  end
end
