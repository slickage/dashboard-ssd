defmodule DashboardSSD.Contracts.ChangeRequest do
  @moduledoc "Change Request metadata and association to a project."
  use Ecto.Schema
  import Ecto.Changeset

  @typedoc "Change Request record"
  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          drive_id: String.t() | nil,
          project_id: integer() | nil
        }

  @derive {Jason.Encoder, only: [:id, :name, :drive_id, :project_id]}
  schema "change_requests" do
    field :name, :string
    field :drive_id, :string
    belongs_to :project, DashboardSSD.Projects.Project, type: :id
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(cr, attrs) do
    cr
    |> cast(attrs, [:name, :drive_id, :project_id])
    |> validate_required([:name, :project_id])
    |> foreign_key_constraint(:project_id)
  end
end
