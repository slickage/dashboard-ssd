defmodule DashboardSSD.Accounts.UserInvite do
  @moduledoc """
  Schema representing an invitation for a user to join the system.

    - Persists invite metadata (email, role, client, inviter, usage state).
  - Validates tokens/emails and provides specialized changesets for creation/form flows.
  - Links accepted invites back to the resulting user for audit trails.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias DashboardSSD.Accounts.User
  alias DashboardSSD.Clients.Client
  alias Ecto.Association.NotLoaded

  @email_regex ~r/^[^@\s]+@[^@\s]+\.[^@\s]+$/

  @type t :: %__MODULE__{
          id: integer() | nil,
          email: String.t() | nil,
          token: String.t() | nil,
          role_name: String.t() | nil,
          client_id: integer() | nil,
          invited_by_id: integer() | nil,
          invited_by: User.t() | NotLoaded.t() | nil,
          client: Client.t() | NotLoaded.t() | nil,
          used_at: DateTime.t() | nil,
          accepted_user_id: integer() | nil,
          accepted_user: User.t() | NotLoaded.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          role: String.t() | nil
        }

  schema "user_invites" do
    field :email, :string
    field :token, :string
    field :role_name, :string
    field :used_at, :utc_datetime
    field :role, :string, virtual: true

    belongs_to :client, DashboardSSD.Clients.Client, type: :id
    belongs_to :invited_by, DashboardSSD.Accounts.User, type: :id

    belongs_to :accepted_user, DashboardSSD.Accounts.User,
      type: :id,
      foreign_key: :accepted_user_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for creating or updating a `UserInvite`.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
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
    |> validate_format(:email, @email_regex)
    |> unique_constraint(:token)
  end

  @doc """
  Convenience wrapper that ensures the token is forced to the provided value.
  """
  @spec creation_changeset(t(), map()) :: Ecto.Changeset.t()
  def creation_changeset(invite, attrs) do
    invite
    |> changeset(attrs)
    |> force_change(:token, Map.get(attrs, :token) || Map.get(attrs, "token"))
  end

  @doc """
  Builds a changeset tailored for the invite form, validating only the fields
  surfaced in the UI.
  """
  @spec form_changeset(t(), map(), keyword()) :: Ecto.Changeset.t()
  def form_changeset(invite, attrs, opts \\ []) do
    attrs = ensure_form_role(attrs)
    validate? = Keyword.get(opts, :validate, false)

    invite
    |> cast(attrs, [:email, :role, :client_id])
    |> normalize_email()
    |> maybe_validate_required(validate?)
    |> maybe_validate_email(validate?)
  end

  defp normalize_email(changeset) do
    update_change(changeset, :email, fn email ->
      email
      |> to_string()
      |> String.trim()
      |> String.downcase()
    end)
  end

  defp maybe_validate_required(changeset, false), do: changeset

  defp maybe_validate_required(changeset, true) do
    changeset
    |> validate_required([:email, :role])
  end

  defp maybe_validate_email(changeset, false), do: changeset

  defp maybe_validate_email(changeset, true) do
    validate_format(changeset, :email, @email_regex)
  end

  defp ensure_form_role(attrs) when is_map(attrs) do
    cond do
      Map.has_key?(attrs, :role) or Map.has_key?(attrs, "role") ->
        attrs

      Map.has_key?(attrs, :role_name) ->
        Map.put(attrs, :role, Map.get(attrs, :role_name))

      Map.has_key?(attrs, "role_name") ->
        Map.put(attrs, "role", Map.get(attrs, "role_name"))

      true ->
        Map.put(attrs, "role", "client")
    end
  end
end
