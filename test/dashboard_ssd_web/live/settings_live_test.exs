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

  test "shows google not connected when no identity exists", %{conn: conn} do
    {:ok, user} =
      Accounts.create_user(%{
        email: "no-google@example.com",
        name: "No Google",
        role_id: Accounts.ensure_role!("admin").id
      })

    # Set other tokens but no google identity
    Application.put_env(:dashboard_ssd, :integrations,
      linear_token: "lin-123",
      slack_bot_token: "xoxb-123",
      notion_token: "not-123"
    )

    conn = init_test_session(conn, %{user_id: user.id})
    {:ok, _view, html} = live(conn, ~p"/settings")

    # Google shows connect link
    assert html =~ "Connect Google"
    # Others show connected
    assert html =~ "Configured via LINEAR_TOKEN"
    assert html =~ "App token configured"
    assert html =~ "Integration token active"
  end

  test "handle_event toggles mobile menu", %{conn: conn} do
    {:ok, user} =
      Accounts.create_user(%{
        email: "mobile@example.com",
        name: "Mobile",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = init_test_session(conn, %{user_id: user.id})
    {:ok, view, _html} = live(conn, ~p"/settings")

    view |> element("button[phx-click='toggle_mobile_menu']") |> render_click()

    assigns = view.pid |> :sys.get_state() |> Map.fetch!(:socket) |> Map.fetch!(:assigns)
    assert assigns.mobile_menu_open == true

    view |> element("button[phx-click='close_mobile_menu']") |> render_click()

    assigns = view.pid |> :sys.get_state() |> Map.fetch!(:socket) |> Map.fetch!(:assigns)
    assert assigns.mobile_menu_open == false
  end

  test "handle_event toggle_theme does nothing", %{conn: conn} do
    {:ok, user} =
      Accounts.create_user(%{
        email: "theme@example.com",
        name: "Theme",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = init_test_session(conn, %{user_id: user.id})
    {:ok, view, _html} = live(conn, ~p"/settings")

    view |> element("button[phx-click='toggle_theme']") |> render_click()

    # No change expected
  end
end
