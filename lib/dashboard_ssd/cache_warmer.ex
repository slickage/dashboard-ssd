defmodule DashboardSSD.CacheWarmer do
  @moduledoc """
  Shared cache warmer that preloads knowledge base collections and Linear
  summaries so first page loads avoid slow external calls.

  The warmer fetches curated collections/documents into
  `DashboardSSD.KnowledgeBase.CacheStore` and primes Linear summaries via the
  projects context. It runs on a configurable interval and skips work in the
  test environment.

    - Boots a GenServer responsible for recurring warm-up passes.
  - Sequentially hydrates knowledge-base collections, workflow states, and Linear summaries.
  - Emits lightweight timing logs so operators can monitor warm-up performance.
  """
  use GenServer

  require Logger

  alias DashboardSSD.KnowledgeBase.Catalog
  alias DashboardSSD.Projects

  @name __MODULE__
  @default_initial_delay 0
  @default_interval :timer.minutes(5)

  @doc false
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    state = %{
      catalog: Keyword.get(opts, :catalog, Catalog),
      projects: Keyword.get(opts, :projects, Projects),
      notify: Keyword.get(opts, :notify),
      interval: Keyword.get(opts, :interval, @default_interval)
    }

    initial_delay = Keyword.get(opts, :initial_delay, @default_initial_delay)

    state =
      state
      |> Map.put(:last_phase, nil)
      |> Map.put(:next_phase, :scheduled)

    if initial_delay <= 0 do
      {:ok, %{state | next_phase: :initial}, {:continue, :warm_immediate}}
    else
      schedule_warm(initial_delay)
      {:ok, state}
    end
  end

  @impl true
  def handle_info(:warm, %{interval: interval} = state) do
    warm_cache_with_metrics(state, :scheduled)
    schedule_warm(interval)
    {:noreply, state}
  end

  @impl true
  def handle_continue(:warm_immediate, %{interval: interval, next_phase: phase} = state) do
    warm_cache_with_metrics(state, phase || :initial)
    schedule_warm(interval)
    {:noreply, %{state | next_phase: :scheduled}}
  end

  defp schedule_warm(delay) when delay <= 0, do: send(self(), :warm)
  defp schedule_warm(delay), do: Process.send_after(self(), :warm, delay)

  defp warm_cache_with_metrics(state, phase) do
    started = System.monotonic_time(:millisecond)

    try do
      warm_cache(state)
    after
      elapsed = System.monotonic_time(:millisecond) - started
      Logger.info("Warm cycle (#{phase}) finished in #{elapsed}ms")
    end
  end

  defp warm_cache(state) do
    time_phase(:collections, fn -> warm_collections(state) end)
    time_phase(:workflow_states, fn -> warm_workflow_states(state) end)
    time_phase(:linear_summaries, fn -> warm_linear_summaries(state) end)
  end

  defp time_phase(label, fun) when is_function(fun, 0) do
    started = System.monotonic_time(:millisecond)

    try do
      fun.()
    after
      elapsed = System.monotonic_time(:millisecond) - started
      Logger.info("Warm #{label} completed in #{elapsed}ms")
    end
  end

  defp warm_collections(%{catalog: catalog} = state) do
    catalog
    |> list_collections()
    |> handle_collections_result(state)
  rescue
    exception ->
      Logger.debug(
        "Knowledge base cache warming failed: " <>
          Exception.format(:error, exception, __STACKTRACE__)
      )
  end

  defp warm_workflow_states(%{projects: projects}) do
    team_ids =
      projects.unique_linear_team_ids()
      |> Enum.filter(&is_binary/1)
      |> Enum.reject(&(&1 == ""))

    if team_ids != [] do
      _ = projects.workflow_state_metadata_multi(team_ids)
    end
  rescue
    exception ->
      Logger.debug(
        "Workflow state cache warming failed: " <>
          Exception.format(:error, exception, __STACKTRACE__)
      )
  end

  defp warm_linear_summaries(%{projects: projects}) do
    case safe_sync_projects(projects) do
      {:ok, _info} ->
        :ok

      {:error, {:rate_limited, message}} ->
        Logger.debug("Skipping Linear summary warm (rate limited): #{message}")

      {:error, reason} ->
        Logger.debug("Linear summary warm skipped: #{inspect(reason)}")
    end
  end

  defp safe_sync_projects(projects) do
    projects.sync_from_linear()
  rescue
    exception ->
      Logger.debug(
        "Linear summary warm failed: " <> Exception.format(:error, exception, __STACKTRACE__)
      )

      {:error, exception}
  end

  defp notify(%{notify: nil}, _message), do: :ok
  defp notify(%{notify: pid}, message) when is_pid(pid), do: send(pid, {:cache_warmer, message})

  defp list_collections(catalog), do: catalog.list_collections(cache?: true)

  defp handle_collections_result({:ok, %{collections: collections}}, state) do
    {_first_document_id, detail_task} =
      warm_collection_details(state, state.catalog, collections)

    maybe_wait_for_initial_document(detail_task)
    notify(state, {:warmed, Enum.map(collections, & &1.id)})
  end

  defp handle_collections_result({:error, reason}, _state) do
    Logger.debug("Knowledge base cache warming skipped (collections): #{inspect(reason)}")
  end

  defp warm_collection_details(state, catalog, collections) do
    Enum.reduce(collections, {nil, nil}, fn collection, {current, task} ->
      accumulate_collection(state, catalog, collection, current, task)
    end)
  end

  defp accumulate_collection(state, catalog, collection, current, task) do
    candidate = warm_collection_documents(catalog, collection)

    cond do
      current != nil ->
        {current, task}

      candidate != nil ->
        new_task = Task.async(fn -> warm_initial_document(state, candidate) end)
        {candidate, new_task}

      true ->
        {nil, task}
    end
  end

  defp warm_collection_documents(_catalog, %{id: nil}), do: nil

  defp warm_collection_documents(catalog, collection) do
    collection_id = collection_id(collection)

    if collection_id do
      list_collection_documents(catalog, collection_id)
    else
      nil
    end
  end

  defp maybe_wait_for_initial_document(nil), do: :ok
  defp maybe_wait_for_initial_document(task), do: await_warm_initial_document(task)

  defp list_collection_documents(catalog, collection_id) do
    case catalog.list_documents(collection_id, cache?: true) do
      {:ok, %{documents: documents}} ->
        find_first_document_id(documents)

      {:error, reason} ->
        Logger.debug(
          "Knowledge base cache warming skipped documents for #{collection_id}: #{inspect(reason)}"
        )

        nil
    end
  rescue
    exception ->
      Logger.debug(
        "Knowledge base cache warming failed for collection #{collection_id}: " <>
          Exception.format(:error, exception, __STACKTRACE__)
      )

      nil
  end

  defp warm_initial_document(_state, nil), do: :ok

  defp warm_initial_document(%{catalog: catalog}, document_id) do
    case catalog.get_document(document_id, cache?: true) do
      {:ok, _detail} ->
        :ok

      {:error, reason} ->
        Logger.debug(
          "Knowledge base cache warming skipped document #{document_id}: #{inspect(reason)}"
        )
    end
  rescue
    exception ->
      Logger.debug(
        "Knowledge base cache warming failed to fetch document #{document_id}: " <>
          Exception.format(:error, exception, __STACKTRACE__)
      )

      :ok
  end

  defp find_first_document_id(documents) do
    Enum.find_value(documents, fn document ->
      document_id(document)
    end)
  end

  defp document_id(document) when is_map(document) do
    cond do
      Map.has_key?(document, :id) -> normalize_id(Map.get(document, :id))
      Map.has_key?(document, "id") -> normalize_id(Map.get(document, "id"))
      true -> nil
    end
  end

  defp document_id(_), do: nil

  defp collection_id(collection) when is_map(collection) do
    cond do
      Map.has_key?(collection, :id) -> normalize_id(Map.get(collection, :id))
      Map.has_key?(collection, "id") -> normalize_id(Map.get(collection, "id"))
      true -> nil
    end
  end

  defp collection_id(_), do: nil

  defp normalize_id(id) when is_binary(id) do
    trimmed = String.trim(id)
    if trimmed == "", do: nil, else: trimmed
  end

  defp normalize_id(id) when is_integer(id), do: Integer.to_string(id)
  defp normalize_id(id) when is_atom(id), do: Atom.to_string(id)
  defp normalize_id(_), do: nil

  defp await_warm_initial_document(task) do
    Task.await(task, 30_000)
  catch
    :exit, reason ->
      Logger.debug("Knowledge base document warm task exited: #{inspect(reason)}")
      :ok
  end
end
