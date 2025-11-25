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

config :dashboard_ssd, :test_env?, true

# We don't run a server during test. If one is required,
# you can enable the server option below.
test_secret_key_base =
  System.get_env("TEST_SECRET_KEY_BASE", String.duplicate("b", 64))

config :dashboard_ssd, DashboardSSDWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: test_secret_key_base,
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

# Flag runtime as test so optional schedulers stay disabled and avoid sandbox races
config :dashboard_ssd, :env, :test

# Ensure background health check scheduler stays off during tests/coverage runs
config :dashboard_ssd, :health_checks, enabled: false

# Use the Notion mock in tests; production defaults to the real client.
config :dashboard_ssd, :notion_client, DashboardSSD.Integrations.NotionMock

# Use Tesla.Mock adapter in tests to avoid real HTTP requests
config :tesla, adapter: Tesla.Mock

test_drive_service_account_path =
  System.get_env("DRIVE_SERVICE_ACCOUNT_JSON") ||
    System.get_env("GOOGLE_APPLICATION_CREDENTIALS") ||
    Path.expand("../priv/service_accounts/test-drive-service-account.json", __DIR__)

test_notion_token =
  System.get_env("NOTION_TOKEN") ||
    System.get_env("NOTION_API_KEY") ||
    "notion-test-token"

test_projects_kb_parent_id =
  System.get_env("NOTION_PROJECTS_KB_PARENT_ID") ||
    System.get_env("NOTION_CONTRACTS_PAGE_PARENT_ID")

config :dashboard_ssd, :shared_documents_integrations,
  drive: [
    service_account_json_path: test_drive_service_account_path,
    root_folder_id: System.get_env("DRIVE_ROOT_FOLDER_ID") || "drive-root-folder-test"
  ],
  notion: [
    token: test_notion_token,
    projects_kb_parent_id: test_projects_kb_parent_id,
    contracts_database_id:
      System.get_env("NOTION_CONTRACTS_DATABASE_ID") || "notion-contracts-db-test",
    contracts_page_parent_id:
      System.get_env("NOTION_CONTRACTS_PAGE_PARENT_ID") || "notion-contracts-page-test"
  ]
