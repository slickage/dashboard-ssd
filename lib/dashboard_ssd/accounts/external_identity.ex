defmodule DashboardSSD.Accounts.ExternalIdentity do
  use Ecto.Schema
  import Ecto.Changeset
  alias Ecto.Changeset

  @moduledoc "Linked external identity credentials for a user (e.g., Google)."

  @typedoc "External identity record"
  @type t :: %__MODULE__{
          id: integer() | nil,
          provider: String.t() | nil,
          provider_id: String.t() | nil,
          token: binary() | nil,
          refresh_token: binary() | nil,
          expires_at: DateTime.t() | nil,
          user_id: integer() | nil
        }

  schema "external_identities" do
    field :provider, :string
    field :provider_id, :string
    field :token, DashboardSSD.Encrypted.Binary
    field :refresh_token, DashboardSSD.Encrypted.Binary
    field :expires_at, :utc_datetime
    belongs_to :user, DashboardSSD.Accounts.User, type: :id
    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec changeset(t() | Changeset.t(), map()) :: Changeset.t()
  def changeset(identity, attrs) do
    identity
    |> cast(attrs, [:provider, :provider_id, :token, :refresh_token, :expires_at, :user_id])
    |> validate_required([:provider, :user_id])
  end
end
