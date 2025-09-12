defmodule DashboardSSD.ContractsTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Clients
  alias DashboardSSD.Contracts
  alias DashboardSSD.Projects

  setup do
    {:ok, client} = Clients.create_client(%{name: "Client X"})
    {:ok, project} = Projects.create_project(%{name: "Project X", client_id: client.id})
    %{project: project}
  end

  describe "SOWs" do
    test "create/list/get/update/delete and by-project", %{project: project} do
      # create
      assert {:error, cs} = Contracts.create_sow(%{})
      assert %{name: ["can't be blank"], project_id: ["can't be blank"]} = errors_on(cs)

      {:ok, sow} = Contracts.create_sow(%{name: "S1", project_id: project.id, drive_id: "d1"})

      # list/get
      assert Enum.any?(Contracts.list_sows(), &(&1.id == sow.id))
      assert Contracts.get_sow!(sow.id).name == "S1"

      # update
      {:ok, sow} = Contracts.update_sow(sow, %{name: "S2"})
      assert sow.name == "S2"
      assert {:error, cs} = Contracts.update_sow(sow, %{name: nil})
      assert %{name: ["can't be blank"]} = errors_on(cs)

      # by project
      ids = Contracts.list_sows_by_project(project.id) |> Enum.map(& &1.id)
      assert ids == [sow.id]

      # delete
      assert {:ok, _} = Contracts.delete_sow(sow)
    end
  end

  describe "Change Requests" do
    test "create/list/get/update/delete and by-project", %{project: project} do
      # create
      assert {:error, cs} = Contracts.create_change_request(%{})
      assert %{name: ["can't be blank"], project_id: ["can't be blank"]} = errors_on(cs)

      {:ok, cr} =
        Contracts.create_change_request(%{name: "CR1", project_id: project.id, drive_id: "d1"})

      # list/get
      assert Enum.any?(Contracts.list_change_requests(), &(&1.id == cr.id))
      assert Contracts.get_change_request!(cr.id).name == "CR1"

      # update
      {:ok, cr} = Contracts.update_change_request(cr, %{name: "CR2"})
      assert cr.name == "CR2"
      assert {:error, cs} = Contracts.update_change_request(cr, %{name: nil})
      assert %{name: ["can't be blank"]} = errors_on(cs)

      # by project
      ids = Contracts.list_change_requests_by_project(project.id) |> Enum.map(& &1.id)
      assert ids == [cr.id]

      # delete
      assert {:ok, _} = Contracts.delete_change_request(cr)
    end
  end
end
