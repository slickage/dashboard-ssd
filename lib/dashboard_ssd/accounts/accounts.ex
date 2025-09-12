defmodule DashboardSSD.Accounts do
  @moduledoc """
  Accounts context: users, roles, and external identities.
  """
  import Ecto.Query, warn: false
  alias DashboardSSD.Repo
  alias DashboardSSD.Accounts.{ExternalIdentity, Role, User}

  # Users
  def list_users, do: Repo.all(User)
  def change_user(%User{} = user, attrs \\ %{}), do: User.changeset(user, attrs)

  def get_user!(id), do: Repo.get!(User, id)
  def get_user_by_email(email), do: Repo.get_by(User, email: email)

  def ensure_role!(name) do
    Repo.get_by(Role, name: name) || %Role{} |> Role.changeset(%{name: name}) |> Repo.insert!()
  end

  def create_user(attrs) do
    %User{} |> User.changeset(attrs) |> Repo.insert()
  end

  def update_user(%User{} = user, attrs) do
    user |> User.changeset(attrs) |> Repo.update()
  end

  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

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
            case create_user(%{email: email, name: name, role_id: ensure_role!("employee").id}) do
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
end
