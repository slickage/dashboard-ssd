defmodule DashboardSSD.Application do
  @moduledoc """
  OTP application callback responsible for bootstrapping the supervision tree.

    - Starts shared infrastructure such as Repo, PubSub, Vault, Finch, and background schedulers.
  - Guards optional workers (health checks, analytics, knowledge-base warmers) behind env/config toggles.
  - Propagates configuration changes to `DashboardSSDWeb.Endpoint` on hot upgrades.
  """
  use Application

  @on_load :ensure_documented_modules_loaded

  defp ensure_documented_modules_loaded do
    Application.spec(:dashboard_ssd, :modules)
    |> case do
      nil ->
        :ok

      modules when is_list(modules) ->
        Enum.each(modules, &Code.ensure_loaded?/1)
        :ok
    end
  end

  @impl true
  def start(_type, _args) do
    children = [
      DashboardSSDWeb.Telemetry,
      DashboardSSD.Vault,
      DashboardSSD.Repo,
      {Task.Supervisor, name: DashboardSSD.TaskSupervisor},
      DashboardSSD.Cache,
      {DNSCluster, query: Application.get_env(:dashboard_ssd, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: DashboardSSD.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: DashboardSSD.Finch},
      health_checks_child(),
      analytics_scheduler_child(),
      knowledge_base_cache_warmer_child(),
      # Start a worker by calling: DashboardSSD.Worker.start_link(arg)
      # {DashboardSSD.Worker, arg},
      # Start to serve requests, typically the last entry
      DashboardSSDWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DashboardSSD.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp health_checks_child do
    env = Application.get_env(:dashboard_ssd, :env) || :dev
    enabled = Application.get_env(:dashboard_ssd, :health_checks, [])[:enabled]

    if env != :test and enabled != false do
      DashboardSSD.Projects.HealthChecksScheduler
    else
      # Disabled in test or when explicitly disabled
      Supervisor.child_spec({Task, fn -> :ok end}, id: :hc_disabled, restart: :temporary)
    end
  end

  defp analytics_scheduler_child do
    env = Application.get_env(:dashboard_ssd, :env) || :dev
    enabled = Application.get_env(:dashboard_ssd, :analytics, [])[:enabled]

    if env != :test and enabled != false do
      DashboardSSD.Analytics.MetricsScheduler
    else
      # Disabled in test or when explicitly disabled
      Supervisor.child_spec({Task, fn -> :ok end}, id: :analytics_disabled, restart: :temporary)
    end
  end

  defp knowledge_base_cache_warmer_child do
    env = Application.get_env(:dashboard_ssd, :env) || :dev
    kb_config = Application.get_env(:dashboard_ssd, DashboardSSD.KnowledgeBase, [])
    enabled? = Keyword.get(kb_config, :cache_warmer?, true)

    if env != :test and enabled? do
      DashboardSSD.CacheWarmer
    else
      Supervisor.child_spec(
        {Task, fn -> :ok end},
        id: :cache_warmer_disabled,
        restart: :temporary
      )
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DashboardSSDWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
