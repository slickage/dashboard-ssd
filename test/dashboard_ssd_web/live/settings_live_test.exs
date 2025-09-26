defmodule DashboardSSDWeb.SettingsLiveTest do
  use DashboardSSDWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts
  alias DashboardSSD.Accounts.ExternalIdentity
  alias DashboardSSD.Repo

  setup do
    Accounts.ensure_role!("admin")
    prev = Application.get_env(:dashboard_ssd, :integrations)

    on_exit(fn ->
      if prev,
        do: Application.put_env(:dashboard_ssd, :integrations, prev),
        else: Application.delete_env(:dashboard_ssd, :integrations)
    end)

    :ok
  end

  test "shows not connected states and connect links when tokens missing", %{conn: conn} do
    {:ok, user} =
      Accounts.create_user(%{
        email: "s1@example.com",
        name: "S1",
        role_id: Accounts.ensure_role!("admin").id
      })

    # Clear integration tokens
    Application.put_env(:dashboard_ssd, :integrations,
      linear_token: nil,
      slack_bot_token: nil,
      slack_channel: nil,
      notion_token: nil,
      drive_token: nil
    )

    conn = init_test_session(conn, %{user_id: user.id})
    {:ok, _view, html} = live(conn, ~p"/settings")

    assert html =~ "Settings"

    # Google shows connect link
    assert html =~ "Connect Google"

    # Other integrations show guidance
    assert html =~ "LINEAR_TOKEN"
    assert html =~ "SLACK_BOT_TOKEN"
    assert html =~ "NOTION_TOKEN"
  end

  test "shows connected states when tokens and google identity present", %{conn: conn} do
    {:ok, user} =
      Accounts.create_user(%{
        email: "s2@example.com",
        name: "S2",
        role_id: Accounts.ensure_role!("admin").id
      })

    # Insert a Google identity with a token
    _ =
      %ExternalIdentity{}
      |> ExternalIdentity.changeset(%{
        user_id: user.id,
        provider: "google",
        provider_id: "pid-123",
        token: "tok-xyz"
      })
      |> Repo.insert!()

    # Set integration tokens
    Application.put_env(:dashboard_ssd, :integrations,
      linear_token: "lin-123",
      slack_bot_token: "xoxb-123",
      slack_channel: "#general",
      notion_token: "not-123",
      drive_token: nil
    )

    conn = init_test_session(conn, %{user_id: user.id})
    {:ok, _view, html} = live(conn, ~p"/settings")

    # All present show Connected
    assert html =~ "Connected"
    refute html =~ "Connect Google"
  end
end
