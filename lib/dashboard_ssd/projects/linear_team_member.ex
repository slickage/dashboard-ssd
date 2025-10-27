defmodule DashboardSSD.Projects.LinearTeamMember do
  @moduledoc "Ecto schema storing Linear team member metadata captured during sync."
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          linear_team_id: String.t() | nil,
          linear_user_id: String.t() | nil,
          name: String.t() | nil,
          display_name: String.t() | nil,
          email: String.t() | nil,
          avatar_url: String.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  @derive {Jason.Encoder,
           only: [:linear_team_id, :linear_user_id, :name, :display_name, :email, :avatar_url]}
  schema "linear_team_members" do
    field :linear_team_id, :string
    field :linear_user_id, :string
    field :name, :string
    field :display_name, :string
    field :email, :string
    field :avatar_url, :string

    timestamps(type: :utc_datetime)
  end
end
