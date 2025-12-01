defmodule DashboardSSDWeb.ProjectsLive.ContractsTest do
  use DashboardSSDWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias DashboardSSD.Accounts
  alias DashboardSSD.Clients
  alias DashboardSSD.Documents.SharedDocument
  alias DashboardSSD.Projects.Project
  alias DashboardSSD.Repo
  alias DashboardSSDWeb.ProjectsLive.Contracts, as: ProjectsContractsLive

  setup do
    Accounts.ensure_role!("admin")
    Accounts.ensure_role!("employee")

    Application.put_env(
      :dashboard_ssd,
      :workspace_bootstrap_module,
      DashboardSSD.WorkspaceBootstrapStub
    )

    :persistent_term.put({:workspace_test_pid}, self())

    on_exit(fn ->
      :persistent_term.erase({:workspace_test_pid})
      Application.delete_env(:dashboard_ssd, :workspace_bootstrap_module)
    end)

    :ok
  end

  test "admin sees staff contracts", %{conn: conn} do
    {:ok, client} = Clients.create_client(%{name: "Acme"})
    {:ok, project} = Repo.insert(%Project{name: "Proj", client_id: client.id})
    insert_document(client.id, project.id, title: "SOW")

    {:ok, admin} =
      Accounts.create_user(%{
        email: "admin-contracts@example.com",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = init_test_session(conn, %{user_id: admin.id})
    {:ok, _view, html} = live(conn, ~p"/projects/contracts")
    assert html =~ "Contracts (Staff)"
    assert html =~ "SOW"
  end

  test "employee without contract capability is redirected", %{conn: conn} do
    {:ok, _} =
      Accounts.replace_role_capabilities("employee", [], granted_by_id: nil)

    {:ok, employee} =
      Accounts.create_user(%{
        email: "employee-contracts@example.com",
        role_id: Accounts.ensure_role!("employee").id
      })

    conn = init_test_session(conn, %{user_id: employee.id})
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/projects/contracts")
  end

  test "admin can select sections when regenerating workspace", %{conn: conn} do
    {:ok, client} = Clients.create_client(%{name: "Acme"})

    {:ok, project} =
      Repo.insert(%Project{
        name: "Proj",
        client_id: client.id,
        drive_folder_id: "folder"
      })

    insert_document(client.id, project.id, title: "Doc")

    {:ok, admin} =
      Accounts.create_user(%{
        email: "admin2@example.com",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = init_test_session(conn, %{user_id: admin.id})
    {:ok, view, _html} = live(conn, ~p"/projects/contracts")

    project_id = project.id
    view |> element("button[phx-value-id=\"#{project_id}\"]", "Regenerate") |> render_click()
    assert render(view) =~ "Regenerate workspace for"

    form_params = %{
      "project_id" => "#{project_id}",
      "sections" => ["drive_contracts", "notion_project_kb"]
    }

    view |> form("#workspace-bootstrap-form", form_params) |> render_submit()

    assert_receive {:workspace_bootstrap, ^project_id, sections}
    assert sections == [:drive_contracts, :notion_project_kb]
  end

  test "regen form deduplicates sections", %{conn: conn} do
    {:ok, client} = Clients.create_client(%{name: "Acme"})

    {:ok, project} =
      Repo.insert(%Project{
        name: "Proj",
        client_id: client.id,
        drive_folder_id: "folder"
      })

    insert_document(client.id, project.id, title: "Doc")

    {:ok, admin} =
      Accounts.create_user(%{
        email: "admin-dup@example.com",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = init_test_session(conn, %{user_id: admin.id})
    {:ok, view, _html} = live(conn, ~p"/projects/contracts")

    project_id = project.id
    view |> element("button[phx-value-id=\"#{project_id}\"]", "Regenerate") |> render_click()

    view
    |> form("#workspace-bootstrap-form", %{
      "project_id" => "#{project_id}",
      "sections" => ["drive_contracts", "drive_contracts"]
    })
    |> render_submit()

    assert_receive {:workspace_bootstrap, ^project_id, [:drive_contracts]}
  end

  test "regen form requires selecting at least one section", %{conn: conn} do
    {:ok, client} = Clients.create_client(%{name: "Acme"})

    {:ok, project} =
      Repo.insert(%Project{
        name: "Proj",
        client_id: client.id,
        drive_folder_id: "folder"
      })

    insert_document(client.id, project.id, title: "Doc")

    {:ok, admin} =
      Accounts.create_user(%{
        email: "admin3@example.com",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = init_test_session(conn, %{user_id: admin.id})
    {:ok, view, _html} = live(conn, ~p"/projects/contracts")

    project_id = project.id
    view |> element("button[phx-value-id=\"#{project_id}\"]", "Regenerate") |> render_click()

    html =
      view
      |> form("#workspace-bootstrap-form", %{
        "project_id" => "#{project_id}",
        "sections" => []
      })
      |> render_submit()

    assert html =~ "Select at least one section"

    refute_received {:workspace_bootstrap, ^project_id, _}
  end

  test "admin can filter documents by client", %{conn: conn} do
    {:ok, client_a} = Clients.create_client(%{name: "Acme"})
    {:ok, client_b} = Clients.create_client(%{name: "Beta"})

    {:ok, project_a} = Repo.insert(%Project{name: "A", client_id: client_a.id})
    {:ok, project_b} = Repo.insert(%Project{name: "B", client_id: client_b.id})

    insert_document(client_a.id, project_a.id, title: "Doc A")
    insert_document(client_b.id, project_b.id, title: "Doc B")

    {:ok, admin} =
      Accounts.create_user(%{
        email: "admin-filter@example.com",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = init_test_session(conn, %{user_id: admin.id})
    {:ok, _view, html} = live(conn, ~p"/projects/contracts?client_id=#{client_a.id}")

    assert html =~ "Doc A"
    refute html =~ "Doc B"
  end

  test "admin toggles visibility via staff console", %{conn: conn} do
    {:ok, client} = Clients.create_client(%{name: "Toggle Co"})
    {:ok, project} = Repo.insert(%Project{name: "Proj", client_id: client.id})
    doc = insert_document(client.id, project.id, title: "Doc", visibility: :client)

    {:ok, admin} =
      Accounts.create_user(%{
        email: "admin-toggle@example.com",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = init_test_session(conn, %{user_id: admin.id})
    {:ok, view, _html} = live(conn, ~p"/projects/contracts")

    view
    |> element("form[phx-change=toggle_visibility]")
    |> render_change(%{"doc_id" => doc.id, "visibility" => "internal"})

    updated = Repo.get!(SharedDocument, doc.id)
    assert updated.visibility == :internal
  end

  test "admin toggles client edit flag", %{conn: conn} do
    {:ok, client} = Clients.create_client(%{name: "Edit Co"})
    {:ok, project} = Repo.insert(%Project{name: "Proj", client_id: client.id})

    doc =
      insert_document(client.id, project.id,
        title: "Editable Doc",
        visibility: :client,
        client_edit_allowed: false
      )

    {:ok, admin} =
      Accounts.create_user(%{
        email: "admin-edit@example.com",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = init_test_session(conn, %{user_id: admin.id})
    {:ok, view, _html} = live(conn, ~p"/projects/contracts")

    view
    |> element("form[phx-change=toggle_edit]")
    |> render_change(%{"doc_id" => doc.id, "value" => "true"})

    updated = Repo.get!(SharedDocument, doc.id)
    assert updated.client_edit_allowed
  end

  test "shows error when project missing drive folder", %{conn: conn} do
    {:ok, client} = Clients.create_client(%{name: "Folderless"})

    {:ok, project} =
      Repo.insert(%Project{
        name: "Proj",
        client_id: client.id,
        drive_folder_id: nil
      })

    insert_document(client.id, project.id, title: "Doc")

    {:ok, admin} =
      Accounts.create_user(%{
        email: "admin-missing-folder@example.com",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = init_test_session(conn, %{user_id: admin.id})
    {:ok, view, _html} = live(conn, ~p"/projects/contracts")

    view
    |> element("button[phx-value-id=\"#{project.id}\"]", "Regenerate")
    |> render_click()

    assert render(view) =~ "Project is missing a Drive folder."
  end

  test "cancel bootstrap form closes the panel", %{conn: conn} do
    {:ok, client} = Clients.create_client(%{name: "Cancel"})

    {:ok, project} =
      Repo.insert(%Project{
        name: "Proj",
        client_id: client.id,
        drive_folder_id: "folder"
      })

    insert_document(client.id, project.id, title: "Doc")

    {:ok, admin} =
      Accounts.create_user(%{
        email: "admin-cancel@example.com",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = init_test_session(conn, %{user_id: admin.id})
    {:ok, view, _html} = live(conn, ~p"/projects/contracts")

    view
    |> element("button[phx-value-id=\"#{project.id}\"]", "Regenerate")
    |> render_click()

    assert render(view) =~ "Regenerate workspace for"

    view
    |> element("button[phx-click='cancel_bootstrap_form']", "Close")
    |> render_click()

    refute render(view) =~ "Regenerate workspace for"
  end

  test "internal documents show warning badge", %{conn: conn} do
    {:ok, client} = Clients.create_client(%{name: "Warn"})
    {:ok, project} = Repo.insert(%Project{name: "Proj", client_id: client.id})
    insert_document(client.id, project.id, title: "Doc", visibility: :internal)

    {:ok, admin} =
      Accounts.create_user(%{
        email: "admin-warning@example.com",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = init_test_session(conn, %{user_id: admin.id})
    {:ok, _view, html} = live(conn, ~p"/projects/contracts")

    assert html =~ "Internal only"
  end

  test "drive inheritance warning renders when sharing broken", %{conn: conn} do
    {:ok, client} = Clients.create_client(%{name: "Warn Drive"})

    {:ok, project} =
      Repo.insert(%Project{
        name: "Proj",
        client_id: client.id,
        drive_folder_id: "folder",
        drive_folder_sharing_inherited: false
      })

    insert_document(client.id, project.id, title: "Doc")

    {:ok, admin} =
      Accounts.create_user(%{
        email: "admin-drive-warning@example.com",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = init_test_session(conn, %{user_id: admin.id})
    {:ok, _view, html} = live(conn, ~p"/projects/contracts")

    assert html =~ "Drive inheritance broken"
  end

  test "bootstrap form shows empty state when no sections configured", %{conn: conn} do
    original_blueprint =
      Application.get_env(:dashboard_ssd, DashboardSSD.Documents.WorkspaceBlueprint)

    Application.put_env(:dashboard_ssd, DashboardSSD.Documents.WorkspaceBlueprint, %{
      sections: [],
      default_sections: []
    })

    on_exit(fn ->
      Application.put_env(
        :dashboard_ssd,
        DashboardSSD.Documents.WorkspaceBlueprint,
        original_blueprint
      )
    end)

    {:ok, client} = Clients.create_client(%{name: "Empty Sections"})

    {:ok, project} =
      Repo.insert(%Project{
        name: "Proj",
        client_id: client.id,
        drive_folder_id: "folder"
      })

    insert_document(client.id, project.id, title: "Doc")

    {:ok, admin} =
      Accounts.create_user(%{
        email: "admin-empty-sections@example.com",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = init_test_session(conn, %{user_id: admin.id})
    {:ok, view, _html} = live(conn, ~p"/projects/contracts")

    view
    |> element("button[phx-value-id=\"#{project.id}\"]", "Regenerate")
    |> render_click()

    assert render(view) =~ "No workspace sections are configured"
  end

  test "bootstrap form humanizes section labels and types", %{conn: conn} do
    original_blueprint =
      Application.get_env(:dashboard_ssd, DashboardSSD.Documents.WorkspaceBlueprint)

    Application.put_env(:dashboard_ssd, DashboardSSD.Documents.WorkspaceBlueprint, %{
      sections: [
        %{id: :drive_special_docs, type: :drive, enabled?: true},
        %{id: :notion_project_notes, type: :notion, enabled?: true}
      ],
      default_sections: [:drive_special_docs]
    })

    on_exit(fn ->
      Application.put_env(
        :dashboard_ssd,
        DashboardSSD.Documents.WorkspaceBlueprint,
        original_blueprint
      )
    end)

    {:ok, client} = Clients.create_client(%{name: "Labels"})

    {:ok, project} =
      Repo.insert(%Project{
        name: "Proj",
        client_id: client.id,
        drive_folder_id: "folder"
      })

    insert_document(client.id, project.id, title: "Doc")

    {:ok, admin} =
      Accounts.create_user(%{
        email: "admin-labels@example.com",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = init_test_session(conn, %{user_id: admin.id})
    {:ok, view, _html} = live(conn, ~p"/projects/contracts")

    view
    |> element("button[phx-value-id=\"#{project.id}\"]", "Regenerate")
    |> render_click()

    html = render(view)
    assert html =~ "Drive Special Docs"
    assert html =~ "Drive section"
    assert html =~ "Notion Project Notes"
    assert html =~ "Notion section"
  end

  test "drive sync success message clears syncing flag", %{conn: conn} do
    {:ok, client} = Clients.create_client(%{name: "Sync"})
    {:ok, project} = Repo.insert(%Project{name: "Proj", client_id: client.id})
    insert_document(client.id, project.id, title: "Doc")

    {:ok, admin} =
      Accounts.create_user(%{
        email: "admin-sync@example.com",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = init_test_session(conn, %{user_id: admin.id})
    {:ok, view, _html} = live(conn, ~p"/projects/contracts")

    send(view.pid, {:drive_sync_done, :ok})

    assert render(view) =~ "Drive documents synced."
  end

  test "drive sync failure shows error flash", %{conn: conn} do
    {:ok, client} = Clients.create_client(%{name: "SyncErr"})
    {:ok, project} = Repo.insert(%Project{name: "Proj", client_id: client.id})
    insert_document(client.id, project.id, title: "Doc")

    {:ok, admin} =
      Accounts.create_user(%{
        email: "admin-sync-error@example.com",
        role_id: Accounts.ensure_role!("admin").id
      })

    conn = init_test_session(conn, %{user_id: admin.id})
    {:ok, view, _html} = live(conn, ~p"/projects/contracts")

    send(view.pid, {:drive_sync_done, {:error, :timeout}})

    assert render(view) =~ "Drive sync failed: :timeout"
  end

  defp insert_document(client_id, project_id, attrs) do
    attrs = Map.new(attrs)

    params = %{
      client_id: client_id,
      project_id: project_id,
      source: :drive,
      source_id: Ecto.UUID.generate(),
      doc_type: "sow",
      title: attrs[:title] || "Doc",
      visibility: Map.get(attrs, :visibility, :client)
    }

    %SharedDocument{}
    |> SharedDocument.changeset(params)
    |> Repo.insert!()
  end

  describe "projects contracts inline events" do
    test "toggle_mobile_menu flips assign" do
      socket = staff_socket(%{mobile_menu_open: false})

      {:noreply, updated} =
        ProjectsContractsLive.handle_event("toggle_mobile_menu", %{}, socket)

      assert updated.assigns.mobile_menu_open
    end

    test "close_mobile_menu sets assign to false" do
      socket = staff_socket(%{mobile_menu_open: true})

      {:noreply, updated} =
        ProjectsContractsLive.handle_event("close_mobile_menu", %{}, socket)

      refute updated.assigns.mobile_menu_open
    end

    test "toggle_visibility no-ops when user lacks manage capability" do
      socket = staff_socket(%{can_manage?: false})

      assert {:noreply, ^socket} =
               ProjectsContractsLive.handle_event(
                 "toggle_visibility",
                 %{"doc_id" => "123", "visibility" => "client"},
                 socket
               )
    end

    test "toggle_edit no-ops when user lacks manage capability" do
      socket = staff_socket(%{can_manage?: false})

      assert {:noreply, ^socket} =
               ProjectsContractsLive.handle_event(
                 "toggle_edit",
                 %{"doc_id" => "123", "value" => "true"},
                 socket
               )
    end

    test "submit_bootstrap_form ignored for read-only users" do
      socket = staff_socket(%{can_manage?: false})

      assert {:noreply, ^socket} =
               ProjectsContractsLive.handle_event(
                 "submit_bootstrap_form",
                 %{"project_id" => "1"},
                 socket
               )
    end

    test "cancel_bootstrap_form resets modal state" do
      socket =
        staff_socket(%{
          available_sections: [%{id: :drive_contracts}],
          bootstrap_form: %{
            open?: true,
            project_id: 1,
            project_name: "Acme",
            selected_sections: [:drive_contracts],
            error: "boom"
          }
        })

      {:noreply, updated} =
        ProjectsContractsLive.handle_event("cancel_bootstrap_form", %{}, socket)

      refute updated.assigns.bootstrap_form.open?
      assert updated.assigns.bootstrap_form.error == nil
    end

    test "filter event loads documents for selected client" do
      {:ok, client} = Clients.create_client(%{name: "Filter Client"})
      {:ok, project} = Repo.insert(%Project{name: "Proj", client_id: client.id})
      insert_document(client.id, project.id, title: "Filter Doc")

      socket = staff_socket(%{documents: [], filter_client_id: nil})

      {:noreply, updated} =
        ProjectsContractsLive.handle_event(
          "filter",
          %{"client_id" => "#{client.id}"},
          socket
        )

      assert updated.assigns.filter_client_id == client.id
      assert Enum.any?(updated.assigns.documents, &(&1.title == "Filter Doc"))
    end
  end

  defp staff_socket(assigns) do
    %Phoenix.LiveView.Socket{
      endpoint: DashboardSSDWeb.Endpoint,
      view: ProjectsContractsLive,
      root_pid: self(),
      transport_pid: self(),
      private: %{live_action: :index},
      assigns:
        %{
          __changed__: %{},
          flash: %{},
          current_user: %{id: 1},
          can_manage?: true,
          filter_client_id: nil,
          mobile_menu_open: false,
          documents: [],
          clients: [],
          available_sections: [],
          bootstrap_form: %{
            open?: false,
            project_id: nil,
            project_name: nil,
            selected_sections: [],
            error: nil
          }
        }
        |> Map.merge(assigns)
    }
  end
end
