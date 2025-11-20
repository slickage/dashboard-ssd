defmodule DashboardSSD.Meetings.FirefliesStore do
  @moduledoc """
  Persistence helpers for Fireflies artifacts per recurring series.

  Retrieval order in boundary: Cache → DB → API. This module provides the DB
  part and upsert on successful API fetches.
  """

  import Ecto.Query
  alias DashboardSSD.Meetings.FirefliesArtifact
  alias DashboardSSD.Repo

  @type artifacts :: %{
          accomplished: String.t() | nil,
          action_items: [String.t()],
          bullet_gist: String.t() | nil
        }

  @doc """
  Retrieves persisted artifacts for a recurring series id or `:not_found`.
  """
  @spec get(String.t()) :: {:ok, artifacts()} | :not_found
  def get(series_id) when is_binary(series_id) do
    case Repo.one(
           from a in FirefliesArtifact, where: a.recurring_series_id == ^series_id, limit: 1
         ) do
      %FirefliesArtifact{} = a ->
        {:ok,
         %{
           accomplished: a.accomplished,
           action_items: normalize_items(a.action_items),
           bullet_gist: a.bullet_gist
         }}

      _ ->
        :not_found
    end
  end

  @doc """
  Inserts or updates artifacts for a recurring series id.
  """
  @spec upsert(String.t(), map()) :: :ok
  def upsert(series_id, attrs) when is_binary(series_id) and is_map(attrs) do
    now = DateTime.utc_now()

    attrs =
      attrs
      |> Map.put(:recurring_series_id, series_id)
      |> Map.put(:fetched_at, Map.get(attrs, :fetched_at) || now)

    case Repo.get_by(FirefliesArtifact, recurring_series_id: series_id) do
      nil ->
        %FirefliesArtifact{}
        |> FirefliesArtifact.changeset(attrs)
        |> Repo.insert()

        :ok

      %FirefliesArtifact{} = rec ->
        rec
        |> FirefliesArtifact.changeset(attrs)
        |> Repo.update()

        :ok
    end
  end

  defp normalize_items(nil), do: []
  defp normalize_items(items) when is_list(items), do: items

  defp normalize_items(items) when is_map(items) do
    case Map.get(items, "items") do
      l when is_list(l) -> l
      _ -> []
    end
  end

  defp normalize_items(_), do: []
end
