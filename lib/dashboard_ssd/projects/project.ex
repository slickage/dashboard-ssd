defmodule DashboardSSD.Projects.Project do
  use Ecto.Schema
  import Ecto.Changeset

  @typedoc "Project record"
  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          client_id: integer() | nil
        }

  @derive {Jason.Encoder, only: [:id, :name, :client_id]}
  schema "projects" do
    field :name, :string
    belongs_to :client, DashboardSSD.Clients.Client, type: :id
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(project, attrs) do
    project
    |> cast(attrs, [:name, :client_id])
    |> validate_required([:name, :client_id])
    |> foreign_key_constraint(:client_id)
  end
end
