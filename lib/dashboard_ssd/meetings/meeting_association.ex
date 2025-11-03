defmodule DashboardSSD.Meetings.MeetingAssociation do
  @moduledoc """
  Ecto schema linking a meeting occurrence or series to a Client or Project.
  One of `client_id` or `project_id` must be set.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          calendar_event_id: String.t() | nil,
          recurring_series_id: String.t() | nil,
          client_id: integer() | nil,
          project_id: integer() | nil,
          origin: String.t() | nil,
          persist_series: boolean() | nil
        }

  schema "meeting_associations" do
    field :calendar_event_id, :string
    field :recurring_series_id, :string
    field :origin, :string, default: "auto"
    field :persist_series, :boolean, default: false
    belongs_to :client, DashboardSSD.Clients.Client, type: :id
    belongs_to :project, DashboardSSD.Projects.Project, type: :id
    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec changeset(t() | Changeset.t(), map()) :: Changeset.t()
  def changeset(assoc, attrs) do
    assoc
    |> cast(attrs, [
      :calendar_event_id,
      :recurring_series_id,
      :client_id,
      :project_id,
      :origin,
      :persist_series
    ])
    |> validate_required([:calendar_event_id])
    |> validate_inclusion(:origin, ["auto", "manual"])
    |> check_constraint(:client_or_project,
      name: :client_or_project_must_be_set,
      message: "either client_id or project_id must be present"
    )
    |> foreign_key_constraint(:client_id)
    |> foreign_key_constraint(:project_id)
  end
end

