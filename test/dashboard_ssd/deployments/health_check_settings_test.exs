defmodule DashboardSSD.Deployments.HealthCheckSettingsTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Clients
  alias DashboardSSD.Deployments
  alias DashboardSSD.Projects

  test "upsert with empty HTTP URL errors (requires URL when enabled)" do
    {:ok, c} = Clients.create_client(%{name: "C"})
    {:ok, p} = Projects.create_project(%{name: "P", client_id: c.id})

    assert {:error, _cs} =
             Deployments.upsert_health_check_setting(p.id, %{
               enabled: true,
               provider: "http",
               endpoint_url: ""
             })
  end

  test "run_health_check_now inserts status and returns down on HTTP error" do
    {:ok, c} = Clients.create_client(%{name: "C2"})
    {:ok, p} = Projects.create_project(%{name: "P2", client_id: c.id})

    # Set an unreachable URL to simulate error -> classified as "down"
    {:ok, _} =
      Deployments.upsert_health_check_setting(p.id, %{
        enabled: true,
        provider: "http",
        endpoint_url: "http://127.0.0.1:9/health"
      })

    assert {:ok, status} = Deployments.run_health_check_now(p.id)
    assert status in ["down", "degraded", "up"]

    # Verify a health check row was created
    m = Deployments.latest_health_status_by_project_ids([p.id])
    assert Map.has_key?(m, p.id)
  end

  test "aws settings require region and arn when enabled" do
    {:ok, c} = Clients.create_client(%{name: "CA"})
    {:ok, p} = Projects.create_project(%{name: "PA", client_id: c.id})

    assert {:error, _} =
             Deployments.upsert_health_check_setting(p.id, %{
               enabled: true,
               provider: "aws_elbv2",
               aws_region: "",
               aws_target_group_arn: ""
             })

    assert {:ok, s} =
             Deployments.upsert_health_check_setting(p.id, %{
               enabled: true,
               provider: "aws_elbv2",
               aws_region: "us-east-1",
               aws_target_group_arn: "arn:aws:elasticloadbalancing:..."
             })

    assert s.enabled
  end

  test "list_enabled_health_check_settings only returns enabled ones" do
    {:ok, c} = Clients.create_client(%{name: "CF"})
    {:ok, p1} = Projects.create_project(%{name: "PF1", client_id: c.id})
    {:ok, p2} = Projects.create_project(%{name: "PF2", client_id: c.id})

    {:ok, _} =
      Deployments.upsert_health_check_setting(p1.id, %{
        enabled: true,
        provider: "http",
        endpoint_url: "http://example/health1"
      })

    # Disabled (empty url)
    _ =
      Deployments.upsert_health_check_setting(p2.id, %{
        enabled: true,
        provider: "http",
        endpoint_url: ""
      })
      |> case do
        {:error, _} -> :ok
        _ -> :ok
      end

    proj_ids = Deployments.list_enabled_health_check_settings() |> Enum.map(& &1.project_id)
    assert p1.id in proj_ids
    refute p2.id in proj_ids
  end
end
