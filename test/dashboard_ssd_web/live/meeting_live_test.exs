defmodule DashboardSSDWeb.MeetingLiveTest do
  use DashboardSSDWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts
  alias DashboardSSD.Clients
  alias DashboardSSD.Projects

  alias DashboardSSD.Meetings.{
    Agenda,
    AgendaItem,
    CacheStore,
    FirefliesArtifact,
    MeetingAssociation
  }

  alias DashboardSSD.Repo
  alias DashboardSSDWeb.MeetingLive.Index, as: MeetingIndexLV
  alias Phoenix.LiveView.Socket

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

    {:ok, _view, html} =
      live(conn, ~p"/meetings/#{meeting_id}?series_id=#{series_id}&title=Weekly")

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

    {:ok, client} =
      Accounts.ensure_role!("client")
      |> then(fn _ ->
        Clients.create_client(%{name: "Assoc C"})
      end)

    _assoc =
      %MeetingAssociation{}
      |> MeetingAssociation.changeset(%{
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
    {:ok, project} = Projects.create_project(%{name: "Assoc P"})

    _assoc =
      %MeetingAssociation{}
      |> MeetingAssociation.changeset(%{
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
    {:ok, client} = Clients.create_client(%{name: "Persist Default"})
    {:ok, view, _} = live(conn, ~p"/meetings/#{meeting_id}")

    render_submit(element(view, "form[phx-submit='assoc_save']"), %{
      "entity" => "client:#{client.id}"
    })

    html = render(view)
    assert html =~ ~s(value="client:#{client.id}" selected)
  end

  test "assoc_save invalid entity and unknown leaves unassigned", %{conn: conn} do
    meeting_id = "evt-assoc-invalid"
    {:ok, view, html0} = live(conn, ~p"/meetings/#{meeting_id}?mock=1")
    assert html0 =~ "Unassigned"

    # Invalid parse for client id (non-integer)
    render_submit(element(view, "form[phx-submit='assoc_save']"), %{"entity" => "client:abc"})
    html1 = render(view)
    assert html1 =~ "Unassigned"

    # Unknown entity prefix
    render_submit(element(view, "form[phx-submit='assoc_save']"), %{"entity" => "foo:1"})
    html2 = render(view)
    assert html2 =~ "Unassigned"
  end

  test "assoc_apply_guess sets association for client and project (unit)" do
    meeting_id = "evt-apply-guess"
    series_id = "series-apply-guess"
    {:ok, client} = Clients.create_client(%{name: "Auto C"})
    {:ok, project} = Projects.create_project(%{name: "Auto P"})

    base_socket = %Socket{
      assigns: %{
        __changed__: %{},
        meeting_id: meeting_id,
        series_id: series_id,
        manual_agenda: []
      }
    }

    {:noreply, s1} =
      MeetingIndexLV.handle_event(
        "assoc_apply_guess",
        %{"entity" => "client:#{client.id}"},
        base_socket
      )

    assert s1.assigns.assoc.client_id == client.id

    {:noreply, s2} =
      MeetingIndexLV.handle_event(
        "assoc_apply_guess",
        %{"entity" => "project:#{project.id}"},
        base_socket
      )

    assert s2.assigns.assoc.project_id == project.id
  end

  test "tz:set updates tz_offset assign (unit)" do
    s0 = %Socket{assigns: %{__changed__: %{}}}

    {:noreply, s1} =
      MeetingIndexLV.handle_event("tz:set", %{"offset" => 0}, s0)

    assert s1.assigns.tz_offset == 0

    {:noreply, s2} =
      MeetingIndexLV.handle_event("tz:set", %{"offset" => "123"}, s0)

    assert s2.assigns.tz_offset == 123

    {:noreply, s3} =
      MeetingIndexLV.handle_event("tz:set", %{"offset" => :bad}, s0)

    assert s3.assigns.tz_offset == 0
  end

  describe "manual agenda item events (unit)" do
    test "edit/save/move/delete flows update DB and assigns" do
      meeting_id = "evt-items"
      # Seed items via context
      :ok = Agenda.replace_manual_text(meeting_id, "A\nB\nC")
      items0 = Agenda.list_items(meeting_id)
      assert length(items0) >= 1

      # Note: replace_manual_text may store a single text row or multiple rows depending on implementation

      # Normalize to at least two items for move tests
      if length(items0) == 1 do
        # Append another row to ensure we can move
        {:ok, _} =
          AgendaItem.changeset(%AgendaItem{}, %{
            calendar_event_id: meeting_id,
            text: "B",
            position: 2
          })
          |> Repo.insert()
      end

      items = Agenda.list_items(meeting_id)

      s0 =
        %Socket{
          assigns: %{
            __changed__: %{},
            meeting_id: meeting_id,
            series_id: nil,
            manual_agenda: items
          }
        }

      # edit_item success
      first = hd(items)

      {:noreply, s1} =
        MeetingIndexLV.handle_event(
          "edit_item",
          %{"id" => to_string(first.id)},
          s0
        )

      assert s1.assigns.editing_id == first.id
      assert is_binary(s1.assigns.editing_text)

      # edit_item with missing id
      {:noreply, s1b} =
        MeetingIndexLV.handle_event(
          "edit_item",
          %{"id" => to_string(first.id + 999_999)},
          s0
        )

      assert Map.get(s1b.assigns, :editing_id) == nil

      # save_item success (also clears editing assigns and refreshes)
      {:noreply, _s2} =
        MeetingIndexLV.handle_event(
          "save_item",
          %{"id" => to_string(first.id), "text" => "  Changed  "},
          s0
        )

      updated = Agenda.list_items(meeting_id) |> Enum.find(&(&1.id == first.id))
      assert updated.text == "Changed"

      # save_item missing id
      {:noreply, _s2b} =
        MeetingIndexLV.handle_event(
          "save_item",
          %{"id" => to_string(first.id + 999_999), "text" => "Noop"},
          s0
        )

      refute Enum.any?(Agenda.list_items(meeting_id), &(&1.text == "Noop"))

      # move down then up (ensure reorder persisted)
      items_before_move = Agenda.list_items(meeting_id)
      assert length(items_before_move) >= 2
      ids_before = Enum.map(items_before_move, & &1.id)
      target = Enum.at(items_before_move, 0)

      {:noreply, _s4} =
        MeetingIndexLV.handle_event(
          "move",
          %{"id" => to_string(target.id), "dir" => "down"},
          s0
        )

      ids_after_down = Agenda.list_items(meeting_id) |> Enum.map(& &1.id)
      assert ids_after_down != ids_before

      # Move up (may no-op if already first)
      move_up_id = Enum.at(ids_after_down, 1) || hd(ids_after_down)

      {:noreply, _s5} =
        MeetingIndexLV.handle_event(
          "move",
          %{"id" => to_string(move_up_id), "dir" => "up"},
          s0
        )

      # delete_item success
      second = Agenda.list_items(meeting_id) |> Enum.find(fn it -> it.id != first.id end)

      {:noreply, _s3} =
        MeetingIndexLV.handle_event(
          "delete_item",
          %{"id" => to_string(second.id)},
          s0
        )

      refute Enum.any?(Agenda.list_items(meeting_id), &(&1.id == second.id))

      # delete_item missing id
      {:noreply, _s3b} =
        MeetingIndexLV.handle_event(
          "delete_item",
          %{"id" => to_string(second.id + 999_999)},
          s0
        )
    end
  end

  test "refresh_post with series triggers refresh path with Tesla mocked", %{conn: conn} do
    # Mock any Fireflies GraphQL call
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql"} ->
        %Tesla.Env{status: 200, body: %{"data" => %{}}}
    end)

    meeting_id = "evt-refresh"
    series_id = "series-refresh"
    {:ok, view, _} = live(conn, ~p"/meetings/#{meeting_id}?series_id=#{series_id}")
    render_click(element(view, "button[phx-click='refresh_post']"))
    # No assertion needed other than not crashing; render to ensure LV updated
    _html = render(view)
  end

  test "shows generic message when Fireflies returns generic error", %{conn: conn} do
    Tesla.Mock.mock(fn %{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
      payload = if is_binary(body), do: Jason.decode!(body), else: body
      query = Map.get(payload, "query") || Map.get(payload, :query)

      cond do
        is_binary(query) and String.contains?(query, "query Bites") ->
          %Tesla.Env{
            status: 200,
            body: %{
              "data" => %{
                "bites" => [
                  %{
                    "id" => "b-err",
                    "transcript_id" => "t-err",
                    "created_at" => "2024-01-01T00:00:00Z",
                    "created_from" => %{"id" => "series-generic"}
                  }
                ]
              }
            }
          }

        is_binary(query) and String.contains?(query, "query Transcript(") ->
          %Tesla.Env{status: 500, body: %{"errors" => [%{"message" => "boom"}]}}

        true ->
          flunk("unexpected request: #{inspect(payload)}")
      end
    end)

    {:ok, _view, html} =
      live(conn, ~p"/meetings/evt-generic?series_id=series-generic&title=Weekly")

    assert html =~ "Last meeting summary"
    assert html =~ "Fireflies data unavailable. Please try again later."
  end

  test "can save manual agenda text", %{conn: conn} do
    meeting_id = "evt-save"
    {:ok, view, _html} = live(conn, ~p"/meetings/#{meeting_id}?mock=1")

    form = element(view, "form[phx-submit='save_agenda_text']")
    render_submit(form, %{"agenda_text" => "Line 1\nLine 2"})

    # Verify it persisted (via context) and is rendered
    assert Agenda.list_items(meeting_id) |> length() == 1

    html = render(view)
    assert html =~ "Agenda"
    assert html =~ "Line 1"
    assert html =~ "Line 2"
  end

  test "associate to client, reset event and series", %{conn: conn} do
    meeting_id = "evt-assoc"
    series_id = "series-assoc"

    {:ok, client} = Clients.create_client(%{name: "ACME"})

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
