defmodule DashboardSSD.DeploymentsTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Clients
  alias DashboardSSD.Deployments
  alias DashboardSSD.Projects

  setup do
    {:ok, client} = Clients.create_client(%{name: "C"})
    {:ok, project} = Projects.create_project(%{name: "P", client_id: client.id})
    %{project: project}
  end

  describe "deployments" do
    test "create/list/get/update/delete & by-project", %{project: project} do
      # validations
      assert {:error, cs} = Deployments.create_deployment(%{})
      assert %{project_id: ["can't be blank"], status: ["can't be blank"]} = errors_on(cs)

      {:ok, dep} =
        Deployments.create_deployment(%{project_id: project.id, status: "ok", commit_sha: "abc"})

      assert Enum.any?(Deployments.list_deployments(), &(&1.id == dep.id))
      assert Deployments.get_deployment!(dep.id).status == "ok"

      {:ok, dep} = Deployments.update_deployment(dep, %{status: "bad"})
      assert dep.status == "bad"
      assert {:error, cs} = Deployments.update_deployment(dep, %{status: nil})
      assert %{status: ["can't be blank"]} = errors_on(cs)

      ids = Deployments.list_deployments_by_project(project.id) |> Enum.map(& &1.id)
      assert ids == [dep.id]

      assert {:ok, _} = Deployments.delete_deployment(dep)
    end
  end

  describe "health checks" do
    test "create/list/get/update/delete & by-project", %{project: project} do
      assert {:error, cs} = Deployments.create_health_check(%{})
      assert %{project_id: ["can't be blank"], status: ["can't be blank"]} = errors_on(cs)

      {:ok, hc} = Deployments.create_health_check(%{project_id: project.id, status: "passing"})
      assert Enum.any?(Deployments.list_health_checks(), &(&1.id == hc.id))
      assert Deployments.get_health_check!(hc.id).status == "passing"

      {:ok, hc} = Deployments.update_health_check(hc, %{status: "failing"})
      assert hc.status == "failing"
      assert {:error, cs} = Deployments.update_health_check(hc, %{status: nil})
      assert %{status: ["can't be blank"]} = errors_on(cs)

      ids = Deployments.list_health_checks_by_project(project.id) |> Enum.map(& &1.id)
      assert ids == [hc.id]

      assert {:ok, _} = Deployments.delete_health_check(hc)
    end
  end
end
