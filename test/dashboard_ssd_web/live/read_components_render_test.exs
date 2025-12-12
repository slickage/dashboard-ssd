defmodule DashboardSSDWeb.ReadComponentsRenderTest do
  use DashboardSSDWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias DashboardSSD.{Clients, Projects}

  test "clients read component renders name and not-found" do
    {:ok, c} = Clients.create_client(%{name: "Acme"})

    # Component uses assigns[:id] first to resolve record, so pass id as the record id
    html =
      render_component(DashboardSSDWeb.ClientsLive.ReadComponent,
        id: Integer.to_string(c.id)
      )

    assert html =~ "Client"
    assert html =~ "Acme"

    html2 = render_component(DashboardSSDWeb.ClientsLive.ReadComponent, id: "abc")
    assert html2 =~ "Client not found"
  end

  test "projects read component renders name and not-found" do
    {:ok, c} = Clients.create_client(%{name: "Globex"})
    {:ok, p} = Projects.create_project(%{name: "Portal", client_id: c.id})

    html =
      render_component(DashboardSSDWeb.ProjectsLive.ReadComponent,
        id: Integer.to_string(p.id)
      )

    assert html =~ "Project"
    assert html =~ "Portal"
    assert html =~ "Globex"

    html2 =
      render_component(DashboardSSDWeb.ProjectsLive.ReadComponent, id: "zzz")

    assert html2 =~ "Project not found"
  end
end
