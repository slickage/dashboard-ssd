defmodule DashboardSSD.Repo do
  @moduledoc """
  Ecto repository for the DashboardSSD application.

    - Configured in `config/*.exs` with runtime credentials and pooling strategy.
  - Supervised as part of the OTP application so all contexts share a single connection pool.
  - Provides `Sandbox` support for tests and mixes in Postgres-specific conveniences.
  """
  use Ecto.Repo,
    otp_app: :dashboard_ssd,
    adapter: Ecto.Adapters.Postgres
end
