defmodule DashboardSSDWeb.ProjectsLiveLinearTest do
  use DashboardSSDWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts
  alias DashboardSSD.{Clients, Projects}

  setup do
    Accounts.ensure_role!("admin")
    prev = Application.get_env(:dashboard_ssd, :integrations)

    Application.put_env(
      :dashboard_ssd,
      :integrations,
      Keyword.merge(prev || [], linear_token: "tok")
    )

    Application.put_env(:tesla, :adapter, Tesla.Mock)

    on_exit(fn ->
      if prev,
        do: Application.put_env(:dashboard_ssd, :integrations, prev),
        else: Application.delete_env(:dashboard_ssd, :integrations)
    end)

    :ok
  end

  test "shows Linear task breakdown when enabled", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "adm-linear@example.com",
        name: "A",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, c} = Clients.create_client(%{name: "Acme"})
    {:ok, _p} = Projects.create_project(%{name: "Acme Website", client_id: c.id})

    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.linear.app/graphql", headers: headers} ->
        # token set without Bearer by our integration
        assert Enum.any?(headers, fn {k, v} -> k == "authorization" and v == "tok" end)

        %Tesla.Env{
          status: 200,
          body: %{
            "data" => %{
              "issueSearch" => %{
                "nodes" => [
                  %{"state" => %{"name" => "Done"}},
                  %{"state" => %{"name" => "In Progress"}},
                  %{"state" => %{"name" => "Closed"}}
                ]
              }
            }
          }
        }
    end)

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, view, _html} = live(conn, ~p"/projects")

    # Trigger async summary loading
    send(view.pid, :reload_summaries)
    html = render(view)

    # Should display computed totals via data attributes
    assert html =~ ~s/data-total="3"/
    assert html =~ ~s/data-in-progress="1"/
    assert html =~ ~s/data-finished="2"/
  end

  test "shows N/A when Linear response unavailable", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "adm-linear2@example.com",
        name: "A",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, c} = Clients.create_client(%{name: "Acme"})
    {:ok, _p} = Projects.create_project(%{name: "Acme Marketing", client_id: c.id})

    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.linear.app/graphql"} ->
        %Tesla.Env{status: 500, body: %{"errors" => ["oops"]}}
    end)

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, view, _html} = live(conn, ~p"/projects")

    # Trigger async summary loading
    send(view.pid, :reload_summaries)
    html = render(view)

    assert html =~ "N/A"
  end

  test "shows totals 0 when Linear returns empty list", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "adm-linear3@example.com",
        name: "A",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, c} = Clients.create_client(%{name: "Acme"})
    {:ok, _p} = Projects.create_project(%{name: "Acme Ops", client_id: c.id})

    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.linear.app/graphql"} ->
        %Tesla.Env{status: 200, body: %{"data" => %{"issueSearch" => %{"nodes" => []}}}}
    end)

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, view, _html} = live(conn, ~p"/projects")

    # Trigger async summary loading
    send(view.pid, :reload_summaries)
    html = render(view)

    assert html =~ ~s/data-total="0"/
    assert html =~ ~s/data-in-progress="0"/
    assert html =~ ~s/data-finished="0"/
  end

  test "sync button flashes error on failure", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "adm-syncerr@example.com",
        name: "A",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, _c} = Clients.create_client(%{name: "Acme"})
    {:ok, _p} = Projects.create_project(%{name: "Acme Web"})

    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.linear.app/graphql"} ->
        %Tesla.Env{status: 500, body: %{"errors" => ["oops"]}}
    end)

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, view, html} = live(conn, ~p"/projects")
    assert html =~ "Sync from Linear"
    # Click sync
    view |> element("button", "Sync from Linear") |> render_click()
    # Should show error flash
    assert render(view) =~ "Linear sync failed"
  end

  test "reload tasks button triggers info flash", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "adm-reload@example.com",
        name: "A",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, c} = Clients.create_client(%{name: "Acme"})
    {:ok, _p} = Projects.create_project(%{name: "Acme Web", client_id: c.id})

    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.linear.app/graphql"} ->
        %Tesla.Env{status: 200, body: %{"data" => %{"issueSearch" => %{"nodes" => []}}}}
    end)

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, view, html} = live(conn, ~p"/projects")
    assert html =~ "Reload Tasks"

    view |> element("button", "Reload Tasks") |> render_click()

    assert render(view) =~ "Tasks reloaded successfully"
  end
end
