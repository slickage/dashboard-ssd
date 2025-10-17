defmodule DashboardSSD.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      DashboardSSDWeb.Telemetry,
      DashboardSSD.Vault,
      DashboardSSD.Repo,
      DashboardSSD.KnowledgeBase.Cache,
      {DNSCluster, query: Application.get_env(:dashboard_ssd, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: DashboardSSD.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: DashboardSSD.Finch},
      health_checks_child(),
      analytics_scheduler_child(),
      # Start a worker by calling: DashboardSSD.Worker.start_link(arg)
      # {DashboardSSD.Worker, arg},
      # Start to serve requests, typically the last entry
      DashboardSSDWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DashboardSSD.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} = result ->
        # Add Phoenix.CodeReloader listener after Phoenix loads
        add_phoenix_code_reloader_listener()
        result
      other ->
        other
    end
  end

  defp health_checks_child do
    env = Application.get_env(:dashboard_ssd, :env) || :dev
    enabled = Application.get_env(:dashboard_ssd, :health_checks, [])[:enabled]

    if env != :test and enabled != false do
      DashboardSSD.HealthChecks.Scheduler
    else
      # Disabled in test or when explicitly disabled
      Supervisor.child_spec({Task, fn -> :ok end}, id: :hc_disabled, restart: :temporary)
    end
  end

  defp analytics_scheduler_child do
    env = Application.get_env(:dashboard_ssd, :env) || :dev
    enabled = Application.get_env(:dashboard_ssd, :analytics, [])[:enabled]

    if env != :test and enabled != false do
      DashboardSSD.Analytics.Scheduler
    else
      # Disabled in test or when explicitly disabled
      Supervisor.child_spec({Task, fn -> :ok end}, id: :analytics_disabled, restart: :temporary)
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DashboardSSDWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  # Add Phoenix.CodeReloader listener after application starts
  defp add_phoenix_code_reloader_listener do
    # Only add the listener if Phoenix.CodeReloader is available
    if Code.ensure_loaded?(Phoenix.CodeReloader) do
      try do
        # Try to start the listener using the child spec
        case Phoenix.CodeReloader.child_spec([]) do
          %{start: {mod, fun, args}} = spec ->
            case Supervisor.start_child(Mix.PubSub, spec) do
              {:ok, _pid} ->
                :ok
              {:error, {:already_started, _pid}} ->
                :ok
              {:error, reason} ->
                Logger.warning("Failed to start Phoenix.CodeReloader listener: #{inspect(reason)}")
            end
          _ ->
            Logger.warning("Phoenix.CodeReloader.child_spec/1 returned invalid spec")
        end
      rescue
        _ -> :ok # Ignore errors if listener can't be started
      end
    end
  end
end
