defmodule DashboardSSDWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

     use DashboardSSDWeb, :controller
     use DashboardSSDWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  @doc """
  Returns the list of static file paths that should be served by the endpoint.
  """
  @spec static_paths() :: [String.t()]
  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  @doc """
  Defines imports and configuration for Phoenix routers.
  """
  @spec router() :: Macro.t()
  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  @doc """
  Defines imports and configuration for Phoenix channels.
  """
  @spec channel() :: Macro.t()
  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  @doc """
  Defines imports and configuration for Phoenix controllers.
  """
  @spec controller() :: Macro.t()
  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: DashboardSSDWeb.Layouts]

      import Plug.Conn
      use Gettext, backend: DashboardSSDWeb.Gettext

      unquote(verified_routes())
    end
  end

  @doc """
  Defines imports and configuration for Phoenix LiveViews.
  """
  @spec live_view() :: Macro.t()
  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {DashboardSSDWeb.Layouts, :app}

      unquote(html_helpers())
    end
  end

  @doc """
  Defines imports and configuration for Phoenix LiveComponents.
  """
  @spec live_component() :: Macro.t()
  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  @doc """
  Defines imports and configuration for Phoenix HTML components.
  """
  @spec html() :: Macro.t()
  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components and translation
      import DashboardSSDWeb.CoreComponents
      use Gettext, backend: DashboardSSDWeb.Gettext

      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  @doc """
  Defines configuration for Phoenix VerifiedRoutes.
  """
  @spec verified_routes() :: Macro.t()
  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: DashboardSSDWeb.Endpoint,
        router: DashboardSSDWeb.Router,
        statics: DashboardSSDWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  @spec __using__(atom()) :: Macro.t()
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
