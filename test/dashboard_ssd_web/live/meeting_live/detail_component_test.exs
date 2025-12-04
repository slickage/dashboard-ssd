defmodule DashboardSSDWeb.MeetingLive.DetailComponentTest do
  use DashboardSSD.DataCase, async: false
  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts
  alias DashboardSSD.Meetings.{AgendaItem, CacheStore}
  alias DashboardSSDWeb.MeetingLive.DetailComponent

  setup do
    Accounts.ensure_role!("admin")
    :ok
  end

  defp render_detail(assigns), do: render_component(DetailComponent, assigns)

  test "derives post from cache and normalizes action_items; manual agenda wins" do
    # Seed cache with bitstring action_items
    :ok =
      CacheStore.put({:series_artifacts, "series-1"}, %{accomplished: "Notes", action_items: "A\nB"}, 60_000)

    # Seed manual agenda
    {:ok, _} =
      %AgendaItem{}
      |> AgendaItem.changeset(%{calendar_event_id: "evt-1", text: "Manual", position: 0, source: "manual"})
      |> DashboardSSD.Repo.insert()

    html =
      render_detail(%{
        id: "m1",
        meeting_id: "evt-1",
        series_id: "series-1",
        title: "Weekly – Client A"
      })

    assert html =~ "Last meeting summary"
    assert html =~ "Notes"
    assert html =~ ">A<"
    assert html =~ ">B<"
    # agenda textarea should include manual text, not derived items
    assert html =~ ">Manual<"
  end

  test "shows suggested association based on title when none set" do
    # Create a client to match against title
    _ = Accounts.ensure_role!("client")
    {:ok, _} = DashboardSSD.Clients.create_client(%{name: "Acme Corp"})
    # Create a project too, to ensure client suggestion is visible
    {:ok, _} = DashboardSSD.Projects.create_project(%{name: "Legacy", client_id: nil})

    html =
      render_detail(%{
        id: "m2",
        meeting_id: "evt-2",
        series_id: nil,
        title: "Weekly Sync – Acme Corp",
        params: %{"mock" => "1"}
      })

    # Suggested tag appears in the select option for the matching client
    assert html =~ "(suggested)"
    assert html =~ "Clients"
  end
end
