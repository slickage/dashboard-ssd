defmodule DashboardSSD.Projects.Project do
  @moduledoc "Ecto schema for projects tracked in the dashboard."
  use Ecto.Schema
  import Ecto.Changeset
  alias Ecto.Changeset

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
  @spec changeset(t() | Changeset.t(), map()) :: Changeset.t()
  def changeset(project, attrs) do
    project
    |> cast(attrs, [:name, :client_id])
    |> validate_required([:name])
    |> foreign_key_constraint(:client_id)
  end
end
