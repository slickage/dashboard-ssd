defmodule DashboardSSD.Accounts.RoleCapability do
  @moduledoc """
  Associates a role with a granted capability and audit metadata.

    - Persists which capability codes are granted to each role.
  - Captures the admin who last changed the grant for auditing.
  - Enforces uniqueness and foreign-key integrity via the changeset.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias DashboardSSD.Accounts.{Role, User}

  @typedoc "Role capability record"
  @type t :: %__MODULE__{
          id: integer() | nil,
          role_id: pos_integer() | nil,
          capability: String.t() | nil,
          granted_by_id: pos_integer() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "role_capabilities" do
    belongs_to :role, Role
    field :capability, :string
    belongs_to :granted_by, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(role_capability, attrs) do
    role_capability
    |> cast(attrs, [:role_id, :capability, :granted_by_id])
    |> validate_required([:role_id, :capability])
    |> foreign_key_constraint(:role_id)
    |> foreign_key_constraint(:granted_by_id)
    |> unique_constraint([:role_id, :capability])
  end
end
