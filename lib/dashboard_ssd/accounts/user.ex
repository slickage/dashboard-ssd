defmodule DashboardSSD.Accounts.User do
  @moduledoc "User schema with role and external identities."
  use Ecto.Schema
  import Ecto.Changeset
  alias Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          email: String.t() | nil,
          name: String.t() | nil,
          role_id: integer() | nil,
          client_id: integer() | nil
        }

  @derive {Jason.Encoder, only: [:id, :email, :name, :role_id]}
  schema "users" do
    field :email, :string
    field :name, :string
    belongs_to :role, DashboardSSD.Accounts.Role, type: :id
    belongs_to :client, DashboardSSD.Clients.Client, type: :id
    has_many :external_identities, DashboardSSD.Accounts.ExternalIdentity
    has_one :linear_user_link, DashboardSSD.Accounts.LinearUserLink
    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for user validation and casting.

  ## Parameters
    - user: The user struct or changeset
    - attrs: Map of attributes to cast and validate

  ## Validations
    - email: Required and must be unique
    - name: Optional
    - role_id: Optional
  """
  @spec changeset(t() | Changeset.t(), map()) :: Changeset.t()
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :role_id, :client_id])
    |> validate_required([:email])
    |> unique_constraint(:email)
  end
end
