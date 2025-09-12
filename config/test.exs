import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :dashboard_ssd, DashboardSSD.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "dashboard_ssd_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :dashboard_ssd, DashboardSSDWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "gCr05Z3OZsYR8I7NTdZghXQjjyGqB6Dp1PE2pH5awp4cNnt4KgTn0aVogiQc9nbl",
  server: false

# In test we don't send emails
config :dashboard_ssd, DashboardSSD.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# OAuth mode: stubbed in tests
config :dashboard_ssd, :oauth_mode, :stub

# Enable dev/test-only routes for stubbed authorization endpoints
config :dashboard_ssd, dev_routes: true
