defmodule DashboardSSD.Repo do
  use Ecto.Repo,
    otp_app: :dashboard_ssd,
    adapter: Ecto.Adapters.Postgres
end
