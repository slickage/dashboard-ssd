# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :dashboard_ssd,
  namespace: DashboardSSD,
  ecto_repos: [DashboardSSD.Repo],
  generators: [timestamp_type: :utc_datetime]

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

# Git hooks: enforce checks on pre-commit
config :git_hooks,
  auto_install: true,
  hooks: [
    pre_commit: [
      tasks: [
        {:mix_task, :format, ["--check-formatted"]},
        {:mix_task, :credo, ["--strict"]},
        {:mix_task, :dialyzer, []},
        {:mix_task, :test, []},
        {:mix_task, :docs, []}
      ]
    ]
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
