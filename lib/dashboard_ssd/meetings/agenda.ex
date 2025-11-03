defmodule DashboardSSD.Meetings.Agenda do
  @moduledoc """
  Context functions for managing pre-meeting agenda items.
  """
  import Ecto.Query
  alias DashboardSSD.Repo
  alias DashboardSSD.Meetings.AgendaItem

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

    result = Repo.transaction(fn ->
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
end
