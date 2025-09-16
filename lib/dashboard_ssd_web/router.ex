defmodule DashboardSSDWeb.Router do
  use DashboardSSDWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DashboardSSDWeb.Layouts, :root}
    plug :protect_from_forgery

    plug :put_secure_browser_headers, %{
      "content-security-policy" =>
        "default-src 'self'; img-src 'self' data:; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'"
    }

    plug DashboardSSDWeb.Plugs.CurrentUser
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", DashboardSSDWeb do
    pipe_through :browser

    get "/", PageController, :home

    live_session :default,
      on_mount: [{DashboardSSDWeb.UserAuth, :mount_current_user}],
      session: {__MODULE__, :build_live_session, []} do
    end

    live_session :require_authenticated,
      on_mount: [
        {DashboardSSDWeb.UserAuth, :mount_current_user},
        {DashboardSSDWeb.UserAuth, {:require, :read, :clients}}
      ],
      session: {__MODULE__, :build_live_session, []} do
      live "/clients", ClientsLive.Index, :index
      live "/clients/new", ClientsLive.Index, :new
      live "/clients/:id/edit", ClientsLive.Index, :edit
    end

    live_session :projects_read,
      on_mount: [
        {DashboardSSDWeb.UserAuth, :mount_current_user},
        {DashboardSSDWeb.UserAuth, {:require, :read, :projects}}
      ],
      session: {__MODULE__, :build_live_session, []} do
      live "/projects", ProjectsLive.Index, :index
      live "/projects/:id/edit", ProjectsLive.Index, :edit
    end

    get "/auth/:provider", AuthController, :request
    # Use distinct actions to avoid CSRF action reuse warnings
    get "/auth/:provider/callback", AuthController, :callback_get
    post "/auth/:provider/callback", AuthController, :callback_post
    delete "/logout", AuthController, :delete
    # Keep GET logout for backwards-compat, but map to a distinct action
    get "/logout", AuthController, :delete_get
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

  # helper for live_session to pass needed session data into LiveViews
  def build_live_session(conn) do
    path =
      conn.request_path <>
        if conn.query_string in [nil, ""], do: "", else: "?" <> conn.query_string

    %{
      "user_id" => Plug.Conn.get_session(conn, :user_id),
      "current_path" => path
    }
  end
end
