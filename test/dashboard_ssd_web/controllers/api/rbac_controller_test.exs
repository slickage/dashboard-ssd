defmodule DashboardSSDWeb.API.RBACControllerTest do
  use DashboardSSDWeb.ConnCase, async: true

  alias DashboardSSD.Accounts
  alias DashboardSSD.Auth.Capabilities

  setup do
    Enum.each(["admin", "employee", "client"], &Accounts.ensure_role!/1)
    :ok
  end

  describe "GET /api/rbac/roles" do
    test "returns capability mappings for admin users", %{conn: conn} do
      conn = conn |> log_in_role("admin")

      response =
        conn
        |> get(~p"/api/rbac/roles")
        |> json_response(200)

      assert %{"data" => roles} = response

      assert Enum.any?(roles, fn role ->
               role["role"] == "admin" and "settings.rbac" in List.wrap(role["capabilities"])
             end)
    end

    test "returns forbidden for users without RBAC settings capability", %{conn: conn} do
      conn = conn |> log_in_role("employee")

      conn = get(conn, ~p"/api/rbac/roles")
      assert conn.status == 403
    end
  end

  describe "PUT /api/rbac/roles/:role_name/capabilities" do
    test "replaces capabilities when authorized", %{conn: conn} do
      conn = conn |> log_in_role("admin")

      payload = %{"capabilities" => ["dashboard.view", "settings.personal"]}

      response =
        conn
        |> put(~p"/api/rbac/roles/employee/capabilities", payload)
        |> json_response(200)

      assert %{"role" => "employee", "capabilities" => caps} = response
      assert Enum.sort(caps) == Enum.sort(payload["capabilities"])
    end

    test "returns not found for unknown role", %{conn: conn} do
      conn = conn |> log_in_role("admin")

      conn =
        conn
        |> put(~p"/api/rbac/roles/unknown/capabilities", %{"capabilities" => []})

      assert conn.status == 404
      assert json_response(conn, 404)["error"] =~ "Unknown role"
    end

    test "rejects invalid capability codes", %{conn: conn} do
      conn = conn |> log_in_role("admin")

      conn =
        conn
        |> put(~p"/api/rbac/roles/employee/capabilities", %{"capabilities" => ["does.not.exist"]})

      assert conn.status == 400
      assert json_response(conn, 400)["error"] =~ "Unknown capability"
    end

    test "prevents removing mandatory admin capabilities", %{conn: conn} do
      conn = conn |> log_in_role("admin")

      conn =
        conn
        |> put(~p"/api/rbac/roles/admin/capabilities", %{"capabilities" => ["dashboard.view"]})

      assert conn.status == 400
      assert json_response(conn, 400)["error"] =~ "Admin roles must retain"
    end
  end

  describe "POST /api/rbac/reset" do
    test "restores default assignments", %{conn: conn} do
      conn = conn |> log_in_role("admin")

      payload = %{"capabilities" => ["dashboard.view"]}

      _ =
        conn
        |> put(~p"/api/rbac/roles/client/capabilities", payload)
        |> json_response(200)

      response =
        conn
        |> post(~p"/api/rbac/reset")
        |> response(202)

      assert response =~ "reset"

      assert Enum.sort(Accounts.capabilities_for_role("client")) ==
               Enum.sort(Map.fetch!(Capabilities.default_assignments(), "client"))
    end

    test "forbids reset without RBAC capability", %{conn: conn} do
      conn = conn |> log_in_role("employee")

      conn = post(conn, ~p"/api/rbac/reset")
      assert conn.status == 403
    end
  end

  defp log_in_role(conn, role_name) do
    role = Accounts.ensure_role!(role_name)
    defaults = Capabilities.default_assignments()
    capabilities = Map.get(defaults, role_name, [])

    {:ok, _} = Accounts.replace_role_capabilities(role, capabilities, granted_by_id: nil)

    user =
      case Accounts.get_user_by_email("#{role_name}@example.com") do
        nil ->
          {:ok, user} =
            Accounts.create_user(%{
              email: "#{role_name}@example.com",
              name: String.capitalize(role_name),
              role_id: role.id
            })

          user

        user ->
          user
      end

    conn
    |> Plug.Conn.put_req_header("accept", "application/json")
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_id, user.id)
  end
end
