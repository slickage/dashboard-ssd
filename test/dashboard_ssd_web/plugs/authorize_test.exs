defmodule DashboardSSDWeb.Plugs.AuthorizeTest do
  use ExUnit.Case, async: true
  import Plug.Conn
  import Plug.Test

  alias DashboardSSD.Accounts.User
  alias DashboardSSDWeb.Plugs.Authorize

  defp user(role_name) do
    %User{id: 1, role: %{name: role_name}}
  end

  test "init converts tuple options into map" do
    assert %{action: :read, subject: :projects} = Authorize.init({:read, :projects})
  end

  test "init with map returns original map" do
    opts = %{action: :read, subject: :kb}
    assert Authorize.init(opts) == opts
  end

  test "call allows request when policy permits" do
    conn =
      conn(:get, "/")
      |> assign(:current_user, user("admin"))

    opts = Authorize.init({:write, :anything})
    conn = Authorize.call(conn, opts)

    refute conn.halted
  end

  test "call halts request when forbidden" do
    conn =
      conn(:get, "/")
      |> assign(:current_user, nil)

    opts = Authorize.init({:read, :projects})
    conn = Authorize.call(conn, opts)

    assert conn.halted
    assert conn.status == 403
    assert conn.resp_body == "Forbidden"
  end
end
