defmodule DashboardSSDWeb.Navigation do
  @moduledoc "Shared navigation components for the theme layout."
  use DashboardSSDWeb, :html

  alias DashboardSSD.Auth.Policy
  alias Phoenix.LiveView.Rendered

  import DashboardSSDWeb.Layouts, only: [user_initials: 1, user_display_name: 1, user_role: 1]

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
  attr :mobile_menu_open, :boolean, default: false
  attr :open, :boolean, default: false

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

  @doc false
  @spec mobile_menu_button(map()) :: Rendered.t()
  def mobile_menu_button(assigns) do
    ~H"""
    <button
      type="button"
      class={"md:hidden inline-flex items-center justify-center rounded-md p-2 text-theme-muted hover:bg-white/10 hover:text-white focus:outline-none focus:ring-2 focus:ring-inset focus:ring-white #{assigns[:class] || ""}"}
      phx-click="toggle_mobile_menu"
      aria-controls="mobile-menu"
      aria-expanded="false"
    >
      <span class="sr-only">Open main menu</span>
      <svg
        class="block h-6 w-6"
        fill="none"
        viewBox="0 0 24 24"
        stroke-width="1.5"
        stroke="currentColor"
        aria-hidden="true"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"
        />
      </svg>
    </button>
    """
  end

  @doc false
  @spec mobile_drawer(map()) :: Rendered.t()
  def mobile_drawer(assigns) do
    items = filtered_items(assigns.current_user, :mobile)

    assigns
    |> assign(:items, items)
    |> assign(:version, assigns[:version] || "v0.1.0")
    |> render_mobile_drawer()
  end

  @doc false
  @spec render_mobile_drawer(map()) :: Rendered.t()
  defp render_mobile_drawer(assigns) do
    ~H"""
    <div
      class={"fixed inset-0 z-50 md:hidden #{if @open, do: "block", else: "hidden"}"}
      role="dialog"
      aria-modal="true"
    >
      <!-- Backdrop -->
      <div
        class="fixed inset-0 bg-black/50 backdrop-blur-sm"
        aria-hidden="true"
        phx-click="close_mobile_menu"
      >
      </div>
      
    <!-- Drawer panel -->
      <div class="fixed inset-y-0 right-0 w-full max-w-sm bg-theme-surface shadow-xl">
        <div class="flex h-full flex-col">
          <!-- Header -->
          <div class="flex items-center justify-between px-4 py-6 border-b border-white/10">
            <div class="flex items-center gap-3">
              <div class="flex h-8 w-8 items-center justify-center rounded-xl bg-theme-primary text-sm font-semibold text-white">
                DS
              </div>
              <div class="flex flex-col">
                <span class="text-lg font-semibold text-white">DashboardSSD</span>
                <span class="text-xs text-theme-muted">{@version}</span>
              </div>
            </div>
            <button
              type="button"
              class="inline-flex items-center justify-center rounded-md p-2 text-theme-muted hover:bg-white/10 hover:text-white focus:outline-none focus:ring-2 focus:ring-inset focus:ring-white"
              phx-click="close_mobile_menu"
            >
              <span class="sr-only">Close menu</span>
              <svg
                class="block h-6 w-6"
                fill="none"
                viewBox="0 0 24 24"
                stroke-width="1.5"
                stroke="currentColor"
                aria-hidden="true"
              >
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
          
    <!-- Navigation -->
          <nav class="flex-1 px-4 py-6" aria-label="Mobile navigation">
            <ul class="space-y-2">
              <%= for item <- @items do %>
                <% active? = nav_active?(@current_path, item.path) %>
                <li>
                  <.link
                    navigate={item.path}
                    class={"group flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors #{if active?, do: "bg-white/10 text-white", else: "text-theme-muted hover:bg-white/10 hover:text-white"}"}
                    phx-click="close_mobile_menu"
                  >
                    <span class={"flex h-5 w-5 items-center justify-center #{icon_color_class(:mobile, active?)}"}>
                      <span class={icon_classes(item.icon, active?, :mobile)}></span>
                    </span>
                    <span>{item.label}</span>
                  </.link>
                </li>
              <% end %>
            </ul>
          </nav>
          
    <!-- Footer -->
          <%= if @current_user do %>
            <div class="border-t border-white/10 px-4 py-4">
              <div class="flex items-center gap-3">
                <div class="flex h-8 w-8 items-center justify-center rounded-full bg-white/10 text-sm font-medium text-white">
                  {user_initials(@current_user)}
                </div>
                <div class="flex-1 min-w-0">
                  <p class="text-sm font-medium text-white truncate">
                    {user_display_name(@current_user)}
                  </p>
                  <p class="text-xs text-theme-muted">
                    {user_role(@current_user)}
                  </p>
                </div>
                <.link
                  href={~p"/logout"}
                  method="delete"
                  class="p-2 text-theme-muted hover:text-white transition-colors"
                  phx-click="close_mobile_menu"
                >
                  <svg
                    class="h-5 w-5"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke-width="1.5"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15m-3-6l3 3m0 0l-3 3m3-3H9"
                    />
                  </svg>
                </.link>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
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
  defp filtered_items(user, :mobile), do: nav_items(user, :all)
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
