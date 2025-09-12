defmodule DashboardSSD.Notifications.NotificationRule do
  use Ecto.Schema
  import Ecto.Changeset

  @typedoc "Notification rule record"
  @type t :: %__MODULE__{
          id: integer() | nil,
          project_id: integer() | nil,
          event_type: String.t() | nil,
          channel: String.t() | nil
        }

  @derive {Jason.Encoder, only: [:id, :project_id, :event_type, :channel]}
  schema "notification_rules" do
    belongs_to :project, DashboardSSD.Projects.Project, type: :id
    field :event_type, :string
    field :channel, :string
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(rule, attrs) do
    rule
    |> cast(attrs, [:project_id, :event_type, :channel])
    |> validate_required([:project_id, :event_type, :channel])
    |> foreign_key_constraint(:project_id)
  end
end
