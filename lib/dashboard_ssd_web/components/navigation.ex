defmodule DashboardSSDWeb.Navigation do
  @moduledoc "Shared navigation components for the theme layout."
  use DashboardSSDWeb, :html

  alias DashboardSSD.Auth.Policy
  alias Phoenix.LiveView.Rendered

  @icon_class_map %{
    home: "hero-home-mini",
    projects: "hero-squares-2x2-mini",
    clients: "hero-users-mini",
    knowledge_base: "hero-book-open-mini",
    analytics: "hero-chart-pie-mini",
    settings: "hero-cog-6-tooth-mini"
  }

  @active_icon_color "text-white"
  @inactive_icon_color "text-theme-muted group-hover:text-white"
  @default_icon_color "text-theme-muted"

  attr :current_user, :any, default: nil
  attr :current_path, :string, default: nil
  attr :variant, :atom, default: :sidebar
  attr :class, :string, default: ""

  @spec nav(map()) :: Rendered.t()
  def nav(assigns) do
    items = filtered_items(assigns.current_user, assigns.variant)

    assigns
    |> assign(:items, items)
    |> assign(:data_role, data_role(assigns.variant))
    |> assign(:nav_classes, nav_classes(assigns.variant, assigns.class))
    |> assign(:orientation, assigns.variant)
    |> render_nav()
  end

  defp render_nav(%{orientation: orientation} = assigns)
       when orientation in [:sidebar, :sidebar_admin] do
    ~H"""
    <nav data-role={@data_role} class={@nav_classes} aria-label="Primary">
      <ul class="flex flex-col items-center gap-5">
        <%= for item <- @items do %>
          <% active? = nav_active?(@current_path, item.path) %>
          <li>
            <.link
              navigate={item.path}
              class={sidebar_link_classes(item)}
              title={item.label}
              data-active={if active?, do: "true", else: nil}
              aria-current={if active?, do: "page", else: nil}
            >
              <span class="sr-only">{item.label}</span>
              <span class={icon_classes(item.icon, active?, @orientation)} aria-hidden="true"></span>
            </.link>
          </li>
        <% end %>
      </ul>
    </nav>
    """
  end

  defp render_nav(assigns) do
    ~H"""
    <nav data-role={@data_role} class={@nav_classes} aria-label="Primary">
      <ul class={list_classes(@orientation)}>
        <%= for item <- @items do %>
          <% active? = nav_active?(@current_path, item.path) %>
          <li>
            <.link
              navigate={item.path}
              class={link_classes(@orientation, active?)}
              aria-current={if active?, do: "page", else: nil}
            >
              <span class="flex items-center gap-2">
                <span class={icon_classes(item.icon, active?, :topbar)} aria-hidden="true"></span>
                <span class="font-medium leading-6">{item.label}</span>
              </span>
            </.link>
          </li>
        <% end %>
      </ul>
    </nav>
    """
  end

  defp filtered_items(user, :sidebar), do: nav_items(user, :main)
  defp filtered_items(user, :sidebar_admin), do: nav_items(user, :admin)
  defp filtered_items(user, _), do: nav_items(user, :all)

  defp nav_items(user, scope) do
    items =
      [
        %{label: "Dashboard", path: ~p"/", icon: :home, group: :main},
        %{label: "Projects", path: ~p"/projects", icon: :projects, group: :main},
        %{label: "Clients", path: ~p"/clients", icon: :clients, group: :main},
        %{
          label: "Knowledge Base",
          path: ~p"/kb",
          icon: :knowledge_base,
          group: :main,
          permission: {:read, :kb}
        },
        %{
          label: "Analytics",
          path: ~p"/analytics",
          icon: :analytics,
          group: :admin,
          permission: {:read, :analytics}
        },
        %{label: "Settings", path: ~p"/settings", icon: :settings, group: :admin}
      ]
      |> Enum.filter(&allowed?(&1, user))

    case scope do
      :all -> items
      target -> Enum.filter(items, fn item -> Map.get(item, :group, :main) == target end)
    end
  end

  defp allowed?(%{permission: {action, subject}}, user), do: Policy.can?(user, action, subject)
  defp allowed?(_item, _user), do: true

  defp nav_active?(nil, _path), do: false

  defp nav_active?(current_path, path) do
    normalized_path = Map.get(URI.parse(current_path || ""), :path) || ""

    if path == ~p"/" do
      normalized_path == "/"
    else
      String.starts_with?(normalized_path, path)
    end
  end

  defp data_role(:sidebar), do: "theme-nav"
  defp data_role(:sidebar_admin), do: "theme-nav-admin"
  defp data_role(_variant), do: nil

  defp nav_classes(:sidebar, extra),
    do: ["flex w-full flex-col items-center gap-10 text-theme-muted", extra]

  defp nav_classes(:sidebar_admin, extra),
    do: ["flex w-full flex-col items-center gap-10 text-theme-muted", extra]

  defp nav_classes(:topbar, extra) do
    [
      "flex w-full items-center gap-2 overflow-x-auto rounded-full bg-white/5 px-2 py-1 text-theme-muted",
      extra
    ]
  end

  defp list_classes(:topbar), do: "flex w-full items-center gap-2"

  defp list_classes(_), do: ""

  defp link_classes(:topbar, true) do
    "group flex items-center gap-2 rounded-full bg-white/10 px-3 py-2 text-sm font-semibold text-white"
  end

  defp link_classes(:topbar, false) do
    "group flex items-center gap-2 rounded-full px-3 py-2 text-sm font-medium text-theme-muted hover:bg-white/10 hover:text-white"
  end

  defp link_classes(_, _), do: ""

  defp sidebar_link_classes(item) do
    case Map.get(item, :group) do
      :admin -> "theme-nav-item border border-white/10 bg-white/5"
      _ -> "theme-nav-item"
    end
  end

  defp icon_classes(icon, active?, variant) do
    base = Map.fetch!(@icon_class_map, icon)
    [base, "h-5 w-5", icon_color_class(variant, active?)]
  end

  defp icon_color_class(variant, active?) when variant in [:sidebar, :sidebar_admin, :topbar] do
    if active?, do: @active_icon_color, else: @inactive_icon_color
  end

  defp icon_color_class(_variant, _active?), do: @default_icon_color
end
