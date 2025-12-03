defmodule DashboardSSDWeb.ProjectsLiveFormComponentTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Accounts
  alias DashboardSSD.{Clients, Projects}
  alias DashboardSSDWeb.ProjectsLive.FormComponent

  defp socket,
    do: %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, flash: %{}},
      private: %{live_temp: %{flash: %{}}},
      root_pid: self()
    }

  setup do
    Accounts.ensure_role!("admin")
    Accounts.ensure_role!("employee")
    :ok
  end

  test "validate and save as admin without health settings" do
    {:ok, c} = Clients.create_client(%{name: "Acme"})
    {:ok, p} = Projects.create_project(%{name: "Legacy", client_id: c.id})

    {:ok, sock} =
      FormComponent.update(
        %{
          project_id: Integer.to_string(p.id),
          action: :edit,
          current_user: %{role: %{name: "admin"}}
        },
        socket()
      )

    {:noreply, sock2} =
      FormComponent.handle_event("validate", %{"project" => %{"name" => "Renamed"}}, sock)

    assert sock2.assigns.changeset.valid?

    # Save without enabling health (avoids run_health_check_now)
    {:noreply, _sock3} =
      FormComponent.handle_event(
        "save",
        %{"project" => %{"name" => "Renamed"}, "hc" => %{"enabled" => "off"}},
        sock2
      )

    assert Projects.get_project!(p.id).name == "Renamed"
  end

  test "save forbidden for non-admin" do
    {:ok, p} = Projects.create_project(%{name: "Solo"})

    {:ok, sock} =
      FormComponent.update(
        %{
          project_id: Integer.to_string(p.id),
          action: :edit,
          current_user: %{role: %{name: "employee"}}
        },
        socket()
      )

    {:noreply, _sock2} =
      FormComponent.handle_event("save", %{"project" => %{"name" => "X"}}, sock)

    # Name should remain unchanged for non-admin
    assert Projects.get_project!(p.id).name == "Solo"
  end
end
