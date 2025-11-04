defmodule DashboardSSD.AccountsTest do
  use DashboardSSD.DataCase, async: false

  alias DashboardSSD.{Accounts, Clients, Repo}
  alias DashboardSSD.Accounts.ExternalIdentity

  setup do
    prev = Application.get_env(:dashboard_ssd, DashboardSSD.Accounts)

    Application.put_env(:dashboard_ssd, DashboardSSD.Accounts,
      slickage_allowed_domains: ["slickage.com", "example.com"]
    )

    on_exit(fn ->
      if prev,
        do: Application.put_env(:dashboard_ssd, DashboardSSD.Accounts, prev),
        else: Application.delete_env(:dashboard_ssd, DashboardSSD.Accounts)
    end)

    :ok
  end

  test "upsert_user_with_identity matches by provider+provider_id and updates credentials" do
    # Ensure role exists
    role = Accounts.ensure_role!("employee")

    # Prepare an existing user and identity
    {:ok, user} =
      Accounts.create_user(%{email: "by-id@example.com", name: "ById", role_id: role.id})

    identity =
      %ExternalIdentity{}
      |> ExternalIdentity.changeset(%{
        user_id: user.id,
        provider: "google",
        provider_id: "prov-123",
        token: "old-token",
        refresh_token: "old-refresh",
        expires_at: DateTime.utc_now()
      })
      |> Repo.insert!()

    # Call upsert with same provider+provider_id but different email
    result_user =
      Accounts.upsert_user_with_identity("google", %{
        email: "different@slickage.com",
        name: "Different",
        provider_id: "prov-123",
        token: "new-token",
        refresh_token: "new-refresh",
        expires_at: DateTime.utc_now()
      })

    # Should return the original user, not create a new one
    assert result_user.id == user.id

    updated = Repo.get!(ExternalIdentity, identity.id)
    assert updated.token == "new-token"
    assert updated.refresh_token == "new-refresh"
  end

  test "upsert_user_with_identity creates user and identity when none exist; updates identity on next login" do
    # First login creates user and identity
    user =
      Accounts.upsert_user_with_identity("google", %{
        email: "first@slickage.com",
        name: "First",
        provider_id: "prov-x",
        token: "tok-1",
        refresh_token: "ref-1",
        expires_at: DateTime.utc_now()
      })

    assert %DashboardSSD.Accounts.User{} = user

    identity = Repo.get_by(ExternalIdentity, user_id: user.id, provider: "google")
    assert identity
    assert identity.provider_id == "prov-x"
    assert identity.token == "tok-1"

    # Second login updates identity
    user2 =
      Accounts.upsert_user_with_identity("google", %{
        email: "first@slickage.com",
        name: "First",
        provider_id: "prov-y",
        token: "tok-2",
        refresh_token: "ref-2",
        expires_at: DateTime.utc_now()
      })

    assert user2.id == user.id
    identity2 = Repo.get_by(ExternalIdentity, user_id: user.id, provider: "google")
    assert identity2.provider_id == "prov-y"
    assert identity2.token == "tok-2"
    assert identity2.refresh_token == "ref-2"
  end

  test "upsert_user_with_identity raises when user creation fails validation" do
    assert_raise ArgumentError, fn ->
      Accounts.upsert_user_with_identity("google", %{
        email: nil,
        name: "Invalid Login Attempt",
        provider_id: "prov-invalid",
        token: "token"
      })
    end
  end

  test "upsert_user_with_identity assigns employee role once an admin exists" do
    Repo.delete_all(DashboardSSD.Accounts.User)
    Repo.delete_all(DashboardSSD.Accounts.Role)

    _admin =
      Accounts.upsert_user_with_identity("google", %{
        email: "admin@slickage.com",
        name: "First User",
        provider_id: "prov-admin",
        token: "token-admin"
      })

    second =
      Accounts.upsert_user_with_identity("google", %{
        email: "employee@slickage.com",
        name: "Second User",
        provider_id: "prov-employee",
        token: "token-employee"
      })
      |> Repo.preload(:role)

    assert second.role.name == "employee"
  end

  test "apply_invite updates role, client, and marks invite used" do
    admin_role = Accounts.ensure_role!("admin")
    employee_role = Accounts.ensure_role!("employee")
    client_role = Accounts.ensure_role!("client")

    {:ok, admin} =
      Accounts.create_user(%{
        email: "invite-admin@slickage.com",
        name: "Admin",
        role_id: admin_role.id
      })

    client = Clients.ensure_client!("Acme Corp")

    {:ok, invite} =
      Accounts.create_user_invite(%{
        "email" => "invited@example.com",
        "role" => "client",
        "client_id" => client.id,
        "invited_by_id" => admin.id
      })

    {:ok, user} =
      Accounts.create_user(%{
        email: "invited@example.com",
        name: "Invited",
        role_id: employee_role.id
      })

    assert invite.used_at == nil

    {:ok, updated_user} =
      user
      |> Repo.preload([:role, :client])
      |> Accounts.apply_invite(invite.token)

    assert updated_user.role.name == client_role.name
    assert updated_user.client_id == client.id

    updated_invite = Accounts.get_invite_by_token(invite.token)
    assert updated_invite.used_at
    assert updated_invite.accepted_user_id == updated_user.id
  end

  test "apply_invite ignores mismatched email" do
    employee_role = Accounts.ensure_role!("employee")

    {:ok, user} =
      Accounts.create_user(%{
        email: "different@slickage.com",
        name: "Different",
        role_id: employee_role.id
      })

    {:ok, invite} =
      Accounts.create_user_invite(%{
        "email" => "other@example.com",
        "role" => "client"
      })

    {:ok, result} = Accounts.apply_invite(Repo.preload(user, [:role]), invite.token)

    assert result.id == user.id
    assert result.role_id == employee_role.id
    refute result.client_id

    invite = Accounts.get_invite_by_token(invite.token)
    assert invite.used_at == nil
  end

  test "apply_invite with invalid token returns original user" do
    employee_role = Accounts.ensure_role!("employee")

    {:ok, user} =
      Accounts.create_user(%{
        email: "tokenless@slickage.com",
        name: "Tokenless",
        role_id: employee_role.id
      })

    {:ok, result} = Accounts.apply_invite(Repo.preload(user, [:role]), "unknown-token")

    assert result.id == user.id
  end

  test "apply_invite returns user unchanged when no token provided" do
    employee_role = Accounts.ensure_role!("employee")

    {:ok, user} =
      Accounts.create_user(%{
        email: "notoken@slickage.com",
        name: "No Token",
        role_id: employee_role.id
      })

    {:ok, result} = Accounts.apply_invite(Repo.preload(user, [:role]), nil)

    assert result.id == user.id
  end

  test "create_user_invite rejects missing email" do
    assert {:error, :invalid_email} = Accounts.create_user_invite(%{})
  end

  test "create_user_invite rejects when user already exists" do
    role = Accounts.ensure_role!("client")

    {:ok, user} =
      Accounts.create_user(%{
        email: "existing-invitee@example.com",
        name: "Existing Invitee",
        role_id: role.id
      })

    assert {:error, :user_exists} =
             Accounts.create_user_invite(%{"email" => user.email, "role" => "client"})
  end

  test "create_user_invite casts client_id and invited_by_id" do
    admin = Accounts.ensure_role!("admin")

    {:ok, inviter} =
      Accounts.create_user(%{
        email: "inviter@example.com",
        name: "Inviter",
        role_id: admin.id
      })

    client = Clients.ensure_client!("Widget Co")

    {:ok, invite} =
      Accounts.create_user_invite(%{
        "email" => "string-ids@example.com",
        "role" => "client",
        "client_id" => Integer.to_string(client.id),
        "invited_by_id" => Integer.to_string(inviter.id)
      })

    assert invite.client_id == client.id
    assert invite.invited_by_id == inviter.id
  end

  test "get_invite_by_token returns nil for unknown token" do
    assert Accounts.get_invite_by_token("missing-token") == nil
  end
