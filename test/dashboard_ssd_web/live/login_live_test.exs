defmodule DashboardSSDWeb.LoginLiveTest do
  use DashboardSSDWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts

  setup do
    Accounts.ensure_role!("admin")
    :ok
  end

  describe "mount/3" do
    test "redirects to home when user is already logged in", %{conn: conn} do
      {:ok, user} = Accounts.create_user(%{email: "test@example.com", name: "Test User"})

      conn = init_test_session(conn, %{user_id: user.id})

      assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/login")
    end

    test "renders login page when user is not logged in", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/login")

      assert html =~ "Welcome to DashboardSSD"
      assert html =~ "Sign in to access your dashboard"
      assert html =~ "Continue with Google"
    end

    test "stores redirect_to from URL params", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/login?redirect_to=/some/path")

      # Check that the redirect_to is stored by testing the oauth URL generation
      lv
      |> element("button[phx-click=start_oauth]")
      |> render_click()

      assert_push_event(lv, "open_oauth_popup", %{url: url})
      assert url =~ "redirect_to=%2Fsome%2Fpath"
    end
  end

  describe "handle_event/2" do
    test "start_oauth event pushes open_oauth_popup event", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/login")

      lv
      |> element("button[phx-click=start_oauth]")
      |> render_click()

      assert_push_event(lv, "open_oauth_popup", %{url: url})
      assert url =~ "/auth/google"
      assert url =~ "popup=true"
    end

    test "start_oauth includes redirect_to in URL when present", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/login?redirect_to=/dashboard")

      lv
      |> element("button[phx-click=start_oauth]")
      |> render_click()

      assert_push_event(lv, "open_oauth_popup", %{url: url})
      assert url =~ "redirect_to=%2Fdashboard"
    end
  end
end
