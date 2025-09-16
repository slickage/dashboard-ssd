defmodule DashboardSSD.Clients.PubSubTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Clients

  test "broadcasts on create/update/delete and subscriber receives" do
    Clients.subscribe()

    {:ok, _c} = Clients.create_client(%{name: "Acme"})
    assert_receive {:client, :created, %Clients.Client{}}

    {:ok, c2} = Clients.update_client(Clients.ensure_client!("Acme"), %{name: "Renamed"})
    assert_receive {:client, :updated, %Clients.Client{}}

    {:ok, _} = Clients.delete_client(c2)
    assert_receive {:client, :deleted, %Clients.Client{}}
  end
end
