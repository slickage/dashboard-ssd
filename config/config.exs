# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :dashboard_ssd, :env, config_env()
config :dashboard_ssd, :test_env?, false
config :dashboard_ssd, :health_checks, interval_ms: 60_000, enabled: true
config :dashboard_ssd, :analytics, collection_interval_ms: 300_000, enabled: true

config :dashboard_ssd,
  namespace: DashboardSSD,
  ecto_repos: [DashboardSSD.Repo],
  generators: [timestamp_type: :utc_datetime]

# Default Notion client implementation; tests override as needed.
config :dashboard_ssd, :notion_client, DashboardSSD.Integrations.Notion

# Use bigints for primary and foreign keys
config :dashboard_ssd, DashboardSSD.Repo,
  migration_primary_key: [name: :id, type: :bigserial],
  migration_foreign_key: [type: :bigint]

# Configures the endpoint
config :dashboard_ssd, DashboardSSDWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: DashboardSSDWeb.ErrorHTML, json: DashboardSSDWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: DashboardSSD.PubSub,
  live_view: [signing_salt: "hn9xk+Sm"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :dashboard_ssd, DashboardSSD.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  dashboard_ssd: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  dashboard_ssd: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Redact sensitive fields from logs and params inspection
config :phoenix, :filter_parameters, [
  "password",
  "token",
  "refresh_token",
  "access_token",
  "authorization"
]

# Silence Tesla builder deprecation warning from ueberauth_google's dependency
config :tesla, disable_deprecated_builder_warning: true

config :ueberauth, Ueberauth,
  providers: [
    google:
      {Ueberauth.Strategy.Google,
       [
         # Include Drive and Calendar read-only to allow API access with the obtained token
         default_scope:
           "email profile https://www.googleapis.com/auth/drive.readonly https://www.googleapis.com/auth/calendar.readonly",
         # Request offline access to receive refresh_token (consent may be required)
         access_type: "offline",
         include_granted_scopes: true,
         prompt: "consent select_account",
         callback_methods: ["GET", "POST"]
       ]}
  ]

# Git hooks: enforce checks before pushing
if config_env() == :dev do
  config :git_hooks,
    auto_install: true,
    hooks: [
      pre_push: [
        tasks: [
          {:cmd, "mix check"}
        ]
      ]
    ]
end

# Provide curated Notion collection samples for local development. Runtime configuration
# will prefer environment variables, but dev/test environments can fall back to this data.
config :dashboard_ssd, DashboardSSD.KnowledgeBase,
  curated_collections_path: Path.expand("../priv/notion/collections.json", __DIR__),
  document_type_property_names: ["Type"],
  allowed_document_type_values: ["Wiki"],
  document_type_filter_exempt_ids: [],
  allow_documents_without_type?: true,
  auto_discover_mode: :databases,
  auto_page_collection_id: "kb:auto:pages",
  auto_page_collection_name: "Wiki Pages",
  auto_page_collection_description: "Top-level pages from the company wiki"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
