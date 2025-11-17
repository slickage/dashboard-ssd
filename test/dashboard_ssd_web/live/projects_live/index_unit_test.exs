defmodule DashboardSSDWeb.ProjectsLive.IndexUnitTest do
  use DashboardSSD.DataCase, async: true

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias DashboardSSD.Clients.Client
  alias DashboardSSD.Projects.Project
  alias DashboardSSD.Repo
  alias DashboardSSDWeb.ProjectsLive.Index
  alias Phoenix.LiveView.Socket

  test "handle_params reuses loaded data when params unchanged" do
    socket =
      assign(%Socket{}, %{
        live_action: :index,
        client_id: nil,
        accessible_client_scope: :all,
        loaded: true,
        projects: [],
        summaries: %{},
        collapsed_teams: MapSet.new(),
        linear_enabled: false,
        can_view_contracts?: false,
        can_manage_projects?: false
      })

    {:noreply, updated} = Index.handle_params(%{}, "/projects", socket)

    assert updated.assigns.loaded
    assert updated.assigns.projects == []
    assert updated.assigns.client_id == nil
  end

  test "handle_params loads allowed client scope even when filter param mismatches" do
    allowed = Repo.insert!(%Client{name: "Acme"})
    disallowed = Repo.insert!(%Client{name: "Globex"})

    Repo.insert!(%Project{name: "Allowed", client_id: allowed.id})
    Repo.insert!(%Project{name: "Hidden", client_id: disallowed.id})

    socket =
      assign(%Socket{}, %{
        live_action: :index,
        client_id: nil,
        accessible_client_scope: [allowed.id],
        loaded: false,
        projects: nil,
        summaries: nil,
        collapsed_teams: MapSet.new(),
        linear_enabled: false,
        can_view_contracts?: false,
        can_manage_projects?: false
      })

    params = %{"client_id" => Integer.to_string(disallowed.id)}

    {:noreply, updated} = Index.handle_params(params, "/projects", socket)

    assert Enum.map(updated.assigns.projects, & &1.name) == ["Allowed"]
    assert updated.assigns.client_id == nil
    assert updated.assigns.client_filter_enabled? == false
  end

  test "toggle_mobile_menu and close_mobile_menu adjust assigns" do
    socket = assign(%Socket{}, mobile_menu_open: false)

    {:noreply, toggled} = Index.handle_event("toggle_mobile_menu", %{}, socket)
    assert toggled.assigns.mobile_menu_open

    {:noreply, closed} = Index.handle_event("close_mobile_menu", %{}, toggled)
    refute closed.assigns.mobile_menu_open
  end

  test "toggle_team stores collapsed keys" do
    socket = assign(%Socket{}, collapsed_teams: MapSet.new())

    {:noreply, collapsed} = Index.handle_event("toggle_team", %{"team" => "team-1"}, socket)
    assert MapSet.member?(collapsed.assigns.collapsed_teams, "team-1")

    {:noreply, expanded} = Index.handle_event("toggle_team", %{"team" => "team-1"}, collapsed)
    refute MapSet.member?(expanded.assigns.collapsed_teams, "team-1")
  end

  test "filter event pushes correct patch when client selected" do
    socket = assign(%Socket{}, accessible_client_scope: :all, client_id: nil)

    {:noreply, patched} = Index.handle_event("filter", %{"client_id" => "15"}, socket)
    assert patched.redirected == {:live, :patch, %{to: "/projects?client_id=15", kind: :push}}

    socket2 = assign(%Socket{}, accessible_client_scope: :all, client_id: "15")

    {:noreply, cleared} = Index.handle_event("filter", %{"client_id" => ""}, socket2)
    assert cleared.redirected == {:live, :patch, %{to: "/projects", kind: :push}}
  end

  test "client filter remains enabled for multi-client scope" do
    c1 = Repo.insert!(%Client{name: "Acme"})
    c2 = Repo.insert!(%Client{name: "Globex"})

    socket =
      assign(%Socket{}, %{
        live_action: :index,
        client_id: nil,
        accessible_client_scope: [c1.id, c2.id],
        loaded: false,
        projects: nil,
        summaries: nil,
        collapsed_teams: MapSet.new(),
        linear_enabled: false,
        can_view_contracts?: false,
        can_manage_projects?: false
      })

    {:noreply, updated} = Index.handle_params(%{}, "/projects", socket)

    assert updated.assigns.client_filter_enabled?
    assert Enum.map(updated.assigns.clients, & &1.id) == Enum.sort([c1.id, c2.id])
  end

  test "render outputs project rows with summaries" do
    client = %Client{id: 1, name: "Acme"}

    project = %Project{
      id: 1,
      name: "Proj",
      client_id: client.id,
      client: client,
      linear_team_id: "team-1",
      linear_team_name: "Platform"
    }

    assigns = %{
      live_action: :index,
      client_filter_enabled?: true,
      accessible_client_scope: :all,
      client_id: nil,
      clients: [client],
      linear_enabled: true,
      projects: [project],
      can_view_contracts?: false,
      can_manage_projects?: false,
      summaries: %{
        project.id => %{
          total: 3,
          in_progress: 1,
          finished: 2,
          assigned: [%{name: "Alice", count: 3}]
        }
      },
      collapsed_teams: MapSet.new(),
      team_members: %{"team-1" => [%{display_name: "Alice"}]},
      loaded: true,
      health: %{},
      summaries_cached: %{},
      summaries_loading: false,
      page_title: "Projects",
      current_path: "/projects",
      mobile_menu_open: false,
      last_linear_sync_at: nil,
      last_linear_sync_reason: :fresh,
      can_manage_projects?: true
    }

    html = assigns |> Index.render() |> rendered_to_string()

    assert html =~ "Proj"
    assert html =~ "Acme"
    assert html =~ "Platform"
    assert html =~ "Alice"
  end

  test "render shows empty state and disabled linear notice" do
    assigns = %{
      live_action: :index,
      client_filter_enabled?: true,
      accessible_client_scope: :all,
      client_id: nil,
      clients: [%Client{id: 1, name: "Acme"}],
      linear_enabled: false,
      projects: [],
      summaries: %{},
      collapsed_teams: MapSet.new(),
      team_members: %{},
      loaded: true,
      health: %{},
      summaries_cached: %{},
      summaries_loading: false,
      page_title: "Projects",
      current_path: "/projects",
      mobile_menu_open: false,
      last_linear_sync_at: nil,
      last_linear_sync_reason: nil,
      can_manage_projects?: false,
      can_view_contracts?: false
    }

    html = assigns |> Index.render() |> rendered_to_string()
    assert html =~ "No projects found."
    assert html =~ "Linear not configured"
  end

  test "render shows loading spinner when summaries empty" do
    client = %Client{id: 5, name: "Client"}
    project = %Project{id: 8, name: "Spinner", client_id: client.id, client: client}

    assigns = %{
      live_action: :index,
      client_filter_enabled?: true,
      accessible_client_scope: :all,
      client_id: nil,
      clients: [client],
      linear_enabled: true,
      projects: [project],
      summaries: %{},
      collapsed_teams: MapSet.new(),
      team_members: %{},
      loaded: true,
      health: %{},
      summaries_cached: %{},
      summaries_loading: false,
      page_title: "Projects",
      current_path: "/projects",
      mobile_menu_open: false,
      last_linear_sync_at: nil,
      last_linear_sync_reason: nil,
      can_manage_projects?: false,
      can_view_contracts?: false
    }

    html = assigns |> Index.render() |> rendered_to_string()
    assert html =~ "animate-spin"
  end

  test "handle_params edit action loads projects when socket not loaded" do
    client = Repo.insert!(%Client{name: "Acme"})
    project = Repo.insert!(%Project{name: "EditProj", client_id: client.id})

    socket =
      assign(%Socket{}, %{
        live_action: :edit,
        loaded: false,
        projects: nil,
        summaries: nil,
        collapsed_teams: MapSet.new(),
        linear_enabled: false,
        accessible_client_scope: :all,
        client_id: nil,
        can_view_contracts?: false,
        can_manage_projects?: false
      })

    {:noreply, updated} =
      Index.handle_params(
        %{"id" => Integer.to_string(project.id)},
        "/projects/#{project.id}/edit",
        socket
      )

    assert updated.assigns.loaded
    assert Enum.any?(updated.assigns.projects, &(&1.id == project.id))
  end

  test "render groups projects by team including no-team bucket" do
    client = %Client{id: 10, name: "Client"}

    project_with_team =
      %Project{
        id: 11,
        name: "Team Alpha",
        client_id: client.id,
        client: client,
        linear_team_id: "team-alpha",
        linear_team_name: "Alpha"
      }

    project_without_team =
      %Project{
        id: 12,
        name: "Untethered",
        client_id: client.id,
        client: client,
        linear_team_id: nil,
        linear_team_name: "   "
      }

    assigns = %{
      live_action: :index,
      client_filter_enabled?: true,
      accessible_client_scope: :all,
      client_id: nil,
      clients: [client],
      linear_enabled: true,
      projects: [project_with_team, project_without_team],
      summaries: %{
        project_with_team.id => :unavailable,
        project_without_team.id => %{total: 0, in_progress: 0, finished: 0, assigned: []}
      },
      collapsed_teams: MapSet.new(),
      team_members: %{"team-alpha" => [%{name: "Bob"}]},
      loaded: true,
      health: %{},
      summaries_cached: %{},
      summaries_loading: false,
      page_title: "Projects",
      current_path: "/projects",
      mobile_menu_open: false,
      last_linear_sync_at: nil,
      last_linear_sync_reason: nil,
      can_manage_projects?: false,
      can_view_contracts?: false
    }

    html = assigns |> Index.render() |> rendered_to_string()
    assert html =~ "Team Alpha"
    assert html =~ "Untethered"
    assert html =~ "No Linear Team"
  end

  test "handle_params reloads when r param provided even if cached" do
    client = Repo.insert!(%Client{name: "Scoped"})
    project = Repo.insert!(%Project{name: "ScopedProj", client_id: client.id})

    socket =
      assign(%Socket{}, %{
        live_action: :index,
        client_id: nil,
        accessible_client_scope: :all,
        loaded: true,
        projects: [project],
        summaries: %{},
        collapsed_teams: MapSet.new(),
        linear_enabled: false,
        can_view_contracts?: false,
        can_manage_projects?: false
      })

    {:noreply, updated} =
      Index.handle_params(%{"client_id" => "", "r" => "1"}, "/projects", socket)

    assert updated.assigns.loaded
    assert Enum.any?(updated.assigns.projects, &(&1.id == project.id))
  end

  test "handle_info health updates assign" do
    socket = assign(%Socket{}, health: %{})
    {:noreply, updated} = Index.handle_info({:health_updated, %{1 => :ok}}, socket)
    assert updated.assigns.health == %{1 => :ok}
  end

  test "handle_info reload_summaries returns socket when task running" do
    prev_env = Application.get_env(:dashboard_ssd, :env)
    Application.put_env(:dashboard_ssd, :env, :dev)
    on_exit(fn -> Application.put_env(:dashboard_ssd, :env, prev_env) end)

    socket =
      assign(%Socket{}, %{
        summaries_task_ref: make_ref(),
        summaries_task_context: :auto,
        projects: [],
        linear_enabled: true
      })

    {:noreply, updated} = Index.handle_info(:reload_summaries, socket)
    assert updated.assigns.summaries_task_ref == socket.assigns.summaries_task_ref
  end

  test "handle_info sync_from_linear respects existing task ref" do
    prev_env = Application.get_env(:dashboard_ssd, :env)
    Application.put_env(:dashboard_ssd, :env, :dev)
    on_exit(fn -> Application.put_env(:dashboard_ssd, :env, prev_env) end)

    socket =
      assign(%Socket{}, %{
        summaries_task_ref: make_ref(),
        summaries_task_context: :auto,
        projects: [],
        linear_enabled: true
      })

    {:noreply, updated} = Index.handle_info(:sync_from_linear, socket)
    assert updated.assigns.summaries_task_ref == socket.assigns.summaries_task_ref
  end

  test "fetch_projects handles all scopes and ids" do
    {:ok, client} = DashboardSSD.Clients.create_client(%{name: "Fetch"})

    {:ok, project} =
      DashboardSSD.Projects.create_project(%{name: "FetchProj", client_id: client.id})

    all = Index.test_fetch_projects(nil, :all)
    assert Enum.any?(all, &(&1.id == project.id))

    all_blank = Index.test_fetch_projects("", :all)
    assert Enum.any?(all_blank, &(&1.id == project.id))

    by_client =
      Index.test_fetch_projects(Integer.to_string(client.id), :all)
      |> Enum.map(& &1.id)

    assert by_client == [project.id]
  end

  test "fetch_projects honors restricted scopes" do
    {:ok, c1} = DashboardSSD.Clients.create_client(%{name: "Allowed"})
    {:ok, c2} = DashboardSSD.Clients.create_client(%{name: "Other"})
    {:ok, _p1} = DashboardSSD.Projects.create_project(%{name: "AllowedProj", client_id: c1.id})
    {:ok, _p2} = DashboardSSD.Projects.create_project(%{name: "OtherProj", client_id: c2.id})

    only_allowed =
      Index.test_fetch_projects(Integer.to_string(c1.id), [c1.id])
      |> Enum.map(& &1.client_id)

    assert only_allowed == [c1.id]

    all_scoped =
      Index.test_fetch_projects(Integer.to_string(c2.id), [c1.id])
      |> Enum.map(& &1.client_id)

    assert Enum.sort(all_scoped) == [c1.id]
  end

  test "clients_for_scope returns expected lists" do
    {:ok, client} = DashboardSSD.Clients.create_client(%{name: "Scope"})
    assert Enum.any?(Index.test_clients_for_scope(:all), &(&1.id == client.id))
    assert Index.test_clients_for_scope([]) == []
    scoped = Index.test_clients_for_scope([client.id])
    assert Enum.map(scoped, & &1.id) == [client.id]
  end

  test "client filter helper predicates" do
    assert Index.test_client_filter_enabled?(:all)
    refute Index.test_client_filter_enabled?([])
    assert Index.test_client_filter_enabled?([1, 2])
    refute Index.test_client_filter_enabled?([1])
  end

  test "normalize client id respects scope lists" do
    assert Index.test_normalize_client_id_for_scope(:all, nil) == nil
    assert Index.test_normalize_client_id_for_scope(:all, "5") == "5"
    assert Index.test_normalize_client_id_for_scope([], "5") == nil
    assert Index.test_normalize_client_id_for_scope([1, 2], Integer.to_string(1)) == "1"
    assert Index.test_normalize_client_id_for_scope([1, 2], "99") == nil
  end

  test "parse_client_id handles nil, empty, integers and strings" do
    assert Index.test_parse_client_id(nil) == :error
    assert Index.test_parse_client_id("") == :error
    assert Index.test_parse_client_id(5) == {:ok, 5}
    assert Index.test_parse_client_id("42") == {:ok, 42}
    assert Index.test_parse_client_id("abc") == :error
  end

  test "sanitized_team_name trims values and ignores non-binaries" do
    assert Index.test_sanitized_team_name("  Alpha ") == "Alpha"
    assert Index.test_sanitized_team_name("   ") == nil
    assert Index.test_sanitized_team_name(%{}) == nil
  end

  test "format_member_name handles email-only members" do
    assert Index.test_format_member_name(%{email: " user@example.com "}) == "user@example.com"
    assert Index.test_format_member_name(%{}) == nil
  end

  test "presence helper normalizes blanks" do
    assert Index.test_presence("") == nil
    assert Index.test_presence("value") == "value"
  end

  test "handle_sync_result surfaces rate limit flashes" do
    socket =
      %Socket{assigns: %{flash: %{}, __changed__: %{}}, private: %{live_temp: %{}}}
      |> assign(%{summaries: %{}, summaries_cached: %{}})

    now = DateTime.utc_now()

    {updated, :error} =
      Index.test_handle_sync_result(socket, {:error, {:rate_limited, "Slow down"}},
        context: :manual,
        show_flash?: true
      )

    assert updated.assigns.flash["error"] =~ "rate limit"

    cache_info = %{
      cached?: true,
      cached_reason: :fresh_cache,
      message: nil,
      synced_at: now,
      inserted: 0,
      updated: 0
    }

    {cached_socket, _} =
      Index.test_handle_sync_result(socket, {:ok, cache_info},
        context: :manual,
        show_flash?: true
      )

    assert cached_socket.assigns.flash["info"]
  end
end
