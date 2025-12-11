defmodule DashboardSSDWeb.MeetingLive.DetailComponentEventsTest do
  use DashboardSSDWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts
  alias DashboardSSD.Clients
  alias DashboardSSD.Meetings.{Agenda, CacheStore}
  alias DashboardSSD.Projects
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
    prev_integrations = Application.get_env(:dashboard_ssd, :integrations)
    prev_tesla = Application.get_env(:tesla, :adapter)

    Application.put_env(
      :dashboard_ssd,
      :integrations,
      Keyword.merge(prev_integrations || [], fireflies_api_token: "test-token")
    )

    Application.put_env(:tesla, :adapter, Tesla.Mock)

    # Mock globally so LiveView processes can use it
    Tesla.Mock.mock_global(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
        payload = if is_binary(body), do: Jason.decode!(body), else: body
        q = Map.get(payload, "query") || Map.get(payload, :query) || ""

        cond do
          String.contains?(q, "query Bites") ->
            %Tesla.Env{status: 200, body: %{"data" => %{"bites" => []}}}

          String.contains?(q, "query Transcripts(") ->
            %Tesla.Env{status: 200, body: %{"data" => %{"transcripts" => []}}}

          String.contains?(q, "query Transcript(") ->
            %Tesla.Env{
              status: 200,
              body: %{
                "data" => %{
                  "transcript" => %{"summary" => %{"overview" => nil, "action_items" => []}}
                }
              }
            }

          true ->
            %Tesla.Env{status: 200, body: %{"data" => %{}}}
        end
    end)

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

  test "save_agenda_text persists manual agenda", %{conn: conn} do
    {:ok, view, _html} = live_isolated(conn, HarnessLV)

    render_submit(element(view, "form[phx-submit='save_agenda_text']"), %{
      "agenda_text" => "One\nTwo"
    })

    assert Agenda.list_items("evt-dc") |> length() == 1
    html = render(view)
    assert html =~ "Agenda"
    assert html =~ "One"
    assert html =~ "Two"
  end

  test "refresh_post triggers refresh when series_id is present (component)", %{conn: conn} do
    {:ok, view, html0} = live_isolated(conn, HarnessLV)
    assert html0 =~ "Summary pending"

    render_click(element(view, "button[phx-click='refresh_post']"))
    html1 = render(view)
    # Still pending (mock mode); ensures branch executed without crash
    assert html1 =~ "Summary pending"
  end

  test "assoc_save sets client and project, resets event and series", %{conn: conn} do
    {:ok, c} = Clients.create_client(%{name: "Client Z"})
    {:ok, p} = Projects.create_project(%{name: "Proj Z"})

    {:ok, view, _} = live_isolated(conn, HarnessLV)

    # Save client association with persist checked
    render_submit(element(view, "form[phx-submit='assoc_save']"), %{
      "entity" => "client:#{c.id}",
      "persist_series" => "on"
    })

    html = render(view)
    # Client option should now be selected in the dropdown
    assert html =~ ~s(value="client:#{c.id}" selected)

    # Save project association without explicit persist flag (defaults true in component)
    render_submit(element(view, "form[phx-submit='assoc_save']"), %{"entity" => "project:#{p.id}"})

    html2 = render(view)
    assert html2 =~ ~s(value="project:#{p.id}" selected)

    # Reset event association -> unassigned
    render_click(element(view, "button[phx-click='assoc_reset_event']"))
    html3 = render(view)
    refute html3 =~ ~s(value="client:#{c.id}" selected)
    refute html3 =~ ~s(value="project:#{p.id}" selected)

    # Reset series association -> remains unassigned
    render_click(element(view, "button[phx-click='assoc_reset_series']"))
    html4 = render(view)
    refute html4 =~ ~s(value="client:#{c.id}" selected)
    refute html4 =~ ~s(value="project:#{p.id}" selected)
  end

  test "assoc_save project with explicit persist flag", %{conn: conn} do
    {:ok, p} = Projects.create_project(%{name: "Proj Explicit"})
    {:ok, view, _} = live_isolated(conn, HarnessLV)

    render_submit(element(view, "form[phx-submit='assoc_save']"), %{
      "entity" => "project:#{p.id}",
      "persist_series" => "on"
    })

    html = render(view)
    assert html =~ ~s(value="project:#{p.id}" selected)
  end

  test "refresh_post does nothing when series_id is nil (component)", %{conn: conn} do
    defmodule NilSeriesHarness do
      use Phoenix.LiveView
      alias DashboardSSDWeb.MeetingLive.DetailComponent

      def mount(_p, _s, socket) do
        {:ok,
         socket
         |> Phoenix.Component.assign(:meeting_id, "evt-nil")
         |> Phoenix.Component.assign(:series_id, nil)
         |> Phoenix.Component.assign(:title, "Weekly – Nil Series")
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

    {:ok, view, html0} = live_isolated(conn, NilSeriesHarness)
    assert html0 =~ "Summary pending"

    render_click(element(view, "button[phx-click='refresh_post']"))
    html1 = render(view)
    assert html1 =~ "Summary pending"
  end

  test "assoc_save invalid entity and unknown leaves selection unchanged (component)", %{
    conn: conn
  } do
    {:ok, view, html0} = live_isolated(conn, HarnessLV)
    assert html0 =~ "— Choose —"

    render_submit(element(view, "form[phx-submit='assoc_save']"), %{"entity" => "client:abc"})
    html1 = render(view)
    assert html1 =~ "— Choose —"

    render_submit(element(view, "form[phx-submit='assoc_save']"), %{"entity" => "foo:1"})
    html2 = render(view)
    assert html2 =~ "— Choose —"
  end

  defmodule NoMockHarness do
    use Phoenix.LiveView
    alias DashboardSSDWeb.MeetingLive.DetailComponent

    @impl true
    def mount(_p, _s, socket) do
      {:ok,
       socket
       |> Phoenix.Component.assign(:meeting_id, "evt-rl")
       |> Phoenix.Component.assign(:series_id, "series-rl")
       |> Phoenix.Component.assign(:title, "Weekly – RL")
       |> Phoenix.Component.assign(:params, %{})}
    end

    @impl true
    def render(assigns) do
      ~H"""
      <.live_component
        module={DetailComponent}
        id="detail-rl"
        meeting_id={@meeting_id}
        series_id={@series_id}
        title={@title}
        params={@params}
      />
      """
    end
  end

  test "shows rate-limited message when Fireflies returns RL (component)", %{conn: conn} do
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql"} ->
        %Tesla.Env{status: 429, body: %{"errors" => [%{"message" => "too many"}]}}
    end)

    {:ok, _view, html} = live_isolated(conn, NoMockHarness)
    assert html =~ "Last meeting summary"
    assert html =~ "too many"
  end

  defmodule DerivedHarness do
    use Phoenix.LiveView
    alias DashboardSSDWeb.MeetingLive.DetailComponent

    @impl true
    def mount(_p, _s, socket) do
      # Seed cache with derived items so component derives agenda_text when manual empty
      CacheStore.put(
        {:series_artifacts, "series-derived"},
        %{accomplished: nil, action_items: ["A", "B"]},
        :timer.minutes(5)
      )

      {:ok,
       socket
       |> Phoenix.Component.assign(:meeting_id, "evt-derived")
       |> Phoenix.Component.assign(:series_id, "series-derived")
       |> Phoenix.Component.assign(:title, "Weekly – Derived")
       |> Phoenix.Component.assign(:params, %{})}
    end

    @impl true
    def render(assigns) do
      ~H"""
      <.live_component
        module={DetailComponent}
        id="detail-derived"
        meeting_id={@meeting_id}
        series_id={@series_id}
        title={@title}
        params={@params}
      />
      """
    end
  end

  test "derives agenda_text from Fireflies when manual empty (list items)", %{conn: conn} do
    # Ensure no Tesla calls are needed (we seeded cache)
    Tesla.Mock.mock(fn _ -> %Tesla.Env{status: 200, body: %{"data" => %{}}} end)
    {:ok, _view, html} = live_isolated(conn, DerivedHarness)
    # The textarea includes the derived agenda text
    assert html =~ ">A"
    assert html =~ ">B"
  end

  defmodule SuggestHarness do
    use Phoenix.LiveView
    alias DashboardSSDWeb.MeetingLive.DetailComponent

    @impl true
    def mount(_p, _s, socket) do
      {:ok,
       socket
       |> Phoenix.Component.assign(:meeting_id, "evt-suggest")
       |> Phoenix.Component.assign(:series_id, nil)
       |> Phoenix.Component.assign(:title, "Weekly – Suggest C")
       |> Phoenix.Component.assign(:params, %{})}
    end

    @impl true
    def render(assigns) do
      ~H"""
      <.live_component
        module={DetailComponent}
        id="detail-suggest"
        meeting_id={@meeting_id}
        series_id={@series_id}
        title={@title}
        params={@params}
      />
      """
    end
  end

  test "shows (suggested) tag for guessed client when no assoc", %{conn: conn} do
    {:ok, _} = DashboardSSD.Clients.create_client(%{name: "Suggest C"})
    {:ok, _view, html} = live_isolated(conn, SuggestHarness)
    assert html =~ "(suggested)"
  end
end
