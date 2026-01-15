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
      CacheStore.put(
        {:series_artifacts, "series-1"},
        %{accomplished: "Notes", action_items: "A\nB"},
        60_000
      )

    # Seed manual agenda
    {:ok, _} =
      %AgendaItem{}
      |> AgendaItem.changeset(%{
        calendar_event_id: "evt-1",
        text: "Manual",
        position: 0,
        source: "manual"
      })
      |> DashboardSSD.Repo.insert()

    html =
      render_detail(%{
        id: "m1",
        meeting_id: "evt-1",
        series_id: "series-1",
        title: "Weekly – Client A"
      })

    assert html =~ "Last meeting summary"
    assert html =~ "Summary pending"
    # agenda textarea should include manual text
    assert html =~ ">Manual<"
  end

  test "renders action items from cached per-occurrence string (normalizes via split)" do
    # Seed per-occurrence cache with string action_items to hit normalization branch
    id = "evt-str"
    start = DateTime.utc_now() |> DateTime.truncate(:second)
    date = DateTime.to_date(start)

    :ok =
      CacheStore.put(
        {:meeting_notes, id, date},
        %{accomplished: nil, action_items: "A\nB"},
        60_000
      )

    html =
      render_detail(%{
        id: "m-str",
        meeting_id: id,
        series_id: nil,
        title: "Weekly – Items",
        starts_at: start,
        ends_at: DateTime.add(start, 3600, :second)
      })

    assert html =~ "Action Items"
    assert html =~ ">A<"
    assert html =~ ">B<"
  end

  test "renders summary text when present and no action items" do
    id = "evt-sum"
    start = DateTime.utc_now() |> DateTime.truncate(:second)
    date = DateTime.to_date(start)

    :ok =
      CacheStore.put(
        {:meeting_notes, id, date},
        %{accomplished: "Sum text", action_items: []},
        60_000
      )

    html =
      render_detail(%{
        id: "m-sum",
        meeting_id: id,
        series_id: nil,
        title: "Weekly – Summary",
        starts_at: start,
        ends_at: DateTime.add(start, 3600, :second)
      })

    assert html =~ "Last meeting summary"
    assert html =~ ">Sum text<"
  end

  test "assoc_apply_guess handles client and project via direct event call" do
    # Build a minimal socket assigns for direct handle_event invocation
    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, meeting_id: "evt-handle", series_id: "series-handle"}
    }

    {:ok, client} = DashboardSSD.Clients.create_client(%{name: "X Co"})
    {:ok, project} = DashboardSSD.Projects.create_project(%{name: "PX"})

    # Client path
    {:noreply, sock1} =
      DetailComponent.handle_event(
        "assoc_apply_guess",
        %{"entity" => "client:#{client.id}"},
        socket
      )

    assert sock1.assigns[:assoc]
    assert sock1.assigns[:association]

    # Project path
    {:noreply, sock2} =
      DetailComponent.handle_event(
        "assoc_apply_guess",
        %{"entity" => "project:#{project.id}"},
        socket
      )

    assert sock2.assigns[:assoc]
    assert sock2.assigns[:association]

    # Invalid entity leaves socket unchanged
    {:noreply, sock3} =
      DetailComponent.handle_event("assoc_apply_guess", %{"entity" => "bad:1"}, socket)

    refute Map.has_key?(sock3.assigns, :association)
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
