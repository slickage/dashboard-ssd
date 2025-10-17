defmodule DashboardSSDWeb.Navigation do
  @moduledoc "Shared navigation components for the theme layout."
  use DashboardSSDWeb, :html

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
      <.icon name="hero-bars-3-solid" class="h-6 w-6" />
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
                <a
                  href={DashboardSSDWeb.Layouts.github_releases_url()}
                  target="_blank"
                  class="text-xs text-theme-muted hover:text-white transition-colors"
                >
                  {@version}
                </a>
              </div>
            </div>
            <button
              type="button"
              class="inline-flex items-center justify-center rounded-md p-2 text-theme-muted hover:bg-white/10 hover:text-white focus:outline-none focus:ring-2 focus:ring-inset focus:ring-white"
              phx-click="close_mobile_menu"
            >
              <span class="sr-only">Close menu</span>
              <.icon name="hero-x-mark-solid" class="h-6 w-6" />
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
                  <.icon name="hero-arrow-right-on-rectangle-solid" class="h-5 w-5" />
                </.link>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @doc false
  @spec sidebar_footer(map()) :: Rendered.t()
  def sidebar_footer(assigns) do
    ~H"""
    <div class="mt-auto flex flex-col items-center gap-6 text-xs text-theme-muted">
      <a
        href={DashboardSSDWeb.Layouts.github_releases_url()}
        target="_blank"
        class="theme-pill hover:bg-white/10 transition-colors"
      >
        {assigns[:version] || "v0.1.0"}
      </a>

      <%= if assigns[:current_user] do %>
        <.link
          navigate={~p"/settings"}
          class="theme-nav-item border border-white/10 bg-white/5 text-sm uppercase"
          title={user_display_name(assigns[:current_user]) || "Open settings"}
        >
          <span class="sr-only">
            <%= if user_display_name(assigns[:current_user]) do %>
              Open settings for {user_display_name(assigns[:current_user])}
            <% else %>
              Open settings
            <% end %>
          </span>
          <span>{user_initials(assigns[:current_user])}</span>
        </.link>
      <% end %>
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

  defp nav_items(_user, scope) do
    items =
      [
        %{label: "Dashboard", path: ~p"/", icon: :home, group: :main},
        %{label: "Projects", path: ~p"/projects", icon: :projects, group: :main},
        %{label: "Clients", path: ~p"/clients", icon: :clients, group: :main},
        %{
          label: "Knowledge Base",
          path: ~p"/kb",
          icon: :knowledge_base,
          group: :main
        },
        %{
          label: "Analytics",
          path: ~p"/analytics",
          icon: :analytics,
          group: :admin
        },
        %{label: "Settings", path: ~p"/settings", icon: :settings, group: :admin}
      ]

    case scope do
      :all -> items
      target -> Enum.filter(items, fn item -> Map.get(item, :group, :main) == target end)
    end
  end

  defp nav_active?(current_path, path) do
    # Handle nil or empty current_path
    current_path = current_path || "/"

    # Debug logging removed

    # Parse and normalize paths
    current_normalized = normalize_path(current_path)
    target_normalized = normalize_path(path)

    if target_normalized == "/" do
      current_normalized == "/"
    else
      String.starts_with?(current_normalized, target_normalized)
    end
  end

  defp normalize_path(path) do
    case URI.parse(path) do
      %URI{path: parsed_path} when is_binary(parsed_path) -> parsed_path
      %URI{} -> "/"
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
