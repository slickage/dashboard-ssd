defmodule DashboardSSDWeb.Navigation do
  @moduledoc "Shared navigation component used across theme layouts."
  use DashboardSSDWeb, :html

  alias DashboardSSD.Auth.Policy

  attr :current_user, :any, default: nil
  attr :current_path, :string, default: nil
  attr :variant, :atom, default: :sidebar
  attr :class, :string, default: ""

  def nav(assigns) do
    assigns
    |> assign(:items, nav_items(assigns.current_user))
    |> assign(:data_role, data_role(assigns.variant))
    |> assign(:nav_classes, nav_classes(assigns.variant, assigns.class))
    |> assign(:orientation, assigns.variant)
    |> render_nav()
  end

  defp render_nav(assigns) do
    ~H"""
    <nav data-role={@data_role} class={@nav_classes} aria-label="Primary">
      <ul class={list_classes(@orientation)}>
        <%= for item <- @items do %>
          <% active? = nav_active?(@current_path, item.path) %>
          <li>
            <.link navigate={item.path} class={link_classes(@orientation, active?)}>
              <span class="flex items-center gap-3">
                <span class={icon_classes(item.icon, active?)} aria-hidden="true"></span>
                <span class="font-medium leading-6">{item.label}</span>
              </span>
            </.link>
          </li>
        <% end %>
      </ul>
    </nav>
    """
  end

  defp nav_items(user) do
    [
      %{label: "Dashboard", path: ~p"/", icon: :home},
      %{label: "Projects", path: ~p"/projects", icon: :projects},
      %{label: "Clients", path: ~p"/clients", icon: :clients},
      %{label: "Knowledge Base", path: ~p"/kb", icon: :knowledge_base, permission: {:read, :kb}},
      %{
        label: "Analytics",
        path: ~p"/analytics",
        icon: :analytics,
        permission: {:read, :analytics}
      },
      %{label: "Settings", path: ~p"/settings", icon: :settings}
    ]
    |> Enum.filter(&allowed?(&1, user))
  end

  defp allowed?(%{permission: {action, subject}} = _item, user) do
    Policy.can?(user, action, subject)
  end

  defp allowed?(_item, _user), do: true

  defp nav_active?(nil, _path), do: false

  defp nav_active?(current_path, path) do
    normalized = URI.parse(current_path || "") |> Map.get(:path)

    cond do
      path == ~p"/" -> normalized == "/"
      true -> String.starts_with?(normalized || "", path)
    end
  end

  defp data_role(:sidebar), do: "theme-nav"
  defp data_role(_variant), do: nil

  defp nav_classes(:sidebar, extra) do
    [
      "flex h-full w-full flex-col",
      "text-theme-muted",
      extra
    ]
  end

  defp nav_classes(:topbar, extra) do
    [
      "flex w-full items-center gap-3 overflow-x-auto",
      "text-theme-muted",
      extra
    ]
  end

  defp list_classes(:sidebar), do: "flex flex-1 flex-col gap-1"
  defp list_classes(:topbar), do: "flex w-full items-center gap-1"

  defp link_classes(:sidebar, true) do
    "group flex items-center gap-3 rounded-xl bg-theme-surface-muted px-3 py-2 text-sm font-semibold text-theme-text shadow-theme-soft"
  end

  defp link_classes(:sidebar, false) do
    "group flex items-center gap-3 rounded-xl px-3 py-2 text-sm font-medium text-theme-muted hover:bg-theme-surface-muted hover:text-theme-text"
  end

  defp link_classes(:topbar, true) do
    "group flex items-center gap-2 rounded-full bg-theme-surface-muted px-3 py-2 text-sm font-semibold text-theme-text"
  end

  defp link_classes(:topbar, false) do
    "group flex items-center gap-2 rounded-full px-3 py-2 text-sm font-medium text-theme-muted hover:bg-theme-surface-muted hover:text-theme-text"
  end

  defp icon_classes(icon, active?) do
    base =
      case icon do
        :home -> "hero-home-mini"
        :projects -> "hero-squares-2x2-mini"
        :clients -> "hero-users-mini"
        :knowledge_base -> "hero-book-open-mini"
        :analytics -> "hero-chart-pie-mini"
        :settings -> "hero-cog-6-tooth-mini"
      end

    color =
      if active?,
        do: "text-theme-primary",
        else: "text-theme-muted group-hover:text-theme-primary"

    [base, "h-5 w-5", color]
  end
end
