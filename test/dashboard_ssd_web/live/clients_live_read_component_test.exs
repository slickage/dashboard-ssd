defmodule DashboardSSDWeb.ClientsLiveReadComponentTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Clients
  alias DashboardSSDWeb.ClientsLive.ReadComponent

  defp empty_socket,
    do: %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}, private: %{}, root_pid: self()}

  test "update assigns client from integer id" do
    {:ok, c} = Clients.create_client(%{name: "Acme"})

    {:ok, socket} = ReadComponent.update(%{client_id: c.id}, empty_socket())
    assert socket.assigns.client.id == c.id
    assert socket.assigns.client.name == "Acme"
  end

  test "update assigns client from binary id and handles nil" do
    {:ok, c} = Clients.create_client(%{name: "Globex"})

    {:ok, socket1} = ReadComponent.update(%{client_id: Integer.to_string(c.id)}, empty_socket())
    assert socket1.assigns.client.id == c.id

    {:ok, socket2} = ReadComponent.update(%{client_id: nil}, empty_socket())
    assert socket2.assigns.client == nil
  end
end
