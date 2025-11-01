defmodule DashboardSSD.Projects.LinearWorkflowState do
  @moduledoc "Stores Linear workflow state metadata per team."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @typedoc "Metadata for a Linear workflow state."
  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          linear_team_id: String.t(),
          linear_state_id: String.t(),
          name: String.t(),
          type: String.t() | nil,
          color: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "linear_workflow_states" do
    field :linear_team_id, :string
    field :linear_state_id, :string
    field :name, :string
    field :type, :string
    field :color, :string

    timestamps(type: :utc_datetime)
  end

  @spec changeset(__MODULE__.t(), map()) :: Ecto.Changeset.t()
  @doc "Builds a changeset for a Linear workflow state record."
  def changeset(state, attrs) do
    state
    |> cast(attrs, [:linear_team_id, :linear_state_id, :name, :type, :color])
    |> validate_required([:linear_team_id, :linear_state_id, :name])
    |> unique_constraint(:linear_state_id,
      name: :linear_workflow_states_linear_state_id_index
    )
  end
end
