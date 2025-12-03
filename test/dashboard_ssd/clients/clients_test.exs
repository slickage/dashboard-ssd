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
end
