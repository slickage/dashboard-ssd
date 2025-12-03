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
          linear_team_name: String.t() | nil,
          drive_folder_id: String.t() | nil,
          drive_folder_sharing_inherited: boolean(),
          drive_folder_last_permission_sync_at: DateTime.t() | nil
        }

  @derive {Jason.Encoder,
           only: [
             :id,
             :name,
             :client_id,
             :linear_project_id,
             :linear_team_id,
             :linear_team_name,
             :drive_folder_id,
             :drive_folder_sharing_inherited,
             :drive_folder_last_permission_sync_at
           ]}
  schema "projects" do
    field :name, :string
    field :linear_project_id, :string
    field :linear_team_id, :string
    field :linear_team_name, :string
    field :drive_folder_id, :string
    field :drive_folder_sharing_inherited, :boolean, default: true
    field :drive_folder_last_permission_sync_at, :utc_datetime
    belongs_to :client, DashboardSSD.Clients.Client, type: :id
    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec changeset(t() | Changeset.t(), map()) :: Changeset.t()
  def changeset(project, attrs) do
    project
    |> cast(attrs, [
      :name,
      :client_id,
      :linear_project_id,
      :linear_team_id,
      :linear_team_name,
      :drive_folder_id,
      :drive_folder_sharing_inherited,
      :drive_folder_last_permission_sync_at
    ])
    |> validate_required([:name])
    |> unique_constraint(:linear_project_id,
      name: :projects_linear_project_id_index
    )
    |> foreign_key_constraint(:client_id)
  end

  @doc """
  Dedicated changeset for updating Drive folder metadata fields.
  """
  @spec drive_metadata_changeset(t() | Changeset.t(), map()) :: Changeset.t()
  def drive_metadata_changeset(project, attrs) do
    project
    |> cast(attrs, [
      :drive_folder_id,
      :drive_folder_sharing_inherited,
      :drive_folder_last_permission_sync_at
    ])
    |> validate_required_if_drive_folder(:drive_folder_sharing_inherited)
  end

  defp validate_required_if_drive_folder(changeset, field) do
    case get_field(changeset, :drive_folder_id) do
      nil -> changeset
      _ -> validate_required(changeset, [field])
    end
  end
end
