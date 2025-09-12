defmodule DashboardSSD.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      DashboardSSDWeb.Telemetry,
      DashboardSSD.Vault,
      DashboardSSD.Repo,
      {DNSCluster, query: Application.get_env(:dashboard_ssd, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: DashboardSSD.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: DashboardSSD.Finch},
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

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DashboardSSDWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
