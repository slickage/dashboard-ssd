defmodule DashboardSSD.ClientsTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Clients

  test "ensure_client!/1 returns existing or creates new client" do
    c = Clients.ensure_client!("Acme")
    assert c.name == "Acme"
    c2 = Clients.ensure_client!("Acme")
    assert c2.id == c.id
  end

  test "search_clients/1 does case-insensitive partial and escapes %" do
    {:ok, _} = Clients.create_client(%{name: "Globex"})
    {:ok, _} = Clients.create_client(%{name: "Acme"})

    names = Clients.search_clients("ob") |> Enum.map(& &1.name)
    assert "Globex" in names

    # Ensure % does not blow up the query (treated as literal by escape we apply)
    _ = Clients.search_clients("%")
  end

  test "search_clients/1 falls back to all clients when term is not binary" do
    {:ok, c1} = Clients.create_client(%{name: "Wayne Enterprises"})
    {:ok, c2} = Clients.create_client(%{name: "Stark Industries"})

    result_names =
      Clients.search_clients(:all)
      |> Enum.map(& &1.name)
      |> Enum.sort()

    assert result_names == Enum.sort([c1.name, c2.name])
  end

  test "list/search clients for user respects role scope" do
    {:ok, c1} = Clients.create_client(%{name: "Globex"})
    {:ok, c2} = Clients.create_client(%{name: "Acme"})

    assert Enum.sort(
             Enum.map(Clients.list_clients_for_user(%{role: %{name: "employee"}}), & &1.id)
           ) ==
             Enum.sort([c1.id, c2.id])

    assert Clients.list_clients_for_user(%{role: %{name: "client"}, client_id: nil}) == []
    assert Clients.search_clients_for_user(%{role: %{name: "client"}, client_id: nil}, "") == []

    scoped = %{role: %{name: "client"}, client_id: c2.id}
    assert Enum.map(Clients.list_clients_for_user(scoped), & &1.id) == [c2.id]
    assert Enum.map(Clients.search_clients_for_user(scoped, "Ac"), & &1.id) == [c2.id]
    assert Clients.search_clients_for_user(scoped, "Globex") == []
  end

  test "create/update/delete client broadcasts to subscribers" do
    Clients.subscribe()

    {:ok, client} = Clients.create_client(%{name: "Broadcast Corp"})
    assert_receive {:client, :created, %{id: created_id}}
    assert created_id == client.id

    {:ok, updated} = Clients.update_client(client, %{name: "Broadcast Corp v2"})
    assert_receive {:client, :updated, %{id: updated_id, name: "Broadcast Corp v2"}}
    assert updated_id == client.id

    {:ok, _deleted} = Clients.delete_client(updated)
    assert_receive {:client, :deleted, %{id: deleted_id}}
    assert deleted_id == client.id
  end

  test "list_clients_by_ids returns requested clients" do
    {:ok, c1} = Clients.create_client(%{name: "List Alpha"})
    {:ok, c2} = Clients.create_client(%{name: "List Beta"})

    assert Clients.list_clients_by_ids([]) == []

    ids = Clients.list_clients_by_ids([c1.id, c2.id]) |> Enum.map(& &1.id) |> Enum.sort()
    assert ids == Enum.sort([c1.id, c2.id])
  end
end
