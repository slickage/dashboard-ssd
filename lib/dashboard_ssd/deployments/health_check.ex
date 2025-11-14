defmodule DashboardSSD.Deployments.HealthCheck do
  @moduledoc """
  Historical production health check status for a project.

    - Records uptime/health outcomes that analytics and dashboards consume.
  - Validates association to a project and required status via the changeset.
  - Keeps timestamps for chronological analysis of health events.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Ecto.Changeset

  @typedoc "Health check record"
  @type t :: %__MODULE__{
          id: integer() | nil,
          project_id: integer() | nil,
          status: String.t() | nil
        }

  @derive {Jason.Encoder, only: [:id, :project_id, :status]}
  schema "health_checks" do
    belongs_to :project, DashboardSSD.Projects.Project, type: :id
    field :status, :string
    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec changeset(t() | Changeset.t(), map()) :: Changeset.t()
  def changeset(health, attrs) do
    health
    |> cast(attrs, [:project_id, :status])
    |> validate_required([:project_id, :status])
    |> foreign_key_constraint(:project_id)
  end
end
