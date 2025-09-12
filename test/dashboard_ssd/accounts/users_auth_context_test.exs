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

  describe "user CRUD" do
    test "list_users/0 returns users" do
      role = Accounts.ensure_role!("employee")
      {:ok, u1} = Accounts.create_user(%{email: "l1@example.com", name: "L1", role_id: role.id})
      {:ok, u2} = Accounts.create_user(%{email: "l2@example.com", name: "L2", role_id: role.id})

      ids = Accounts.list_users() |> Enum.map(& &1.id) |> Enum.sort()
      assert Enum.sort([u1.id, u2.id]) == ids |> Enum.take(-2)
    end

    test "update_user/2 updates attributes" do
      role = Accounts.ensure_role!("employee")

      {:ok, user} =
        Accounts.create_user(%{email: "upd@example.com", name: "Old", role_id: role.id})

      {:ok, user} = Accounts.update_user(user, %{name: "New"})
      assert user.name == "New"
    end

    test "update_user/2 with invalid data returns error changeset" do
      role = Accounts.ensure_role!("employee")
      {:ok, user} = Accounts.create_user(%{email: "inv@example.com", name: "X", role_id: role.id})

      assert {:error, changeset} = Accounts.update_user(user, %{email: nil})
      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "delete_user/1 removes the user" do
      role = Accounts.ensure_role!("employee")
      {:ok, user} = Accounts.create_user(%{email: "del@example.com", name: "D", role_id: role.id})
      assert {:ok, _} = Accounts.delete_user(user)
      refute Accounts.get_user_by_email("del@example.com")
    end

    test "change_user/2 returns a changeset" do
      role = Accounts.ensure_role!("employee")
      {:ok, user} = Accounts.create_user(%{email: "chg@example.com", name: "C", role_id: role.id})
      cs = Accounts.change_user(user, %{name: "Changed"})
      assert %Ecto.Changeset{} = cs
      assert cs.changes.name == "Changed"
    end
  end
end
