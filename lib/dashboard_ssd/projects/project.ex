defmodule DashboardSSD.Projects.Project do
  @moduledoc """
  Ecto schema for projects tracked in the dashboard.

    - Stores project metadata plus optional Linear identifiers.
  - Validates uniqueness of Linear IDs and presence of project names.
  - Serves as the anchor for associations (clients, deployments, metrics).
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Ecto.Changeset

  @typedoc "Project record"
  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          client_id: integer() | nil,
          linear_project_id: String.t() | nil,
          linear_team_id: String.t() | nil,
          linear_team_name: String.t() | nil
        }

  @derive {Jason.Encoder,
           only: [:id, :name, :client_id, :linear_project_id, :linear_team_id, :linear_team_name]}
  schema "projects" do
    field :name, :string
    field :linear_project_id, :string
    field :linear_team_id, :string
    field :linear_team_name, :string
    belongs_to :client, DashboardSSD.Clients.Client, type: :id
    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec changeset(t() | Changeset.t(), map()) :: Changeset.t()
  def changeset(project, attrs) do
    project
    |> cast(attrs, [:name, :client_id, :linear_project_id, :linear_team_id, :linear_team_name])
    |> validate_required([:name])
    |> unique_constraint(:linear_project_id,
      name: :projects_linear_project_id_index
    )
    |> foreign_key_constraint(:client_id)
  end
end
