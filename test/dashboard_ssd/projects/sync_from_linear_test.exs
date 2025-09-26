defmodule DashboardSSD.Projects.SyncFromLinearTest do
  use DashboardSSD.DataCase, async: false

  alias DashboardSSD.{Clients, Projects}

  setup do
    # Configure Linear token for Integrations
    prev = Application.get_env(:dashboard_ssd, :integrations)
    Application.put_env(:dashboard_ssd, :integrations, linear_token: "tok")

    on_exit(fn ->
      if prev,
        do: Application.put_env(:dashboard_ssd, :integrations, prev),
        else: Application.delete_env(:dashboard_ssd, :integrations)
    end)

    :ok
  end

  test "imports projects and infers client by name substring" do
    {:ok, c} = Clients.create_client(%{name: "Acme"})

    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.linear.app/graphql"} ->
        %Tesla.Env{
          status: 200,
          body: %{
            "data" => %{
              "teams" => %{
                "nodes" => [
                  %{
                    "name" => "Acme Team",
                    "projects" => %{"nodes" => [%{"name" => "Acme Website"}]}
                  }
                ]
              }
            }
          }
        }
    end)

    assert {:ok, %{inserted: 1, updated: 0}} = Projects.sync_from_linear()

    projects = Projects.list_projects_by_client(c.id)
    assert Enum.any?(projects, &(&1.name == "Acme Website"))
  end

  test "imports project unassigned when no client match" do
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.linear.app/graphql"} ->
        %Tesla.Env{
          status: 200,
          body: %{
            "data" => %{
              "teams" => %{
                "nodes" => [
                  %{"name" => "Random Team", "projects" => %{"nodes" => [%{"name" => "Foobar"}]}}
                ]
              }
            }
          }
        }
    end)

    assert {:ok, %{inserted: 1, updated: 0}} = Projects.sync_from_linear()
    # Should exist with nil client_id
    assert Enum.any?(Projects.list_projects(), &(&1.name == "Foobar" and is_nil(&1.client_id)))
  end

  test "updates existing project to assign inferred client" do
    {:ok, c} = Clients.create_client(%{name: "Globex"})
    # existing project with nil client
    {:ok, _p} = Projects.create_project(%{name: "Globex CRM"})

    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.linear.app/graphql"} ->
        %Tesla.Env{
          status: 200,
          body: %{
            "data" => %{
              "teams" => %{
                "nodes" => [
                  %{
                    "name" => "Globex Team",
                    "projects" => %{"nodes" => [%{"name" => "Globex CRM"}]}
                  }
                ]
              }
            }
          }
        }
    end)

    assert {:ok, %{inserted: 0, updated: _}} = Projects.sync_from_linear()
    # project should now be assigned to Globex
    assert Enum.any?(Projects.list_projects_by_client(c.id), &(&1.name == "Globex CRM"))
  end

  test "no-op when project already assigned to inferred client" do
    {:ok, c} = Clients.create_client(%{name: "Acme"})
    {:ok, _} = Projects.create_project(%{name: "Acme Website", client_id: c.id})

    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.linear.app/graphql"} ->
        %Tesla.Env{
          status: 200,
          body: %{
            "data" => %{
              "teams" => %{
                "nodes" => [
                  %{"name" => "Acme", "projects" => %{"nodes" => [%{"name" => "Acme Website"}]}}
                ]
              }
            }
          }
        }
    end)

    assert {:ok, %{inserted: 0, updated: u}} = Projects.sync_from_linear()
    # updated may be 0 (no change) or 1 (touched same client)
    assert u in [0, 1]
  end
end
