defmodule DashboardSSD.Accounts.Role do
  @moduledoc "Role schema (admin, employee, client)."
  use Ecto.Schema
  import Ecto.Changeset
  alias Ecto.Changeset

  @typedoc "Role record"
  @type t :: %__MODULE__{id: integer() | nil, name: String.t() | nil}

  @derive {Jason.Encoder, only: [:id, :name]}
  schema "roles" do
    field :name, :string
    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec changeset(t() | Changeset.t(), map()) :: Changeset.t()
  def changeset(role, attrs) do
    role
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
