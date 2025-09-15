defmodule DashboardSSD.Accounts do
  @moduledoc """
  Accounts context: users, roles, and external identities.

  Exposes a small, well-documented API for working with the
  authentication data model. All functions are pure wrappers
  around Ecto with clearly defined contracts.
  """
  import Ecto.Query, warn: false
  alias DashboardSSD.Repo
  alias DashboardSSD.Accounts.{ExternalIdentity, Role, User}

  # Users
  @doc "List all users"
  @spec list_users() :: [User.t()]
  def list_users, do: Repo.all(User)

  @doc "Return a changeset for a user with potential changes"
  @spec change_user(User.t(), map()) :: Ecto.Changeset.t()
  def change_user(%User{} = user, attrs \\ %{}), do: User.changeset(user, attrs)

  @doc "Fetch a user by id, raising if not found"
  @spec get_user!(pos_integer()) :: User.t()
  def get_user!(id), do: Repo.get!(User, id)

  @doc "Fetch a user by email or return nil"
  @spec get_user_by_email(String.t()) :: User.t() | nil
  def get_user_by_email(email), do: Repo.get_by(User, email: email)

  @doc "Ensure a role exists by name, creating it if missing"
  @spec ensure_role!(String.t()) :: Role.t()
  def ensure_role!(name) do
    Repo.get_by(Role, name: name) || %Role{} |> Role.changeset(%{name: name}) |> Repo.insert!()
  end

  @doc "Create a new user from attributes"
  @spec create_user(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def create_user(attrs) do
    %User{} |> User.changeset(attrs) |> Repo.insert()
  end

  @doc "Update a user with attributes"
  @spec update_user(User.t(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_user(%User{} = user, attrs) do
    user |> User.changeset(attrs) |> Repo.update()
  end

  @doc "Delete a user"
  @spec delete_user(User.t()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Upsert a user and the user's external identity for a provider.

  If `provider_id` is present, prefer linking/updating by (provider, provider_id).
  Otherwise, ensure a user by email and upsert the identity by (user, provider).
  """
  @spec upsert_user_with_identity(String.t(), map()) :: User.t()
  def upsert_user_with_identity(provider, attrs) do
    email = Map.fetch!(attrs, :email)
    name = Map.get(attrs, :name)
    provider_id = Map.get(attrs, :provider_id)
    token = Map.get(attrs, :token)
    refresh_token = Map.get(attrs, :refresh_token)
    expires_at = Map.get(attrs, :expires_at)

    # 1) Prefer linking by provider+provider_id if present
    case provider_id &&
           Repo.get_by(ExternalIdentity,
             provider: provider,
             provider_id: provider_id
           ) do
      %ExternalIdentity{} = identity ->
        # Update credentials and return the owning user
        {:ok, _} =
          identity
          |> ExternalIdentity.changeset(%{
            token: token,
            refresh_token: refresh_token,
            expires_at: expires_at
          })
          |> Repo.update()

        Repo.preload(identity, :user).user

      _ ->
        # 2) Fall back to email: ensure user exists
        user =
          get_user_by_email(email) ||
            case create_user(%{email: email, name: name, role_id: default_role_id()}) do
              {:ok, user} -> user
              {:error, cs} -> raise ArgumentError, inspect(cs.errors)
            end

        # 3) Ensure a single identity per user+provider; update if exists, otherwise insert
        case Repo.get_by(ExternalIdentity, user_id: user.id, provider: provider) do
          %ExternalIdentity{} = identity ->
            {:ok, _} =
              identity
              |> ExternalIdentity.changeset(%{
                provider_id: provider_id,
                token: token,
                refresh_token: refresh_token,
                expires_at: expires_at
              })
              |> Repo.update()

            user

          nil ->
            _ =
              %ExternalIdentity{}
              |> ExternalIdentity.changeset(%{
                user_id: user.id,
                provider: provider,
                provider_id: provider_id,
                token: token,
                refresh_token: refresh_token,
                expires_at: expires_at
              })
              |> Repo.insert!()

            user
        end
    end
  end

  # If there are no users in the system, the first user gets the admin role.
  # Otherwise, default to employee.
  defp default_role_id do
    if Repo.aggregate(User, :count, :id) == 0 do
      ensure_role!("admin").id
    else
      ensure_role!("employee").id
    end
  end
end
