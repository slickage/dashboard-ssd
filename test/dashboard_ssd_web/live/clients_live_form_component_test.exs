defmodule DashboardSSDWeb.ClientsLiveFormComponentTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Accounts
  alias DashboardSSD.Clients
  alias DashboardSSDWeb.ClientsLive.FormComponent

  defp socket,
    do: %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, flash: %{}},
      private: %{live_temp: %{flash: %{}}},
      root_pid: self()
    }

  test "admin can validate and create client" do
    admin = Accounts.ensure_role!("admin")

    {:ok, _u} =
      Accounts.create_user(%{email: "fc-admin@example.com", name: "A", role_id: admin.id})

    {:ok, sock} =
      FormComponent.update(
        %{action: :new, patch: "/clients", current_user: %{role: %{name: "admin"}}},
        socket()
      )

    # Validate
    {:noreply, sock2} =
      FormComponent.handle_event("validate", %{"client" => %{"name" => "NewCo"}}, sock)

    assert sock2.assigns.changeset.valid?

    # Save
    {:noreply, _sock3} =
      FormComponent.handle_event("save", %{"client" => %{"name" => "NewCo"}}, sock2)

    # Client should be created in DB
    assert Clients.search_clients("NewCo") |> Enum.any?(fn c -> c.name == "NewCo" end)
  end

  test "non-admin receive forbidden on save" do
    {:ok, sock} =
      FormComponent.update(
        %{action: :new, patch: "/clients", current_user: %{role: %{name: "employee"}}},
        socket()
      )

    {:noreply, _sock2} =
      FormComponent.handle_event("save", %{"client" => %{"name" => "X"}}, sock)

    # No client should be created for non-admin
    refute Clients.search_clients("X") |> Enum.any?(fn c -> c.name == "X" end)
  end
end
