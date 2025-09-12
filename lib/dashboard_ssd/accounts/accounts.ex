defmodule DashboardSSD.Accounts do
  @moduledoc """
  Accounts context: users, roles, and external identities.
  """
  import Ecto.Query, warn: false
  alias DashboardSSD.Repo
  alias DashboardSSD.Accounts.{ExternalIdentity, Role, User}

  def get_user!(id), do: Repo.get!(User, id)
  def get_user_by_email(email), do: Repo.get_by(User, email: email)

  def ensure_role!(name) do
    Repo.get_by(Role, name: name) || %Role{} |> Role.changeset(%{name: name}) |> Repo.insert!()
  end

  def create_user(attrs) do
    %User{} |> User.changeset(attrs) |> Repo.insert()
  end

  def upsert_user_with_identity(provider, attrs) do
    email = Map.fetch!(attrs, :email)
    name = Map.get(attrs, :name)
    provider_id = Map.get(attrs, :provider_id)
    token = Map.get(attrs, :token)
    refresh_token = Map.get(attrs, :refresh_token)
    expires_at = Map.get(attrs, :expires_at)

    user =
      get_user_by_email(email) ||
        case create_user(%{email: email, name: name, role_id: ensure_role!("employee").id}) do
          {:ok, user} -> user
          {:error, cs} -> raise ArgumentError, inspect(cs.errors)
        end

    identity_attrs = %{
      user_id: user.id,
      provider: provider,
      provider_id: provider_id,
      token: token,
      refresh_token: refresh_token,
      expires_at: expires_at
    }

    Repo.insert!(ExternalIdentity.changeset(%ExternalIdentity{}, identity_attrs),
      on_conflict: [set: Map.to_list(Map.drop(identity_attrs, [:user_id, :provider]))],
      conflict_target: [:user_id, :provider]
    )

    user
  end
end
