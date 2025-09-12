defmodule DashboardSSD.Notifications.Alert do
  use Ecto.Schema
  import Ecto.Changeset

  @typedoc "Alert record"
  @type t :: %__MODULE__{
          id: integer() | nil,
          project_id: integer() | nil,
          message: String.t() | nil,
          status: String.t() | nil
        }

  @derive {Jason.Encoder, only: [:id, :project_id, :message, :status]}
  schema "alerts" do
    belongs_to :project, DashboardSSD.Projects.Project, type: :id
    field :message, :string
    field :status, :string
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(alert, attrs) do
    alert
    |> cast(attrs, [:project_id, :message, :status])
    |> validate_required([:project_id, :message, :status])
    |> foreign_key_constraint(:project_id)
  end
end
