defmodule DashboardSSD.Accounts.UserInvite do
  @moduledoc "Schema representing an invitation for a user to join the system."
  use Ecto.Schema
  import Ecto.Changeset

  alias DashboardSSD.Accounts.User
  alias DashboardSSD.Clients.Client

  @type t :: %__MODULE__{
          id: integer() | nil,
          email: String.t(),
          token: String.t(),
          role_name: String.t(),
          client_id: integer() | nil,
          invited_by_id: integer() | nil,
          invited_by: User.t() | nil,
          client: Client.t() | nil,
          used_at: DateTime.t() | nil,
          accepted_user_id: integer() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "user_invites" do
    field :email, :string
    field :token, :string
    field :role_name, :string
    field :used_at, :utc_datetime

    belongs_to :client, DashboardSSD.Clients.Client, type: :id
    belongs_to :invited_by, DashboardSSD.Accounts.User, type: :id

    belongs_to :accepted_user, DashboardSSD.Accounts.User,
      type: :id,
      foreign_key: :accepted_user_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(invite, attrs) do
    invite
    |> cast(attrs, [
      :email,
      :token,
      :role_name,
      :client_id,
      :invited_by_id,
      :used_at,
      :accepted_user_id
    ])
    |> normalize_email()
    |> validate_required([:email, :token, :role_name])
    |> validate_format(:email, ~r/^[^@\s]+@[^@\s]+\.[^@\s]+$/)
    |> unique_constraint(:token)
  end

  @doc false
  def creation_changeset(invite, attrs) do
    invite
    |> changeset(attrs)
    |> force_change(:token, Map.get(attrs, :token) || Map.get(attrs, "token"))
  end

  defp normalize_email(changeset) do
    update_change(changeset, :email, fn email ->
      email
      |> to_string()
      |> String.trim()
      |> String.downcase()
    end)
  end
end
