defmodule DashboardSSD.Meetings.FirefliesArtifact do
  @moduledoc """
  Ecto schema for persisted Fireflies artifacts per recurring series.

  Stores the last successful fetch so we can avoid long vendor timeouts and
  rate limits. We intentionally do not persist empty results.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          recurring_series_id: String.t(),
          transcript_id: String.t() | nil,
          accomplished: String.t() | nil,
          bullet_gist: String.t() | nil,
          action_items: list() | map() | nil,
          fetched_at: DateTime.t() | nil
        }

  schema "fireflies_artifacts" do
    field :recurring_series_id, :string
    field :transcript_id, :string
    field :accomplished, :string
    field :bullet_gist, :string
    field :action_items, :map
    field :fetched_at, :utc_datetime
    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(artifact, attrs) do
    attrs = normalize_action_items_attr(attrs)

    artifact
    |> cast(attrs, [
      :recurring_series_id,
      :transcript_id,
      :accomplished,
      :bullet_gist,
      :action_items,
      :fetched_at
    ])
    |> validate_required([:recurring_series_id])
    |> unique_constraint(:recurring_series_id)
  end

  defp normalize_action_items_attr(attrs) when is_map(attrs) do
    cond do
      is_list(Map.get(attrs, :action_items)) ->
        Map.put(attrs, :action_items, %{"items" => Map.get(attrs, :action_items)})

      is_list(Map.get(attrs, "action_items")) ->
        Map.put(attrs, "action_items", %{"items" => Map.get(attrs, "action_items")})

      true ->
        attrs
    end
  end

  defp normalize_action_items_attr(attrs), do: attrs
end
