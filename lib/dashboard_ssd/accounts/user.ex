defmodule DashboardSSD.Accounts.User do
  @moduledoc "User schema with role and external identities."
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          email: String.t() | nil,
          name: String.t() | nil,
          role_id: integer() | nil
        }

  @derive {Jason.Encoder, only: [:id, :email, :name, :role_id]}
  schema "users" do
    field :email, :string
    field :name, :string
    belongs_to :role, DashboardSSD.Accounts.Role, type: :id
    has_many :external_identities, DashboardSSD.Accounts.ExternalIdentity
    timestamps(type: :utc_datetime)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :role_id])
    |> validate_required([:email])
    |> unique_constraint(:email)
  end
end
