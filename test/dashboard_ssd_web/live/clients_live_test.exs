defmodule DashboardSSDWeb.ClientsLiveTest do
  use DashboardSSDWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts
  alias DashboardSSD.Clients

  setup do
    Accounts.ensure_role!("admin")
    Accounts.ensure_role!("employee")
    :ok
  end

  test "admin sees clients list", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "adm@example.com",
        name: "A",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, _} = Clients.create_client(%{name: "Acme"})
    {:ok, _} = Clients.create_client(%{name: "Globex"})

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, _view, html} = live(conn, ~p"/clients")

    assert html =~ "Clients"
    assert html =~ "Acme"
    assert html =~ "Globex"
  end

  test "employee is redirected with forbidden", %{conn: conn} do
    {:ok, emp} =
      Accounts.create_user(%{
        email: "emp@example.com",
        name: "E",
        role_id: Accounts.ensure_role!("employee").id
      })

    conn = init_test_session(conn, %{user_id: emp.id})
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/clients")
  end

  test "anonymous is redirected", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/login?redirect_to=%2Fclients"}}} =
             live(conn, ~p"/clients")
  end

  test "admin can create and edit client via modal", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "adm@example.com",
        name: "A",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, _view, _} = live(conn, ~p"/clients")

    # New modal
    {:ok, view, _} = live(conn, ~p"/clients/new")
    form = element(view, "#client-form")
    render_change(form, %{"client" => %{"name" => "NewCo"}})
    render_submit(form, %{"client" => %{"name" => "NewCo"}})
    assert_patch(view, ~p"/clients")
    html = render(view)
    assert html =~ "NewCo"

    # Edit modal
    {:ok, c} = Clients.create_client(%{name: "Acme"})
    {:ok, view, _} = live(conn, ~p"/clients/#{c.id}/edit")
    form = element(view, "#client-form")
    render_change(form, %{"client" => %{"name" => "Renamed"}})
    render_submit(form, %{"client" => %{"name" => "Renamed"}})
    assert_patch(view, ~p"/clients")
    html = render(view)
    assert html =~ "Renamed"
  end

  test "client form shows validation error on empty name", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "adm-cvalid@example.com",
        name: "A",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, view, _} = live(conn, ~p"/clients/new")
    form = element(view, "#client-form")
    render_submit(form, %{"client" => %{"name" => ""}})
    assert render(view) =~ "can&#39;t be blank"
  end

  test "client edit forbidden for non-admin", %{conn: conn} do
    {:ok, emp} =
      Accounts.create_user(%{
        email: "emp-cforbid@example.com",
        name: "E",
        role_id: Accounts.ensure_role!("employee").id
      })

    {:ok, c} = Clients.create_client(%{name: "Acme"})
    conn = init_test_session(conn, %{user_id: emp.id})
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/clients/#{c.id}/edit")
  end

  test "mobile menu toggle works", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "adm-mobile@example.com",
        name: "A",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, view, _html} = live(conn, ~p"/clients")

    # Toggle mobile menu open
    view
    |> element("button[phx-click='toggle_mobile_menu']")
    |> render_click()

    # Close mobile menu by clicking the close button
    view
    |> element("button[phx-click='close_mobile_menu']")
    |> render_click()
  end

  test "admin can delete client via modal", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "adm-delete@example.com",
        name: "A",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, client} = Clients.create_client(%{name: "DeleteMe"})

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, _view, _html} = live(conn, ~p"/clients")

    # Navigate to delete modal
    {:ok, view, _} = live(conn, ~p"/clients/#{client.id}/delete")

    # Verify modal shows
    html = render(view)
    assert html =~ "Delete Client"
    assert html =~ "DeleteMe"
    assert html =~ "This action cannot be undone"

    # Confirm delete
    view
    |> element("button[phx-click='delete_client']")
    |> render_click()

    # Should redirect back to clients list
    assert_redirect(view, ~p"/clients")

    # Verify client was deleted
    assert Clients.list_clients() == []
  end

  test "delete modal shows with proper content", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "adm-modal@example.com",
        name: "A",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, client} = Clients.create_client(%{name: "TestClient"})

    conn = init_test_session(conn, %{user_id: adm.id})

    # Navigate to delete modal
    {:ok, view, _} = live(conn, ~p"/clients/#{client.id}/delete")

    # Verify modal content
    html = render(view)
    assert html =~ "Delete Client"
    assert html =~ "TestClient"
    assert html =~ "This action cannot be undone"
    # button text
    assert html =~ "Delete Client"

    # Modal should have close button for cancellation
    assert html =~ "aria-label=\"close\""
  end
end
