defmodule DashboardSSDWeb.MeetingLiveTest do
  use DashboardSSDWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts
  alias DashboardSSD.Meetings.CacheStore
  alias DashboardSSD.Meetings.FirefliesArtifact
  alias DashboardSSD.Repo

  setup %{conn: conn} do
    prev_integrations = Application.get_env(:dashboard_ssd, :integrations)
    prev_tesla = Application.get_env(:tesla, :adapter)
    # Ensure Fireflies client authenticates and uses mock adapter in tests
    Application.put_env(
      :dashboard_ssd,
      :integrations,
      Keyword.merge(prev_integrations || [], fireflies_api_token: "test-token")
    )

    Application.put_env(:tesla, :adapter, Tesla.Mock)

    {:ok, user} =
      Accounts.create_user(%{
        email: "meeting_tester@example.com",
        name: "Mtg Test",
        role_id: Accounts.ensure_role!("admin").id
      })

    on_exit(fn ->
      case prev_integrations do
        nil -> Application.delete_env(:dashboard_ssd, :integrations)
        v -> Application.put_env(:dashboard_ssd, :integrations, v)
      end

      case prev_tesla do
        nil -> Application.delete_env(:tesla, :adapter)
        v -> Application.put_env(:tesla, :adapter, v)
      end
    end)

    {:ok, conn: init_test_session(conn, %{user_id: user.id})}
  end

  test "renders meeting detail", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/meetings/evt-demo")
    assert html =~ "Meeting"
  end

  test "meeting page renders bitstring action_items without crash", %{conn: conn} do
    # Seed Fireflies cache so fetch_latest_for_series returns bitstring items
    key = {:series_artifacts, "series-alpha"}
    val = %{accomplished: "Summary here", action_items: "A\nB"}
    :ok = CacheStore.put(key, val, :timer.minutes(5))

    {:ok, _view, html} = live(conn, ~p"/meetings/evt-1?series_id=series-alpha&title=Weekly")
    assert html =~ "Last meeting summary"
    assert html =~ "Summary here"
    assert html =~ "A"
    assert html =~ "B"
  end

  test "shows summary and action items when DB artifact present", %{conn: conn} do
    meeting_id = "evt-db"
    series_id = "series-db"

    {:ok, _} =
      %FirefliesArtifact{}
      |> FirefliesArtifact.changeset(%{
        recurring_series_id: series_id,
        transcript_id: "t-db",
        accomplished: "DB Notes",
        action_items: ["A", "B"],
        fetched_at: DateTime.utc_now()
      })
      |> Repo.insert()

    {:ok, _view, html} = live(conn, ~p"/meetings/#{meeting_id}?series_id=#{series_id}&title=Weekly")
    assert html =~ "Last meeting summary"
    assert html =~ "DB Notes"
    assert html =~ ">A<"
    assert html =~ ">B<"
  end

  test "refresh_post with nil series leaves summary pending", %{conn: conn} do
    meeting_id = "evt-nil-series"
    {:ok, view, html} = live(conn, ~p"/meetings/#{meeting_id}")
    assert html =~ "Summary pending"

    render_click(element(view, "button[phx-click='refresh_post']"))
    html2 = render(view)
    assert html2 =~ "Summary pending"
  end

  test "association section shows Client label with name", %{conn: conn} do
    meeting_id = "evt-assoc-client"
    {:ok, client} = Accounts.ensure_role!("client") |> then(fn _ -> 
      DashboardSSD.Clients.create_client(%{name: "Assoc C"})
    end)

    _assoc =
      %DashboardSSD.Meetings.MeetingAssociation{}
      |> DashboardSSD.Meetings.MeetingAssociation.changeset(%{
        calendar_event_id: meeting_id,
        client_id: client.id,
        origin: "manual",
        persist_series: true
      })
      |> Repo.insert!()

    {:ok, _view, html} = live(conn, ~p"/meetings/#{meeting_id}")
    assert html =~ "Client:"
    assert html =~ client.name
  end

  test "association section shows Project label with name", %{conn: conn} do
    meeting_id = "evt-assoc-project"
    {:ok, project} = DashboardSSD.Projects.create_project(%{name: "Assoc P"})

    _assoc =
      %DashboardSSD.Meetings.MeetingAssociation{}
      |> DashboardSSD.Meetings.MeetingAssociation.changeset(%{
        calendar_event_id: meeting_id,
        project_id: project.id,
        origin: "manual",
        persist_series: true
      })
      |> Repo.insert!()

    {:ok, _view, html} = live(conn, ~p"/meetings/#{meeting_id}")
    assert html =~ "Project:"
    assert html =~ project.name
  end

  test "assoc_save defaults persist_series when omitted", %{conn: conn} do
    meeting_id = "evt-assoc-default"
    {:ok, client} = DashboardSSD.Clients.create_client(%{name: "Persist Default"})
    {:ok, view, _} = live(conn, ~p"/meetings/#{meeting_id}")

    render_submit(element(view, "form[phx-submit='assoc_save']"), %{"entity" => "client:#{client.id}"})
    html = render(view)
    assert html =~ ~s(value="client:#{client.id}" selected)
  end
  test "can save manual agenda text", %{conn: conn} do
    meeting_id = "evt-save"
    {:ok, view, _html} = live(conn, ~p"/meetings/#{meeting_id}?mock=1")

    form = element(view, "form[phx-submit='save_agenda_text']")
    render_submit(form, %{"agenda_text" => "Line 1\nLine 2"})

    # Verify it persisted (via context) and is rendered
    assert DashboardSSD.Meetings.Agenda.list_items(meeting_id) |> length() == 1

    html = render(view)
    assert html =~ "Agenda"
    assert html =~ "Line 1"
    assert html =~ "Line 2"
  end

  test "associate to client, reset event and series", %{conn: conn} do
    meeting_id = "evt-assoc"
    series_id = "series-assoc"

    {:ok, client} = DashboardSSD.Clients.create_client(%{name: "ACME"})

    {:ok, view, _html} = live(conn, ~p"/meetings/#{meeting_id}?series_id=#{series_id}&mock=1")

    # Save association to client with persist checked
    assoc_form = element(view, "form[phx-submit='assoc_save']")
    render_submit(assoc_form, %{"entity" => "client:#{client.id}", "persist_series" => "on"})

    html = render(view)
    assert html =~ "Client:"
    assert html =~ client.name

    # Reset event association (series may still apply)
    render_click(element(view, "button[phx-click='assoc_reset_event']"))
    html2 = render(view)

    # Event-level association removed; since the record included the event id, fallback is unassigned
    assert html2 =~ "Unassigned"

    # Reset series association, now should be unassigned
    render_click(element(view, "button[phx-click='assoc_reset_series']"))
    html3 = render(view)
    assert html3 =~ "Unassigned"
  end

  test "shows inline rate limit message in meeting detail", %{conn: conn} do
    # Mock Fireflies to return rate-limited error for any query
    Tesla.Mock.mock(fn %{method: :post, url: "https://api.fireflies.ai/graphql"} ->
      %Tesla.Env{
        status: 200,
        body: %{
          "data" => nil,
          "errors" => [
            %{
              "code" => "too_many_requests",
              "message" => "Too many requests. Please retry after 02:34:56 AM (UTC)",
              "extensions" => %{"code" => "too_many_requests", "status" => 429}
            }
          ]
        }
      }
    end)

    {:ok, _view, html} = live(conn, ~p"/meetings/evt-1?series_id=series-1&title=Weekly")
    assert html =~ "Last meeting summary"
    assert html =~ "Too many requests"
  end

  # What to bring section removed in favor of a single freeform agenda field
end
