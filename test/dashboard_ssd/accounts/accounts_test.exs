defmodule DashboardSSD.AccountsTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.{Accounts, Repo}
  alias DashboardSSD.Accounts.ExternalIdentity

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
        email: "different@example.com",
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
        email: "first@example.com",
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
        email: "first@example.com",
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
end

defmodule DashboardSSD.AccountsGetUserTest do
  use DashboardSSD.DataCase, async: true

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
        email: "first@example.com",
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
