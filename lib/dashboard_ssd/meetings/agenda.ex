defmodule DashboardSSD.Meetings.Agenda do
  @moduledoc """
  Context functions for managing pre-meeting agenda items.
  """
  import Ecto.Query
  alias DashboardSSD.Repo
  alias DashboardSSD.Meetings.AgendaItem
  alias DashboardSSD.Integrations.Fireflies

  @spec list_items(String.t()) :: [AgendaItem.t()]
  def list_items(calendar_event_id) when is_binary(calendar_event_id) do
    from(ai in AgendaItem,
      where: ai.calendar_event_id == ^calendar_event_id,
      order_by: ai.position
    )
    |> Repo.all()
  end

  @spec create_item(map()) :: {:ok, AgendaItem.t()} | {:error, Ecto.Changeset.t()}
  def create_item(attrs) when is_map(attrs) do
    %AgendaItem{}
    |> AgendaItem.changeset(Map.put_new(attrs, :source, "manual"))
    |> Repo.insert()
  end

  @spec update_item(AgendaItem.t(), map()) :: {:ok, AgendaItem.t()} | {:error, Ecto.Changeset.t()}
  def update_item(%AgendaItem{} = item, attrs) do
    item
    |> AgendaItem.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_item(AgendaItem.t()) :: {:ok, AgendaItem.t()} | {:error, Ecto.Changeset.t()}
  def delete_item(%AgendaItem{} = item), do: Repo.delete(item)

  @spec reorder_items(String.t(), [integer()]) :: :ok | {:error, term()}
  def reorder_items(calendar_event_id, ordered_ids) when is_binary(calendar_event_id) do
    items = list_items(calendar_event_id)
    pos_map = ordered_ids |> Enum.with_index(0) |> Map.new()

    result =
      Repo.transaction(fn ->
        for item <- items do
          new_pos = Map.get(pos_map, item.id, item.position)

          if new_pos != item.position do
            {:ok, _} = update_item(item, %{position: new_pos})
          end
        end

        :ok
      end)

    case result do
      {:ok, _} -> :ok
      {:error, _} = err -> err
    end
  end

  @doc """
  Derive agenda items for a given meeting occurrence by fetching the latest
  completed Fireflies artifacts for the recurring series.

  Returns a list of maps with keys: :text and :source ("derived").
  """
  @spec derive_items_for_event(String.t(), String.t() | nil, keyword()) :: [map()]
  def derive_items_for_event(_calendar_event_id, _series_id, _opts \\ [])
  def derive_items_for_event(_calendar_event_id, nil, _opts), do: []

  def derive_items_for_event(_calendar_event_id, series_id, opts) when is_binary(series_id) do
    case Fireflies.fetch_latest_for_series(series_id, opts) do
      {:ok, %{action_items: items}} ->
        items
        |> Enum.map(&%{text: &1, source: "derived"})

      _ ->
        []
    end
  end

  @doc """
  Merge manual agenda items (persisted) with derived items, de-duplicating by
  normalized text.
  """
  @spec merged_items_for_event(String.t(), String.t() | nil, keyword()) :: [map()]
  def merged_items_for_event(calendar_event_id, series_id, opts \\ []) do
    manual =
      list_items(calendar_event_id)
      |> Enum.map(&%{text: &1.text, source: "manual", id: &1.id, position: &1.position})

    derived = derive_items_for_event(calendar_event_id, series_id, opts)

    (manual ++ derived)
    |> dedup_by_text()
  end

  defp dedup_by_text(items) do
    {acc, _seen} =
      Enum.reduce(items, {[], MapSet.new()}, fn item, {acc, seen} ->
        key = normalize_text(item.text)

        if MapSet.member?(seen, key) do
          {acc, seen}
        else
          {[item | acc], MapSet.put(seen, key)}
        end
      end)

    acc |> Enum.reverse()
  end

  defp normalize_text(nil), do: ""

  defp normalize_text(text) do
    text
    |> String.downcase()
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
  end

  @doc """
  Replaces all manual agenda items for a meeting with a single text blob.
  """
  @spec replace_manual_text(String.t(), String.t()) :: :ok | {:error, term()}
  def replace_manual_text(calendar_event_id, text) when is_binary(calendar_event_id) do
    Repo.transaction(fn ->
      from(ai in AgendaItem,
        where: ai.calendar_event_id == ^calendar_event_id and ai.source == "manual"
      )
      |> Repo.delete_all()

      %AgendaItem{}
      |> AgendaItem.changeset(%{
        calendar_event_id: calendar_event_id,
        text: String.trim(text || ""),
        position: 0,
        source: "manual"
      })
      |> Repo.insert()
    end)
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
