defmodule DashboardSSD.Accounts do
  @moduledoc """
  Accounts context: users, roles, and external identities.

  Exposes a small, well-documented API for working with the
  authentication data model. All functions are pure wrappers
  around Ecto with clearly defined contracts.
  """
  @dialyzer {:nowarn_function, deliver_invite_email: 1}
  import Ecto.Query, warn: false

  alias DashboardSSD.Accounts.{
    ExternalIdentity,
    InviteEmail,
    Role,
    RoleCapability,
    User,
    UserInvite
  }

  alias DashboardSSD.Auth.Capabilities
  alias DashboardSSD.Mailer
  alias DashboardSSD.Repo

  defmodule DomainNotAllowedError do
    @moduledoc "Raised when a user attempts to sign in with an email domain outside the allowlist."
    defexception [:message]
  end

  # Users
  @doc """
  Lists all users ordered by insertion time.

  Returns a list of User structs.
  """
  @spec list_users() :: [User.t()]
  def list_users, do: Repo.all(User)

  @doc """
  Lists users with role and client preloaded.
  """
  @spec list_users_with_details() :: [User.t()]
  def list_users_with_details do
    Repo.all(from(u in User, preload: [:role, :client], order_by: [asc: u.inserted_at]))
  end

  @doc """
  Returns a changeset for tracking user changes.

  Validates the given attributes against the user schema.
  """
  @spec change_user(User.t(), map()) :: Ecto.Changeset.t()
  def change_user(%User{} = user, attrs \\ %{}), do: User.changeset(user, attrs)

  @doc """
  Fetches a user by ID.

  Raises Ecto.NoResultsError if the user does not exist.
  """
  @spec get_user!(pos_integer()) :: User.t()
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Fetches a user by email address.

  Returns the User struct or nil if not found.
  """
  @spec get_user_by_email(String.t()) :: User.t() | nil
  def get_user_by_email(email), do: Repo.get_by(User, email: email)

  @doc """
  Ensures a role exists by name.

  Creates the role if it doesn't exist, otherwise returns the existing one.
  """
  @spec ensure_role!(String.t()) :: Role.t()
  def ensure_role!(name) do
    Repo.get_by(Role, name: name) || %Role{} |> Role.changeset(%{name: name}) |> Repo.insert!()
  end

  @doc """
  Fetches a role by name, returning nil if not found.
  """
  @spec get_role_by_name(String.t()) :: Role.t() | nil
  def get_role_by_name(name), do: Repo.get_by(Role, name: name)

  @doc """
  Lists all roles ordered by name.
  """
  @spec list_roles() :: [Role.t()]
  def list_roles do
    Repo.all(from(r in Role, order_by: [asc: r.name]))
  end

  @doc """
  Creates a new user with the given attributes.

  Returns {:ok, user} on success or {:error, changeset} on validation failure.
  """
  @spec create_user(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def create_user(attrs) do
    %User{} |> User.changeset(attrs) |> Repo.insert()
  end

  @doc """
  Updates an existing user with the given attributes.

  Returns {:ok, user} on success or {:error, changeset} on validation failure.
  """
  @spec update_user(User.t(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_user(%User{} = user, attrs) do
    user |> User.changeset(attrs) |> Repo.update()
  end

  @doc """
  Deletes a user from the database.

  Returns {:ok, user} on success or {:error, changeset} on constraint violation.
  """
  @spec delete_user(User.t()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  # Role capabilities
  @doc """
  Lists all role capabilities with roles preloaded.
  """
  @spec list_role_capabilities() :: [RoleCapability.t()]
  def list_role_capabilities do
    Repo.all(RoleCapability) |> Repo.preload([:role, :granted_by])
  end

  @doc """
  Lists capability identifiers for the given role.

  Accepts a Role struct, role ID, or role name.
  """
  @spec capabilities_for_role(Role.t() | pos_integer() | String.t()) :: [String.t()]
  def capabilities_for_role(role) do
    role = resolve_role!(role)

    from(rc in RoleCapability,
      where: rc.role_id == ^role.id,
      select: rc.capability
    )
    |> Repo.all()
  end

  @doc """
  Replaces the capability set for a role.

  Returns the freshly persisted list of capabilities for the role.
  """
  @spec replace_role_capabilities(Role.t() | String.t(), [String.t()], keyword()) ::
          {:ok, [String.t()]} | {:error, term()}
  def replace_role_capabilities(role, capabilities, opts \\ []) do
    role = resolve_role!(role)
    granted_by_id = Keyword.get(opts, :granted_by_id)

    normalized_capabilities =
      capabilities |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == "")) |> Enum.uniq()

    with :ok <- validate_capability_codes(normalized_capabilities),
         :ok <- ensure_required_capabilities(role, normalized_capabilities) do
      Repo.transaction(fn ->
        from(rc in RoleCapability, where: rc.role_id == ^role.id) |> Repo.delete_all()

        Enum.each(normalized_capabilities, fn capability ->
          %RoleCapability{}
          |> RoleCapability.changeset(%{
            role_id: role.id,
            capability: capability,
            granted_by_id: granted_by_id
          })
          |> Repo.insert!()
        end)

        normalized_capabilities
      end)
    end
  end

  @doc """
  Returns summary data per role including latest updater metadata.
  """
  @spec role_capability_summary() ::
          [
            %{
              role: Role.t(),
              capabilities: [String.t()],
              updated_at: DateTime.t() | nil,
              updated_by: User.t() | nil
            }
          ]
  def role_capability_summary do
    roles = Repo.all(Role)

    capabilities =
      Repo.all(RoleCapability)
      |> Repo.preload([:granted_by])
      |> Enum.group_by(& &1.role_id)

    Enum.map(roles, fn role ->
      records = Map.get(capabilities, role.id, [])

      latest =
        records
        |> Enum.reject(&is_nil(&1.updated_at))
        |> Enum.sort_by(& &1.updated_at, {:desc, DateTime})
        |> List.first()

      %{
        role: role,
        capabilities: records |> Enum.map(& &1.capability) |> Enum.sort(),
        updated_at: latest && latest.updated_at,
        updated_by: latest && latest.granted_by
      }
    end)
  end

  defp resolve_role!(%Role{} = role), do: role

  defp resolve_role!(role_id) when is_integer(role_id) do
    Repo.get!(Role, role_id)
  end

  defp resolve_role!(role_name) when is_binary(role_name) do
    Repo.get_by!(Role, name: role_name)
  end

  defp validate_capability_codes([]), do: :ok

  defp validate_capability_codes(codes) do
    codes
    |> Enum.find(fn code -> not Capabilities.valid?(code) end)
    |> case do
      nil -> :ok
      invalid -> {:error, {:invalid_capability, invalid}}
    end
  end

  defp ensure_required_capabilities(%Role{name: "admin"}, codes) do
    required = ["settings.rbac"]

    missing = Enum.reject(required, &(&1 in codes))

    case missing do
      [] -> :ok
      _ -> {:error, :missing_required_admin_capability}
    end
  end

  defp ensure_required_capabilities(_role, _codes), do: :ok

  @doc """
  Switches a user's role to the provided role name.

  Accepts a User struct, id, or email. Returns {:ok, user} or {:error, reason}.
  """
  @spec switch_user_role(User.t() | pos_integer() | String.t(), String.t()) ::
          {:ok, User.t()} | {:error, term()}
  def switch_user_role(%User{} = user, role_name) do
    role = ensure_role!(role_name)

    user
    |> User.changeset(%{role_id: role.id})
    |> Repo.update()
    |> case do
      {:ok, updated} -> {:ok, Repo.preload(updated, :role)}
      other -> other
    end
  end

  def switch_user_role(user_id, role_name) when is_integer(user_id) do
    user = Repo.get!(User, user_id) |> Repo.preload(:role)
    switch_user_role(user, role_name)
  end

  def switch_user_role(email, role_name) when is_binary(email) do
    case get_user_by_email(email) do
      %User{} = user -> switch_user_role(Repo.preload(user, :role), role_name)
      nil -> {:error, :user_not_found}
    end
  end

  @doc """
  Updates a user's role and optionally associated client.
  """
  @spec update_user_role_and_client(pos_integer() | String.t(), String.t(), pos_integer() | nil) ::
          {:ok, User.t()} | {:error, term()}
  def update_user_role_and_client(user_identifier, role_name, client_id) do
    user =
      case user_identifier do
        id when is_integer(id) ->
          Repo.get!(User, id)

        id when is_binary(id) ->
          case Integer.parse(id) do
            {int, ""} -> Repo.get!(User, int)
            _ -> Repo.get_by!(User, email: id)
          end
      end

    role = ensure_role!(role_name)

    attrs =
      %{
        role_id: role.id,
        client_id: client_id
      }

    user
    |> User.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated} -> {:ok, Repo.preload(updated, [:role, :client])}
      other -> other
    end
  end

  @doc """
  Lists user invites with related data.
  """
  @spec list_user_invites() :: [UserInvite.t()]
  def list_user_invites do
    Repo.all(
      from(i in UserInvite,
        preload: [:client, :invited_by, :accepted_user],
        order_by: [desc: i.inserted_at]
      )
    )
  end

  @doc """
  Retrieves a user invite by token.
  """
  @spec get_invite_by_token(String.t()) :: UserInvite.t() | nil
  def get_invite_by_token(token) when is_binary(token) do
    Repo.get_by(UserInvite, token: token)
    |> Repo.preload([:client, :invited_by, :accepted_user])
  end

  @doc """
  Creates a user invite and sends an email.
  """
  @spec create_user_invite(map()) :: {:ok, UserInvite.t()} | {:error, term()}
  def create_user_invite(attrs) when is_map(attrs) do
    with {:ok, email} <- extract_invite_email(attrs),
         :ok <- ensure_invited_user_absent(email),
         {:ok, role_name} <- resolve_invite_role(attrs),
         {:ok, invite_attrs} <- build_invite_attrs(attrs, email, role_name),
         {:ok, invite} <-
           %UserInvite{}
           |> UserInvite.changeset(invite_attrs)
           |> Repo.insert() do
      invite = Repo.preload(invite, [:client, :invited_by])
      deliver_invite_email(invite)
      {:ok, invite}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp extract_invite_email(attrs) do
    attrs
    |> Map.get("email")
    |> case do
      nil -> Map.get(attrs, :email)
      value -> value
    end
    |> normalize_email()
    |> case do
      nil -> {:error, :invalid_email}
      email -> {:ok, email}
    end
  end

  defp ensure_invited_user_absent(email) do
    case Repo.get_by(User, email: email) do
      %User{} -> {:error, :user_exists}
      nil -> :ok
    end
  end

  defp resolve_invite_role(attrs) do
    role_name =
      attrs
      |> Map.get("role")
      |> case do
        nil -> Map.get(attrs, :role)
        value -> value
      end
      |> case do
        nil -> "client"
        value -> to_string(value)
      end

    ensure_role!(role_name)
    {:ok, role_name}
  end

  defp build_invite_attrs(attrs, email, role_name) do
    attrs =
      attrs
      |> Enum.reduce(%{}, fn
        {"role", _value}, acc -> acc
        {"client_id", value}, acc -> Map.put(acc, :client_id, value)
        {"invited_by_id", value}, acc -> Map.put(acc, :invited_by_id, value)
        {key, value}, acc when is_atom(key) -> Map.put(acc, key, value)
        {_key, _value}, acc -> acc
      end)
      |> Map.put(:email, email)
      |> Map.put(:role_name, role_name)
      |> Map.put(:token, Ecto.UUID.generate())
      |> Map.update(:client_id, nil, &parse_optional_integer/1)
      |> Map.update(:invited_by_id, nil, &parse_optional_integer/1)

    {:ok, attrs}
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
    invite_token = Map.get(attrs, :invite_token)

    existing_user = get_user_by_email(email)
    ensure_domain_allowed!(email, existing_user)

    case find_identity(provider, provider_id) do
      {:identity, user, identity} ->
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
        |> Repo.preload([:role, :client])
        |> maybe_apply_invite(invite_token)

      :none ->
        user =
          case existing_user do
            %User{} = existing -> Repo.preload(existing, [:role, :client])
            nil -> create_user_for_email!(email, name)
          end

        attrs = identity_attrs(user.id, provider, provider_id, token, refresh_token, expires_at)

        Repo.get_by(ExternalIdentity, user_id: user.id, provider: provider)
        |> upsert_identity(attrs)

        user
        |> Repo.preload([:role, :client])
        |> maybe_apply_invite(invite_token)
    end
  end

  defp find_identity(_provider, nil), do: :none

  defp find_identity(provider, provider_id) do
    case Repo.get_by(ExternalIdentity, provider: provider, provider_id: provider_id) do
      %ExternalIdentity{} = identity ->
        identity = Repo.preload(identity, :user)
        {:identity, identity.user, identity}

      nil ->
        :none
    end
  end

  defp create_user_for_email!(email, name) do
    case create_user(%{email: email, name: name, role_id: default_role_id(email)}) do
      {:ok, user} -> Repo.preload(user, [:role, :client])
      {:error, cs} -> raise ArgumentError, inspect(cs.errors)
    end
  end

  defp upsert_identity(%ExternalIdentity{} = identity, attrs) do
    identity
    |> ExternalIdentity.changeset(attrs)
    |> Repo.update()
  end

  defp upsert_identity(nil, attrs) do
    %ExternalIdentity{}
    |> ExternalIdentity.changeset(attrs)
    |> Repo.insert()
  end

  defp identity_attrs(user_id, provider, provider_id, token, refresh_token, expires_at) do
    %{
      user_id: user_id,
      provider: provider,
      provider_id: provider_id,
      token: token,
      refresh_token: refresh_token,
      expires_at: expires_at
    }
  end

  @doc """
  Applies a pending invite to a user if the token matches.
  """
  @spec apply_invite(User.t(), String.t() | nil) :: {:ok, User.t()}
  def apply_invite(%User{} = user, nil), do: {:ok, Repo.preload(user, [:role, :client])}

  def apply_invite(%User{} = user, token) when is_binary(token) do
    case get_invite_by_token(token) do
      %UserInvite{used_at: nil} = invite ->
        if normalize_email(user.email) == invite.email do
          role = ensure_role!(invite.role_name)

          attrs = %{
            role_id: role.id,
            client_id: invite.client_id
          }

          updated_user =
            user
            |> User.changeset(attrs)
            |> Repo.update!()
            |> Repo.preload([:role, :client])

          invite
          |> UserInvite.changeset(%{
            used_at: DateTime.utc_now(),
            accepted_user_id: updated_user.id
          })
          |> Repo.update!()

          {:ok, updated_user}
        else
          {:ok, Repo.preload(user, [:role, :client])}
        end

      _ ->
        {:ok, Repo.preload(user, [:role, :client])}
    end
  end

  defp maybe_apply_invite(user, invite_token) do
    {:ok, updated} = apply_invite(user, invite_token)
    updated
  end

  defp deliver_invite_email(invite) do
    invite
    |> InviteEmail.new_invite_email()
    |> Mailer.deliver()
  end

  defp normalize_email(nil), do: nil

  defp normalize_email(email) do
    email
    |> to_string()
    |> String.trim()
    |> String.downcase()
  end

  defp parse_optional_integer(nil), do: nil
  defp parse_optional_integer(""), do: nil
  defp parse_optional_integer(value) when is_integer(value), do: value

  defp parse_optional_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp parse_optional_integer(value), do: value

  defp ensure_domain_allowed!(email, existing_user) do
    case existing_user do
      nil ->
        cond do
          not is_binary(email) ->
            raise DomainNotAllowedError, "Email domain not allowed: #{email}"

          not domain_allowed?(email) ->
            raise DomainNotAllowedError, "Email domain not allowed: #{email}"

          true ->
            :ok
        end

      _ ->
        :ok
    end
  end

  # If there are no users in the system, the first user gets the admin role.
  # Otherwise, default to employee.
  defp default_role_id(email) do
    cond do
      Repo.aggregate(User, :count, :id) == 0 -> ensure_role!("admin").id
      domain_allowed?(email) -> ensure_role!("employee").id
      true -> ensure_role!("client").id
    end
  end

  @spec domain_allowed?(String.t()) :: boolean()
  defp domain_allowed?(email) do
    case String.split(email, "@", parts: 2) do
      [_local_part, domain] when byte_size(domain) > 0 ->
        normalized_domain = String.downcase(domain)
        Enum.any?(allowed_domains(), &(String.downcase(&1) == normalized_domain))

      _ ->
        false
    end
  end

  defp allowed_domains do
    case Application.get_env(:dashboard_ssd, __MODULE__, [])
         |> Keyword.get(:slickage_allowed_domains) do
      nil -> ["slickage.com"]
      domains -> List.wrap(domains)
    end
  end
end
