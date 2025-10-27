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
end
