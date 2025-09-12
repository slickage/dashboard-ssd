defmodule DashboardSSD.Accounts.UsersAuthContextTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Accounts
  alias DashboardSSD.Accounts.{Role, User}

  setup do
    Accounts.ensure_role!("employee")
    :ok
  end

  test "create_user/1 inserts a user with valid attrs" do
    role = Accounts.ensure_role!("employee")

    {:ok, user} =
      Accounts.create_user(%{email: "user1@example.com", name: "U1", role_id: role.id})

    assert %User{id: id} = user
    assert id
    assert user.email == "user1@example.com"
  end

  test "create_user/1 requires email" do
    assert {:error, changeset} = Accounts.create_user(%{name: "NoEmail"})
    assert %{email: ["can't be blank"]} = errors_on(changeset)
  end

  test "unique_constraint on email prevents duplicates" do
    role = Accounts.ensure_role!("employee")
    {:ok, _} = Accounts.create_user(%{email: "dupe@example.com", name: "One", role_id: role.id})

    assert {:error, changeset} =
             Accounts.create_user(%{email: "dupe@example.com", name: "Two", role_id: role.id})

    assert %{email: ["has already been taken"]} = errors_on(changeset)
  end

  test "get_user_by_email/1 returns user or nil" do
    refute Accounts.get_user_by_email("missing@example.com")
    role = Accounts.ensure_role!("employee")
    {:ok, user} = Accounts.create_user(%{email: "found@example.com", name: "F", role_id: role.id})
    assert %User{id: id} = Accounts.get_user_by_email("found@example.com")
    assert id == user.id
  end

  test "ensure_role!/1 returns an existing role or creates it" do
    r1 = Accounts.ensure_role!("custom")
    assert %Role{name: "custom"} = r1
    r2 = Accounts.ensure_role!("custom")
    assert r1.id == r2.id
  end
end
