defmodule DashboardSSDWeb.NavigationFiltersTest do
  use DashboardSSDWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias DashboardSSDWeb.Navigation

  defmodule NavHarness do
    use Phoenix.LiveView
    import DashboardSSDWeb.Navigation

    @impl true
    def mount(_p, _s, socket) do
      {:ok, assign(socket, %{user: nil, path: "/", variant: :sidebar})}
    end

    @impl true
    def render(assigns) do
      ~H"""
      <.nav current_user={@user} current_path={@path} variant={@variant} />
      """
    end

    @impl true
    def handle_info({:assigns, map}, socket) when is_map(map), do: {:noreply, assign(socket, map)}
  end

  test "nav highlights active root and includes items without capability", %{conn: conn} do
    {:ok, view, _} = live_isolated(conn, NavHarness)
    html = render(view)
    # Root link has aria-current when current_path=/
    assert html =~ ~s(aria-current="page")
    # Meetings has no capability requirement
    assert html =~ ">Meetings<"
  end

  test "topbar variant uses link classes and active state logic", %{conn: conn} do
    {:ok, view, _} = live_isolated(conn, NavHarness)
    send(view.pid, {:assigns, %{variant: :topbar, path: "/projects"}})
    html = render(view)
    assert html =~ "Projects"
    # Active class logic applied by link_classes(:topbar, true)
    assert html =~ "font-semibold"
  end
end

