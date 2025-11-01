defmodule DashboardSSDWeb.ProjectsLiveLinearTest do
  use DashboardSSDWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  alias DashboardSSD.Accounts
  alias DashboardSSD.{Clients, Projects}

  setup do
    Accounts.ensure_role!("admin")
    prev = Application.get_env(:dashboard_ssd, :integrations)
    prev_summary = Application.get_env(:dashboard_ssd, :linear_summary_in_test?)

    Application.put_env(
      :dashboard_ssd,
      :integrations,
      Keyword.merge(prev || [], linear_token: "tok")
    )

    Application.put_env(:tesla, :adapter, Tesla.Mock)
    Application.put_env(:dashboard_ssd, :linear_summary_in_test?, true)

    on_exit(fn ->
      if prev,
        do: Application.put_env(:dashboard_ssd, :integrations, prev),
        else: Application.delete_env(:dashboard_ssd, :integrations)

      if is_nil(prev_summary) do
        Application.delete_env(:dashboard_ssd, :linear_summary_in_test?)
      else
        Application.put_env(:dashboard_ssd, :linear_summary_in_test?, prev_summary)
      end
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

    {:ok, _p} =
      Projects.create_project(%{
        name: "Acme Website",
        client_id: c.id,
        linear_project_id: "proj-1",
        linear_team_id: "team-1"
      })

    mock_linear_summary_success()

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, view, _html} = live(conn, ~p"/projects")

    # Trigger summary loading through the UI
    view |> element("button", "Sync from Linear") |> render_click()
    html = render(view)

    # Should display computed totals via data attributes
    assert html =~ ~s/data-total="3"/
    assert html =~ ~s/data-in-progress="1"/
    assert html =~ ~s/data-finished="2"/
    assert html =~ "Alice"
    assert html =~ "(2)"
    assert html =~ "Bob"
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

    log =
      capture_log(fn ->
        view |> element("button", "Sync from Linear") |> render_click()
        html = render(view)
        send(self(), {:linear_html, html})
      end)

    assert log =~ "Linear sync failed"
    assert_receive {:linear_html, html}
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

    {:ok, _p} =
      Projects.create_project(%{
        name: "Acme Ops",
        client_id: c.id,
        linear_project_id: "proj-1",
        linear_team_id: "team-1"
      })

    mock_linear_summary_empty()

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, view, _html} = live(conn, ~p"/projects")

    view |> element("button", "Sync from Linear") |> render_click()
    html = render(view)

    assert html =~ ~s/data-total="0"/
    assert html =~ ~s/data-in-progress="0"/
    assert html =~ ~s/data-finished="0"/
  end

  test "reload keeps previous summaries when Linear errors", %{conn: conn} do
    {:ok, adm} =
      Accounts.create_user(%{
        email: "adm-linear4@example.com",
        name: "A",
        role_id: Accounts.ensure_role!("admin").id
      })

    {:ok, c} = Clients.create_client(%{name: "Acme"})

    {:ok, _p} =
      Projects.create_project(%{
        name: "Acme Support",
        client_id: c.id,
        linear_project_id: "proj-keep",
        linear_team_id: "team-keep"
      })

    mode_agent = start_supervised!({Agent, fn -> :success end})

    mock_linear_summary_with_agent(mode_agent, [
      %{"state" => %{"id" => "state-done", "name" => "Done", "type" => "completed"}},
      %{
        "state" => %{"id" => "state-progress", "name" => "In Progress", "type" => "started"}
      }
    ])

    conn = init_test_session(conn, %{user_id: adm.id})
    {:ok, view, _html} = live(conn, ~p"/projects")

    view |> element("button", "Sync from Linear") |> render_click()
    html = render(view)
    assert html =~ ~s/data-total="2"/
    assert html =~ ~s/data-in-progress="1"/
    assert html =~ ~s/data-finished="1"/

    Agent.update(mode_agent, fn _ -> :error end)

    log =
      capture_log(fn ->
        view |> element("button", "Sync from Linear") |> render_click()
        html_cached = render(view)
        send(self(), {:cached_html, html_cached})
      end)

    assert log =~ "Linear sync failed"
    assert_receive {:cached_html, html_cached}
    assert html_cached =~ ~s/data-total="2"/
    assert html_cached =~ ~s/data-in-progress="1"/
    assert html_cached =~ ~s/data-finished="1"/
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

    log =
      capture_log(fn ->
        view |> element("button", "Sync from Linear") |> render_click()
        send(self(), {:sync_html, render(view)})
      end)

    assert log =~ "Linear sync failed"
    assert_receive {:sync_html, html_after}
    assert html_after =~ "Linear sync failed"
  end

  defp mock_linear_summary_success do
    linear_summary_mock(issue_nodes())
  end

  defp mock_linear_summary_empty do
    linear_summary_mock([])
  end

  defp mock_linear_summary_with_agent(agent, nodes) do
    Tesla.Mock.mock(fn %{method: :post, url: "https://api.linear.app/graphql"} = env ->
      case Agent.get(agent, & &1) do
        :success ->
          linear_api_response(env, nodes)

        :error ->
          %Tesla.Env{status: 500, body: %{"errors" => ["oops"]}}
      end
    end)
  end

  defp linear_summary_mock(nodes) do
    Tesla.Mock.mock(fn %{method: :post, url: "https://api.linear.app/graphql"} = env ->
      linear_api_response(env, nodes)
    end)
  end

  defp linear_api_response(env, nodes) do
    payload = decode_graphql(env)
    query = payload["query"] || ""
    variables = Map.get(payload, "variables", %{})

    cond do
      String.contains?(query, "TeamsPage") ->
        teams_response()

      String.contains?(query, "TeamProjects") ->
        team_projects_response(variables)

      String.contains?(query, "IssuesByProjectId") ->
        issue_nodes_response(nodes, variables)

      String.contains?(query, "IssueSearch") ->
        issue_search_response(nodes)

      true ->
        flunk("Unexpected Linear query: #{query} with vars #{inspect(variables)}")
    end
  end

  defp teams_response do
    %Tesla.Env{
      status: 200,
      body: %{
        "data" => %{
          "teams" => %{
            "nodes" => [%{"id" => "team-1", "name" => "Demo Team"}],
            "pageInfo" => %{"hasNextPage" => false}
          }
        }
      }
    }
  end

  defp team_projects_response(variables) do
    team_id = Map.get(variables, "teamId", "team-1")

    %Tesla.Env{
      status: 200,
      body: %{
        "data" => %{
          "team" => %{
            "id" => team_id,
            "name" => "Demo Team",
            "projects" => %{
              "nodes" => [%{"id" => "proj-1", "name" => "Acme Website"}],
              "pageInfo" => %{"hasNextPage" => false}
            },
            "states" => %{
              "nodes" => [
                %{"id" => "state-done", "name" => "Done", "type" => "completed"},
                %{"id" => "state-progress", "name" => "In Progress", "type" => "started"},
                %{"id" => "state-todo", "name" => "Todo", "type" => "backlog"}
              ]
            },
            "teamMemberships" => %{"nodes" => []},
            "members" => %{"nodes" => []}
          }
        }
      }
    }
  end

  defp issue_nodes_response(nodes, variables) do
    project_id = Map.get(variables, "projectId", "proj-1")

    %Tesla.Env{
      status: 200,
      body: %{
        "data" => %{
          "issues" => %{
            "nodes" =>
              Enum.map(nodes, fn node ->
                Map.update(node, "state", %{}, fn state ->
                  Map.put_new(state, "id", Map.get(state, "id") || "#{project_id}-state")
                end)
              end),
            "pageInfo" => %{"hasNextPage" => false}
          }
        }
      }
    }
  end

  defp issue_search_response(nodes) do
    %Tesla.Env{
      status: 200,
      body: %{
        "data" => %{
          "issueSearch" => %{
            "nodes" => nodes
          }
        }
      }
    }
  end

  defp issue_nodes do
    [
      %{
        "state" => %{"id" => "state-done", "name" => "Done", "type" => "completed"},
        "assignee" => %{"id" => "user-1", "displayName" => "Alice"}
      },
      %{
        "state" => %{
          "id" => "state-progress",
          "name" => "In Progress",
          "type" => "started"
        },
        "assignee" => %{"id" => "user-1", "displayName" => "Alice"}
      },
      %{
        "state" => %{"id" => "state-closed", "name" => "Closed", "type" => "completed"},
        "assignee" => %{"id" => "user-2", "displayName" => "Bob"}
      }
    ]
  end

  defp decode_graphql(%{body: body}) do
    if is_binary(body), do: Jason.decode!(body), else: body
  end
end
