defmodule DashboardSSDWeb.Router do
  use DashboardSSDWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DashboardSSDWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug DashboardSSDWeb.Plugs.CurrentUser
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", DashboardSSDWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/auth/:provider", AuthController, :request
    get "/auth/:provider/callback", AuthController, :callback
    post "/auth/:provider/callback", AuthController, :callback
    delete "/logout", AuthController, :delete
    get "/logout", AuthController, :delete
  end

  if Application.compile_env(:dashboard_ssd, :dev_routes) do
    scope "/protected", DashboardSSDWeb do
      pipe_through :browser

      get "/projects", ProtectedController, :projects
      get "/clients", ProtectedController, :clients
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", DashboardSSDWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:dashboard_ssd, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: DashboardSSDWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
