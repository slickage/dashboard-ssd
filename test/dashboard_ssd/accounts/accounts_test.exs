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
end
