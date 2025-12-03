defmodule DashboardSSD.Analytics.MetricSnapshot do
  @moduledoc """
  Schema for storing metric snapshots over time.

    - Persists per-project metric readings (uptime, MTTR, etc.) with timestamps.
  - Provides a changeset used by collectors to validate inputs before insert.
  - Derives JSON encoding to support API and LiveView consumption.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          project_id: integer() | nil,
          type: String.t() | nil,
          value: float() | nil,
          inserted_at: DateTime.t() | nil
        }

  @derive {Jason.Encoder, only: [:id, :project_id, :type, :value, :inserted_at]}
  schema "metric_snapshots" do
    field :type, :string
    field :value, :float
    belongs_to :project, DashboardSSD.Projects.Project

    timestamps(updated_at: false, type: :utc_datetime)
  end

  @doc """
  Creates a changeset for metric snapshot validation and casting.

  ## Parameters
    - metric_snapshot: The metric snapshot struct or changeset
    - attrs: Map of attributes to cast and validate

  ## Validations
    - project_id: Required
    - type: Required
    - value: Required
  """
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(metric_snapshot, attrs) do
    metric_snapshot
    |> cast(attrs, [:project_id, :type, :value])
    |> validate_required([:project_id, :type, :value])
  end
end
