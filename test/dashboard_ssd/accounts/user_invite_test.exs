defmodule DashboardSSD.Accounts.UserInviteTest do
  use ExUnit.Case, async: true

  alias DashboardSSD.Accounts.UserInvite

  test "changeset normalizes email casing" do
    changeset =
      UserInvite.changeset(%UserInvite{}, %{
        email: "Person@Example.COM ",
        token: "token-1",
        role_name: "client"
      })

    assert changeset.valid?
    assert Ecto.Changeset.get_change(changeset, :email) == "person@example.com"
  end

  test "creation_changeset preserves supplied token" do
    changeset =
      UserInvite.creation_changeset(%UserInvite{}, %{
        email: "user@example.com",
        token: "explicit-token",
        role_name: "client"
      })

    assert Ecto.Changeset.get_change(changeset, :token) == "explicit-token"
  end
end
