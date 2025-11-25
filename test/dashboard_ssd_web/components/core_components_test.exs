defmodule DashboardSSDWeb.CoreComponentsTest do
  use DashboardSSDWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Phoenix.Component, only: [sigil_H: 2]
  import DashboardSSDWeb.CoreComponents

  alias DashboardSSD.Accounts
  alias DashboardSSD.Accounts.User
  alias DashboardSSDWeb.CoreComponents

  describe "modal/1" do
    test "renders container and inner content" do
      html =
        render_component(&CoreComponents.modal/1, %{
          id: "confirm-modal",
          show: true,
          inner_block: slot("Confirm body")
        })

      assert html =~ "confirm-modal"
      assert html =~ "Confirm body"
    end
  end

  describe "flash/1" do
    test "renders inline message from slot" do
      html =
        render_component(&CoreComponents.flash/1, %{
          kind: :info,
          title: "Heads up",
          flash: %{},
          inner_block: slot("Saved!")
        })

      assert html =~ "Saved!"
      assert html =~ "hero-information-circle-mini"
    end
  end

  test "flash_group renders info and server/client fallback flashes" do
    html =
      render_component(&CoreComponents.flash_group/1, %{
        flash: %{
          "info" => "Synced",
          "error" => "Nope"
        }
      })

    assert html =~ "Success!"
    assert html =~ "Synced"
    assert html =~ "Something went wrong!"
  end

  describe "button/1" do
    test "renders button when authorized with default capability" do
      html =
        render_component(&CoreComponents.button/1, %{
          inner_block: slot("Submit")
        })

      assert html =~ "Submit"
      assert html =~ "rounded-full"
    end

    test "hides button when capability required but user missing" do
      html =
        render_component(&CoreComponents.button/1, %{
          capability: {:manage, :projects_contracts},
          current_user: nil,
          inner_block: slot("Hidden")
        })

      assert html == ""
    end

    test "allows capability strings via current user role" do
      role = Accounts.ensure_role!("admin")

      html =
        render_component(&CoreComponents.button/1, %{
          capability: "projects.contracts.manage",
          current_user: %User{role: role},
          inner_block: slot("Manage")
        })

      assert html =~ "Manage"
    end
  end

  describe "input/1" do
    test "renders textarea with errors" do
      html =
        render_component(&CoreComponents.input/1, %{
          id: "notes",
          name: "notes",
          label: "Notes",
          type: "textarea",
          value: "Initial",
          errors: ["can't be blank"]
        })

      assert html =~ "textarea"
      assert html =~ "can&#39;t be blank"
    end

    test "renders checkbox with hidden false value" do
      html =
        render_component(&CoreComponents.input/1, %{
          id: "client_edit",
          name: "client_edit",
          label: "Client can edit",
          type: "checkbox",
          value: true
        })

      assert html =~ "type=\"hidden\""
      assert html =~ "Client can edit"
    end

    test "renders select options with prompt" do
      html =
        render_component(&CoreComponents.input/1, %{
          id: "project",
          name: "project",
          label: "Project",
          type: "select",
          options: [{"Phoenix", "phoenix"}, {"Elixir", "elixir"}],
          value: "elixir",
          prompt: "Choose project"
        })

      assert html =~ "Choose project"
      assert html =~ "selected value=\"elixir\""
    end

    test "renders default input from form field assigns" do
      form = Phoenix.Component.to_form(%{"name" => "Phoenix"}, as: :project)

      html =
        render_component(&CoreComponents.input/1, %{
          field: form[:name],
          label: "Project Name"
        })

      assert html =~ "project[name]"
      assert html =~ "Project Name"
    end
  end

  test "simple_form renders heading, fields, and actions" do
    form = Phoenix.Component.to_form(%{}, as: :project)

    html =
      render_component(&CoreComponents.simple_form/1, %{
        id: "project-form",
        title: "Project",
        description: "Create project",
        for: form,
        action: "/projects",
        inner_block: slot(~s(<input type="text" name="project[name]" />)),
        actions: slot(~s(<button type="submit">Save</button>))
      })

    assert html =~ "Project"
    assert html =~ "Create project"
    assert html =~ "project-form"
    assert html =~ "project[name]"
    assert html =~ "Save"
  end

  test "header renders title, subtitle, and actions" do
    html =
      render_component(&CoreComponents.header/1, %{
        inner_block: slot("Clients"),
        subtitle: named_slot(:subtitle, "All clients"),
        actions: named_slot(:actions, ~s(<button>New</button>))
      })

    assert html =~ "Clients"
    assert html =~ "All clients"
    assert html =~ "New"
  end

  test "table renders columns, rows, and actions" do
    rows = [%{name: "Proj", client: "Acme"}]

    html =
      render_component(
        fn assigns ->
          ~H"""
          <.table id="projects-table" rows={@rows} row_id={fn row -> "proj-#{row.name}" end}>
            <:col :let={row} label="Name">{row.name}</:col>
            <:col :let={row} label="Client">{row.client}</:col>
            <:action :let={row}>Action {row.name}</:action>
          </.table>
          """
        end,
        rows: rows
      )

    assert html =~ "projects-table"
    assert html =~ "Proj"
    assert html =~ "Acme"
    assert html =~ "Action Proj"
  end

  test "list renders ordered items" do
    html =
      render_component(&CoreComponents.list/1, %{
        item: [
          %{
            __slot__: :item,
            __changed__: %{},
            title: "Contract",
            inner_block: fn _, _ -> "Signed" end
          }
        ]
      })

    assert html =~ "Contract"
    assert html =~ "Signed"
  end

  test "status_badge and health_dot render colors" do
    assert render_component(&CoreComponents.status_badge/1, %{state: %{connected: true}}) =~
             "Connected"

    assert render_component(&CoreComponents.status_badge/1, %{state: %{connected: false}}) =~
             "Not connected"

    assert render_component(&CoreComponents.health_dot/1, %{status: "up"}) =~ "bg-emerald-400"
    assert render_component(&CoreComponents.health_dot/1, %{status: "down"}) =~ "bg-rose-400"
  end

  test "search_form renders query field and filters" do
    html =
      render_component(&CoreComponents.search_form/1, %{
        query: "contract",
        placeholder: "Search docs",
        rest: %{:"phx-submit" => "search"}
      })

    assert html =~ "contract"
    assert html =~ "Search docs"
    assert html =~ "phx-submit=\"search\""
  end

  test "back renders link with default text" do
    html =
      render_component(&CoreComponents.back/1, %{
        navigate: "/projects",
        inner_block: slot("Go Back")
      })

    assert html =~ "Go Back"
    assert html =~ "/projects"
  end

  describe "JS helpers" do
    test "show composes transition with selector" do
      %{ops: ops} = CoreComponents.show(%Phoenix.LiveView.JS{}, "#panel")

      assert Enum.any?(ops, fn [action, opts] ->
               action == "show" and Map.get(opts, :to) == "#panel"
             end)
    end

    test "hide composes transition with selector" do
      %{ops: ops} = CoreComponents.hide(%Phoenix.LiveView.JS{}, "#panel")

      assert Enum.any?(ops, fn [action, opts] ->
               action == "hide" and Map.get(opts, :to) == "#panel"
             end)
    end

    test "show_modal composes expected operations" do
      %{ops: ops} = CoreComponents.show_modal(%Phoenix.LiveView.JS{}, "workspace-modal")

      assert Enum.any?(ops, fn [action, opts] ->
               action == "show" and Map.get(opts, :to) == "#workspace-modal"
             end)
    end

    test "hide_modal removes overflow class" do
      %{ops: ops} = CoreComponents.hide_modal(%Phoenix.LiveView.JS{}, "workspace-modal")

      assert Enum.any?(ops, fn [action, opts] ->
               action == "remove_class" and Map.get(opts, :names) == ["overflow-hidden"]
             end)
    end
  end

  test "icon renders hero icons with classes" do
    html =
      render_component(&CoreComponents.icon/1, %{
        name: "hero-user-circle",
        class: "w-4 h-4 text-theme"
      })

    assert html =~ "hero-user-circle"
    assert html =~ "w-4 h-4 text-theme"
  end

  describe "error helpers" do
    test "translate_error mirrors message" do
      assert CoreComponents.translate_error({"can't be blank", []}) == "can't be blank"
    end

    test "translate_errors extracts field errors" do
      errors = [name: {"can't be blank", []}]
      assert CoreComponents.translate_errors(errors, :name) == ["can't be blank"]
    end
  end

  describe "tasks and assignment cells" do
    test "tasks_cell renders summary and percentages" do
      html =
        render_component(&CoreComponents.tasks_cell/1, %{
          summary: %{total: 10, in_progress: 3, finished: 4}
        })

      assert html =~ "data-total=\"10\""
      assert html =~ "width: 40%"
      assert html =~ "width: 30%"
    end

    test "assigned_cell renders placeholders and members" do
      html = render_component(&CoreComponents.assigned_cell/1, %{assigned: []})
      assert html =~ "—"

      html =
        render_component(&CoreComponents.assigned_cell/1, %{
          assigned: [%{name: "Jane", count: 2}]
        })

      assert html =~ "Jane"
      assert html =~ "(2)"
    end
  end

  defp slot(content) do
    [
      %{
        __slot__: :inner_block,
        __changed__: %{},
        inner_block: fn _, _ -> content end
      }
    ]
  end

  defp named_slot(name, content) when is_binary(content) do
    [
      %{
        __slot__: name,
        __changed__: %{},
        inner_block: fn _, _ -> content end
      }
    ]
  end

  defp named_slot(name, fun) when is_function(fun, 1) do
    [
      %{
        __slot__: name,
        __changed__: %{},
        inner_block: fn arg, _ -> fun.(arg) end
      }
    ]
  end
end
