defmodule DashboardSSD.Repo do
  @moduledoc "Ecto repository for the DashboardSSD application."
  use Ecto.Repo,
    otp_app: :dashboard_ssd,
    adapter: Ecto.Adapters.Postgres
end
