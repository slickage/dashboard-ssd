defmodule DashboardSSD.Accounts.ExternalIdentity do
  use Ecto.Schema
  import Ecto.Changeset

  schema "external_identities" do
    field :provider, :string
    field :provider_id, :string
    field :token, :string
    field :refresh_token, :string
    field :expires_at, :utc_datetime
    belongs_to :user, DashboardSSD.Accounts.User, type: :id
    timestamps(type: :utc_datetime)
  end

  def changeset(identity, attrs) do
    identity
    |> cast(attrs, [:provider, :provider_id, :token, :refresh_token, :expires_at, :user_id])
    |> validate_required([:provider, :user_id])
  end
end
