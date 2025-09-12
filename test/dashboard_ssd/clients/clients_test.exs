defmodule DashboardSSD.ClientsTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Clients
  alias DashboardSSD.Clients.Client

  test "create_client/1 requires name" do
    assert {:error, changeset} = Clients.create_client(%{})
    assert %{name: ["can't be blank"]} = errors_on(changeset)
  end

  test "create_client/1 inserts client; list/get return it" do
    {:ok, client} = Clients.create_client(%{name: "Acme"})
    assert %Client{id: id} = client

    assert Enum.any?(Clients.list_clients(), &(&1.id == id))
    assert %Client{id: ^id, name: "Acme"} = Clients.get_client!(id)
  end

  test "update_client/2 updates name; invalid returns error" do
    {:ok, client} = Clients.create_client(%{name: "Old"})
    {:ok, client} = Clients.update_client(client, %{name: "New"})
    assert client.name == "New"

    assert {:error, changeset} = Clients.update_client(client, %{name: nil})
    assert %{name: ["can't be blank"]} = errors_on(changeset)
  end

  test "delete_client/1 removes client" do
    {:ok, client} = Clients.create_client(%{name: "Gone"})
    assert {:ok, _} = Clients.delete_client(client)
    assert_raise Ecto.NoResultsError, fn -> Clients.get_client!(client.id) end
  end

  test "change_client/2 returns changeset" do
    {:ok, client} = Clients.create_client(%{name: "X"})
    cs = Clients.change_client(client, %{name: "Y"})
    assert %Ecto.Changeset{} = cs
    assert cs.changes.name == "Y"
  end
end
