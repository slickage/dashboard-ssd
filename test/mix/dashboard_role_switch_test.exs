defmodule Mix.Tasks.Dashboard.RoleSwitchTest do
  use DashboardSSD.DataCase, async: false

  import ExUnit.CaptureIO

  alias DashboardSSD.Accounts
  alias DashboardSSD.Accounts.User
  alias DashboardSSD.Repo
  alias Mix.Tasks.Dashboard.RoleSwitch

  setup do
    Enum.each(["admin", "employee", "client"], &Accounts.ensure_role!/1)

    {:ok, user} =
      Accounts.create_user(%{
        email: "switch@slickage.com",
        name: "Switch",
        role_id: Accounts.ensure_role!("employee").id
      })

    {:ok, user: Repo.preload(user, :role)}
  end

  test "switches the first user when no email provided", %{user: user} do
    output =
      capture_io(fn ->
        RoleSwitch.run(["--role", "client"])
      end)

    assert output =~ "Updated switch@slickage.com to role client"

    updated = Repo.get!(User, user.id) |> Repo.preload(:role)
    assert updated.role.name == "client"
  end

  test "switches specified email", %{user: user} do
    capture_io(fn ->
      RoleSwitch.run(["--role", "admin", "--email", user.email])
    end)

    updated = Repo.get!(User, user.id) |> Repo.preload(:role)
    assert updated.role.name == "admin"
  end

  test "requires role argument" do
    assert_raise Mix.Error, fn ->
      RoleSwitch.run([])
    end
  end

  test "raises when user cannot be found" do
    assert_raise Mix.Error, fn ->
      RoleSwitch.run(["--role", "client", "--email", "missing@example.com"])
    end
  end

  test "raises when no users exist and email omitted", %{user: user} do
    Repo.delete!(user)

    assert_raise Mix.Error, fn ->
      RoleSwitch.run(["--role", "client"])
    end
  end

  test "prevents execution in production" do
    previous = Application.get_env(:dashboard_ssd, :env)
    Application.put_env(:dashboard_ssd, :env, :prod)

    assert_raise Mix.Error, fn ->
      RoleSwitch.run(["--role", "client"])
    end

    if previous do
      Application.put_env(:dashboard_ssd, :env, previous)
    else
      Application.delete_env(:dashboard_ssd, :env)
    end
  end
end
