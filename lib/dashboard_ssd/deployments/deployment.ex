defmodule DashboardSSD.Deployments.Deployment do
  use Ecto.Schema
  import Ecto.Changeset

  @typedoc "Deployment record"
  @type t :: %__MODULE__{
          id: integer() | nil,
          project_id: integer() | nil,
          status: String.t() | nil,
          commit_sha: String.t() | nil
        }

  @derive {Jason.Encoder, only: [:id, :project_id, :status, :commit_sha]}
  schema "deployments" do
    belongs_to :project, DashboardSSD.Projects.Project, type: :id
    field :status, :string
    field :commit_sha, :string
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(deployment, attrs) do
    deployment
    |> cast(attrs, [:project_id, :status, :commit_sha])
    |> validate_required([:project_id, :status])
    |> foreign_key_constraint(:project_id)
  end
end