end

defmodule DashboardSSD.AccountsGetUserTest do
  use DashboardSSD.DataCase, async: false

  alias DashboardSSD.Accounts

  test "get_user!/1 returns the user" do
    role = Accounts.ensure_role!("employee")

    {:ok, user} =
      Accounts.create_user(%{email: "getuser@example.com", name: "G", role_id: role.id})

    assert Accounts.get_user!(user.id).email == "getuser@example.com"
  end

  test "get_user_by_email/1 returns the user when found" do
    role = Accounts.ensure_role!("employee")

    {:ok, user} =
      Accounts.create_user(%{email: "byemail@example.com", name: "ByEmail", role_id: role.id})

    assert Accounts.get_user_by_email("byemail@example.com").id == user.id
  end

  test "get_user_by_email/1 returns nil when not found" do
    assert Accounts.get_user_by_email("nonexistent@example.com") == nil
  end

  test "update_user/2 updates the user" do
    role = Accounts.ensure_role!("employee")

    {:ok, user} =
      Accounts.create_user(%{email: "update@example.com", name: "Update", role_id: role.id})

    {:ok, updated_user} = Accounts.update_user(user, %{name: "Updated Name"})

    assert updated_user.name == "Updated Name"
    assert updated_user.email == "update@example.com"
  end

  test "delete_user/1 deletes the user" do
    role = Accounts.ensure_role!("employee")

    {:ok, user} =
      Accounts.create_user(%{email: "delete@example.com", name: "Delete", role_id: role.id})

    {:ok, deleted_user} = Accounts.delete_user(user)

    assert deleted_user.id == user.id
    assert Accounts.get_user_by_email("delete@example.com") == nil
  end

  test "ensure_role!/1 returns existing role when found" do
    # Create role first
    role1 = Accounts.ensure_role!("existing_role")

    # Call ensure_role! again with same name - should return existing role
    role2 = Accounts.ensure_role!("existing_role")

    assert role1.id == role2.id
  end

  test "ensure_role!/1 creates new role when not found" do
    role = Accounts.ensure_role!("new_role")
    assert role.name == "new_role"
  end

  test "upsert_user_with_identity assigns admin role to first user" do
    # Clear all users and roles to test first user logic
    DashboardSSD.Repo.delete_all(DashboardSSD.Accounts.User)
    DashboardSSD.Repo.delete_all(DashboardSSD.Accounts.Role)

    # First user should get admin role
    user =
      Accounts.upsert_user_with_identity("google", %{
        email: "first@slickage.com",
        name: "First User",
        provider_id: "first-123",
        token: "token",
        refresh_token: "refresh",
        expires_at: DateTime.utc_now()
      })

    # Preload the role association
    user = DashboardSSD.Repo.preload(user, :role)
    assert user.role.name == "admin"
  end
end
