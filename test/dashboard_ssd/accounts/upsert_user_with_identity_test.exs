defmodule DashboardSSD.Accounts.UpsertUserWithIdentityTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Accounts

  setup do
    prev = Application.get_env(:dashboard_ssd, DashboardSSD.Accounts)

    Application.put_env(:dashboard_ssd, DashboardSSD.Accounts,
      slickage_allowed_domains: ["slickage.com"]
    )

    Enum.each(["admin", "employee", "client"], &Accounts.ensure_role!/1)

    on_exit(fn ->
      if prev,
        do: Application.put_env(:dashboard_ssd, DashboardSSD.Accounts, prev),
        else: Application.delete_env(:dashboard_ssd, DashboardSSD.Accounts)
    end)

    :ok
  end

  test "allows Slickage domains" do
    user =
      Accounts.upsert_user_with_identity("google", %{
        email: "person@slickage.com",
        name: "Person",
        provider_id: "pid-1",
        token: "tok"
      })

    assert user.email == "person@slickage.com"
  end

  test "blocks new external domains until invited" do
    assert_raise DashboardSSD.Accounts.DomainNotAllowedError, fn ->
      Accounts.upsert_user_with_identity("google", %{
        email: "guest@example.org",
        name: "Guest",
        provider_id: "pid-2",
        token: "tok"
      })
    end
  end

  test "lets invited clients from external domains sign in" do
    client_role = Accounts.ensure_role!("client")

    {:ok, invited} =
      Accounts.create_user(%{
        email: "invited@example.org",
        name: "Invited",
        role_id: client_role.id
      })

    user =
      Accounts.upsert_user_with_identity("google", %{
        email: invited.email,
        name: invited.name,
        provider_id: "pid-3",
        token: "tok"
      })

    assert user.id == invited.id
  end
end
