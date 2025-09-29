defmodule DashboardSSDWeb.ProjectsHealthChecksLiveTest do
  use DashboardSSDWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts
  alias DashboardSSD.{Clients, Deployments, Projects}

  setup do
    Accounts.ensure_role!("admin")
    # Disable Linear to avoid external calls in these UI tests
    prev = Application.get_env(:dashboard_ssd, :integrations)

    Application.put_env(
      :dashboard_ssd,
      :integrations,
      Keyword.merge(prev || [], linear_token: nil)
    )

    on_exit(fn ->
      if prev,
        do: Application.put_env(:dashboard_ssd, :integrations, prev),
        else: Application.delete_env(:dashboard_ssd, :integrations)
    end)

    :ok
  end

  test "AWS settings save (enabled) but no dot until a status exists", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "a6@x.com",
        name: "A6",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, c} = Clients.create_client(%{name: "Umbrella2"})
    {:ok, p} = Projects.create_project(%{name: "SrvC", client_id: c.id})

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, view, _} = live(conn, ~p"/projects/#{p.id}/edit")
    form = element(view, "#project-form")

    render_submit(form, %{
      "project" => %{"name" => "SrvC", "client_id" => to_string(c.id)},
      "hc" => %{
        "enabled" => "on",
        "provider" => "aws_elbv2",
        "aws_region" => "us-east-1",
        "aws_target_group_arn" => "arn:aws:elasticloadbalancing:...:targetgroup/..."
      }
    })

    # Modal should close and project should be updated in place
    # No status inserted yet -> shows em dash
    html = render(view)
    assert html =~ ">—<"
    # Modal should be closed
    refute html =~ "Edit Project"
  end

  test "Linear summaries are skipped in tests unless Tesla.Mock set" do
    # Ensure linear is configured but adapter is not Tesla.Mock
    prev = Application.get_env(:tesla, :adapter)
    Application.put_env(:tesla, :adapter, Finch)
    on_exit(fn -> Application.put_env(:tesla, :adapter, prev) end)

    {:ok, c} = Clients.create_client(%{name: "AcmeZ"})
    {:ok, _p} = Projects.create_project(%{name: "Zed", client_id: c.id})

    # Just mount the view; with no Tesla.Mock, summaries should be :unavailable → N/A
    {:ok, adm} =
      Accounts.create_user(%{
        email: "a7@x.com",
        name: "A7",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = build_conn() |> init_test_session(%{user_id: adm.id})
    {:ok, _view, html} = live(conn, ~p"/projects")
    assert html =~ "N/A"
  end

  test "Prod shows — when disabled even if status exists", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "a@x.com",
        name: "A",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, c} = Clients.create_client(%{name: "Acme"})
    {:ok, p} = Projects.create_project(%{name: "Site", client_id: c.id})

    # Existing status but settings disabled
    {:ok, _} = Deployments.create_health_check(%{project_id: p.id, status: "up"})

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, _view, html} = live(conn, ~p"/projects")
    assert html =~ ">—<"
  end

  test "enabling HTTP with empty URL remains disabled and shows —", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "a2@x.com",
        name: "A2",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, c} = Clients.create_client(%{name: "Globex"})
    {:ok, p} = Projects.create_project(%{name: "App", client_id: c.id})

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, view, _} = live(conn, ~p"/projects/#{p.id}/edit")

    form = element(view, "#project-form")

    render_submit(form, %{
      "project" => %{"name" => "App", "client_id" => to_string(c.id)},
      "hc" => %{"enabled" => "on", "provider" => "http", "http_url" => ""}
    })

    # Modal should close and project should be updated in place
    html = render(view)
    assert html =~ ">—<"
    # Modal should be closed
    refute html =~ "Edit Project"

    # And setting should be disabled
    s = Deployments.get_health_check_setting_by_project(p.id)
    refute s.enabled
  end

  test "validate keeps HC enable checkbox state after first click", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "a5@x.com",
        name: "A5",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, p} = Projects.create_project(%{name: "X"})

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, view, _} = live(conn, ~p"/projects/#{p.id}/edit")
    form = element(view, "#project-form")
    # Toggle enable ON without other fields
    render_change(form, %{"hc" => %{"enabled" => "on"}, "project" => %{"name" => "X"}})
    html = render(view)
    assert html =~ ~s(name=\"hc[enabled]\" checked)
  end

  test "enabling HTTP with URL shows dot (when status exists) and disabling clears it", %{
    conn: conn
  } do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "a3@x.com",
        name: "A3",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, c} = Clients.create_client(%{name: "Initrode"})
    {:ok, p} = Projects.create_project(%{name: "Srv", client_id: c.id})

    # Pre-existing status
    {:ok, _} = Deployments.create_health_check(%{project_id: p.id, status: "up"})

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, view, _} = live(conn, ~p"/projects/#{p.id}/edit")

    form = element(view, "#project-form")

    render_submit(form, %{
      "project" => %{"name" => "Srv", "client_id" => to_string(c.id)},
      "hc" => %{"enabled" => "on", "provider" => "http", "http_url" => "http://example/health"}
    })

    # Modal should close and project should be updated in place
    html = render(view)
    # Dot (green) should be present for "up"
    assert html =~ "bg-emerald-400"
    # Modal should be closed
    refute html =~ "Edit Project"

    # Now disable
    {:ok, view3, _} = live(conn, ~p"/projects/#{p.id}/edit")
    form2 = element(view3, "#project-form")

    render_submit(form2, %{
      "project" => %{"name" => "Srv", "client_id" => to_string(c.id)},
      "hc" => %{"provider" => "http", "http_url" => "http://example/health"}
    })

    # Modal should close and project should be updated in place
    html2 = render(view3)
    assert html2 =~ ">—<"
    # Modal should be closed
    refute html2 =~ "Edit Project"
  end

  test "dot colors reflect status (degraded amber, down red)", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "a4@x.com",
        name: "A4",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, c} = Clients.create_client(%{name: "Umbrella"})
    {:ok, p1} = Projects.create_project(%{name: "SrvA", client_id: c.id})
    {:ok, p2} = Projects.create_project(%{name: "SrvB", client_id: c.id})

    # Pre-existing statuses and enabled settings
    {:ok, _} = Deployments.create_health_check(%{project_id: p1.id, status: "degraded"})
    {:ok, _} = Deployments.create_health_check(%{project_id: p2.id, status: "down"})

    {:ok, _} =
      Deployments.upsert_health_check_setting(p1.id, %{
        enabled: true,
        provider: "http",
        endpoint_url: "http://example/a"
      })

    {:ok, _} =
      Deployments.upsert_health_check_setting(p2.id, %{
        enabled: true,
        provider: "http",
        endpoint_url: "http://example/b"
      })

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, _view, html} = live(conn, ~p"/projects")
    assert html =~ "bg-amber-400"
    assert html =~ "bg-rose-400"
  end
end
