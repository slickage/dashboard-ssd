defmodule DashboardSSDWeb.MeetingLive.DetailComponentEventsTest do
  use DashboardSSDWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts
  alias DashboardSSD.Clients
  alias DashboardSSD.Projects
  alias DashboardSSD.Meetings.Agenda
  alias DashboardSSDWeb.MeetingLive.DetailComponent

  defmodule HarnessLV do
    use Phoenix.LiveView
    def mount(_params, _session, socket) do
      {:ok,
       socket
       |> Phoenix.Component.assign(:meeting_id, "evt-dc")
       |> Phoenix.Component.assign(:series_id, "series-dc")
       |> Phoenix.Component.assign(:title, "Weekly – Harness")
       |> Phoenix.Component.assign(:params, %{"mock" => "1"})}
    end

    def render(assigns) do
      ~H"""
      <.live_component
        module={DetailComponent}
        id="detail"
        meeting_id={@meeting_id}
        series_id={@series_id}
        title={@title}
        params={@params}
      />
      """
    end
  end

  setup %{conn: conn} do
    # Provide an admin user session (UI renders settings button, etc.)
    {:ok, role} = {:ok, Accounts.ensure_role!("admin")}
    {:ok, user} = Accounts.create_user(%{email: "dc@example.com", name: "DC", role_id: role.id})
    {:ok, conn: init_test_session(conn, %{user_id: user.id})}
  end

  test "save_agenda_text persists manual agenda", %{conn: conn} do
    {:ok, view, _html} = live_isolated(conn, HarnessLV)

    render_submit(element(view, "form[phx-submit='save_agenda_text']"), %{"agenda_text" => "One\nTwo"})

    assert Agenda.list_items("evt-dc") |> length() == 1
    html = render(view)
    assert html =~ "Agenda"
    assert html =~ "One"
    assert html =~ "Two"
  end

  test "assoc_save sets client and project, resets event and series", %{conn: conn} do
    {:ok, c} = Clients.create_client(%{name: "Client Z"})
    {:ok, p} = Projects.create_project(%{name: "Proj Z"})

    {:ok, view, _} = live_isolated(conn, HarnessLV)

    # Save client association with persist checked
    render_submit(element(view, "form[phx-submit='assoc_save']"), %{"entity" => "client:#{c.id}", "persist_series" => "on"})
    html = render(view)
    assert html =~ "Client:"
    assert html =~ c.name

    # Save project association without explicit persist flag (defaults true in component)
    render_submit(element(view, "form[phx-submit='assoc_save']"), %{"entity" => "project:#{p.id}"})
    html2 = render(view)
    assert html2 =~ "Project:"
    assert html2 =~ p.name

    # Reset event association -> unassigned
    render_click(element(view, "button[phx-click='assoc_reset_event']"))
    html3 = render(view)
    assert html3 =~ "Unassigned"

    # Reset series association -> remains unassigned
    render_click(element(view, "button[phx-click='assoc_reset_series']"))
    html4 = render(view)
    assert html4 =~ "Unassigned"
  end
end
