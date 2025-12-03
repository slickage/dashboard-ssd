defmodule DashboardSSDWeb.ProjectsLiveReadComponentTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.{Clients, Projects}
  alias DashboardSSDWeb.ProjectsLive.ReadComponent

  defp empty_socket,
    do: %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}, private: %{}, root_pid: self()}

  test "update assigns project from integer id" do
    {:ok, c} = Clients.create_client(%{name: "Acme"})
    {:ok, p} = Projects.create_project(%{name: "Website", client_id: c.id})

    {:ok, socket} = ReadComponent.update(%{project_id: p.id}, empty_socket())

    assert socket.assigns.project.id == p.id
    assert socket.assigns.project.client && socket.assigns.project.client.name == "Acme"
  end

  test "update assigns project from binary id and handles nil" do
    {:ok, p} = Projects.create_project(%{name: "Solo"})

    # Binary id
    {:ok, socket1} = ReadComponent.update(%{project_id: Integer.to_string(p.id)}, empty_socket())
    assert socket1.assigns.project.id == p.id

    # Nil id
    {:ok, socket2} = ReadComponent.update(%{project_id: nil}, empty_socket())
    assert socket2.assigns.project == nil
  end
end
