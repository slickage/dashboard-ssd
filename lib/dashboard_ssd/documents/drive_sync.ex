defmodule DashboardSSD.Documents.DriveSync do
  @moduledoc """
  Upserts Drive-sourced shared documents and emits telemetry for sync health.
  """
  import Ecto.Query
  alias DashboardSSD.Cache.SharedDocumentsCache
  alias DashboardSSD.Documents.SharedDocument
  alias DashboardSSD.Repo
  require Logger

  @event [:dashboard_ssd, :documents, :drive_sync, :result]

  @doc """
  Syncs the provided Drive documents into `shared_documents`. Removes any prior
  Drive docs for the same project that are no longer present in `remote_docs`
  when `:prune_missing?` is true (default: false).

  Each entry should be a map containing at minimum `:client_id`, `:project_id`,
  `:source_id`, `:title`, and `:doc_type`. Optional keys (visibility, metadata,
  mime_type, etc.) are forwarded to the schema changeset. When a document with the
  same `{source, source_id}` exists it is updated instead of inserted.
  """
  @spec sync([map()], keyword()) ::
          {:ok,
           %{inserted: non_neg_integer(), updated: non_neg_integer(), deleted: non_neg_integer()}}
          | {:error, term()}
  def sync(remote_docs, opts \\ []) when is_list(remote_docs) do
    prune_missing? = Keyword.get(opts, :prune_missing?, false)
    project_ids_opt = Keyword.get(opts, :project_ids)
    start_time = System.monotonic_time()

    result =
      Enum.reduce_while(
        remote_docs,
        {:ok, %{inserted: 0, updated: 0, seen_ids: MapSet.new()}},
        fn attrs, {:ok, acc} ->
          attrs = Map.merge(%{source: :drive, visibility: :client, metadata: %{}}, attrs)

          case upsert(attrs) do
            {:ok, :inserted} ->
              {:cont,
               {:ok,
                %{
                  acc
                  | inserted: acc.inserted + 1,
                    seen_ids: MapSet.put(acc.seen_ids, attrs.source_id)
                }}}

            {:ok, :updated} ->
              {:cont,
               {:ok,
                %{
                  acc
                  | updated: acc.updated + 1,
                    seen_ids: MapSet.put(acc.seen_ids, attrs.source_id)
                }}}

            {:error, reason} ->
              {:halt, {:error, reason}}
          end
        end
      )

    case result do
      {:ok, counts} ->
        deleted =
          if prune_missing? do
            prune_missing_drive_docs(project_ids_opt || remote_docs, counts.seen_ids)
          else
            0
          end

        SharedDocumentsCache.invalidate_listing(:all)
        SharedDocumentsCache.invalidate_download(:all)
        emit(:ok, counts, remote_docs, start_time, %{deleted: deleted})
        {:ok, Map.put(counts, :deleted, deleted)}

      {:error, reason} ->
        emit(
          :error,
          %{inserted: 0, updated: 0, deleted: 0},
          remote_docs,
          start_time,
          %{reason: inspect(reason)}
        )

        {:error, reason}
    end
  end

  defp prune_missing_drive_docs(remote_docs_or_ids, seen_ids) do
    remote_docs_or_ids
    |> project_ids_for_pruning()
    |> Enum.reduce(0, fn project_id, acc ->
      acc + delete_missing_drive_docs_for_project(project_id, seen_ids)
    end)
  end

  defp delete_missing_drive_docs_for_project(project_id, seen_ids) do
    Repo.all(
      from(sd in SharedDocument,
        where: sd.source == :drive and sd.project_id == ^project_id
      )
    )
    |> Enum.reduce(0, fn doc, count ->
      if MapSet.member?(seen_ids, doc.source_id) do
        count
      else
        Repo.delete!(doc)
        count + 1
      end
    end)
  end

  defp project_ids_for_pruning(ids) when is_list(ids) do
    if Enum.all?(ids, &is_integer/1) do
      ids
    else
      ids
      |> Enum.map(&Map.get(&1, :project_id))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
    end
  end

  defp project_ids_for_pruning(_), do: []

  defp upsert(attrs) do
    changeset = SharedDocument.changeset(%SharedDocument{}, attrs)

    case Repo.insert(changeset) do
      {:ok, _doc} -> {:ok, :inserted}
      {:error, changeset} -> handle_insert_error(attrs, changeset)
    end
  end

  defp handle_insert_error(attrs, changeset) do
    if conflict_on_source?(changeset) do
      existing = Repo.get_by!(SharedDocument, source: attrs.source, source_id: attrs.source_id)

      case Repo.update(SharedDocument.changeset(existing, attrs)) do
        {:ok, _doc} -> {:ok, :updated}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, changeset}
    end
  end

  defp conflict_on_source?(changeset) do
    Enum.any?(changeset.errors, fn
      {:source_id, {_, opts}} -> Keyword.get(opts, :constraint) == :unique
      _ -> false
    end)
  end

  defp emit(status, counts, remote_docs, start_time, extra) do
    duration = System.monotonic_time() - start_time
    stale_pct = stale_percentage(remote_docs)

    if stale_pct > 0.02 do
      Logger.warning(
        "Drive sync stale percentage above threshold (#{Float.round(stale_pct * 100, 2)}%)"
      )
    end

    measurements = %{duration: duration, stale_pct: stale_pct}

    metadata =
      %{status: status, inserted: counts.inserted, updated: counts.updated}
      |> Map.merge(extra)

    :telemetry.execute(@event, measurements, metadata)
  end

  defp stale_percentage([]), do: 0.0

  defp stale_percentage(remote_docs) do
    stale = Enum.count(remote_docs, &Map.get(&1, :stale?, false))
    total = max(length(remote_docs), 1)
    stale / total
  end
end
