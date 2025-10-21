defmodule DashboardSSD.MixListeners.CodeReloader do
  @moduledoc false

  def child_spec(opts) do
    if Code.ensure_loaded?(Phoenix.CodeReloader) and
         function_exported?(Phoenix.CodeReloader, :child_spec, 1) do
      Phoenix.CodeReloader.child_spec(opts)
    else
      %{
        id: __MODULE__,
        start: {__MODULE__, :start_link, [opts]},
        type: :worker,
        restart: :temporary
      }
    end
  end

  def start_link(_opts), do: :ignore
end

defmodule DashboardSSD.MixProject do
  use Mix.Project

  def project do
    [
      app: :dashboard_ssd,
      version: "1.4.2",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      dialyzer: dialyzer(),
      test_coverage: [tool: ExCoveralls],
      listeners: listeners(),
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.github": :test,
        "coveralls.html": :test,
        sobelow: :dev
      ],
      docs: [
        main: "readme",
        source_url: "https://github.com/slickage/dashboard-ssd",
        source_ref: System.get_env("DOCS_SOURCE_REF") || "phase/3.5-liveviews",
        homepage_url: "https://github.com/slickage/dashboard-ssd",
        extras: [
          "README.md": [title: "Overview"],
          "INTEGRATIONS.md": [title: "Integrations (Local)"],
          "NOTION.md": [title: "Notion Integration"],
          "specs/001-dashboard-init/tasks.md": [title: "001 MVP Tasks"],
          "specs/002-theme/tasks.md": [title: "002 Theme Tasks"],
          "specs/003-prepare-this-repo/tasks.md": [title: "003 Prepare Repo Tasks"],
          "specs/004-enhance-the-existing/tasks.md": [title: "004 Enhance Existing Tasks"]
        ],
        groups_for_extras: [
          "Getting Started": ["README.md"],
          Guides: ["INTEGRATIONS.md", "NOTION.md"],
          Specs: [
            "specs/001-dashboard-init/tasks.md",
            "specs/002-theme/tasks.md",
            "specs/003-prepare-this-repo/tasks.md",
            "specs/004-enhance-the-existing/tasks.md"
          ]
        ],
        nest_modules_by_prefix: [
          DashboardSSD,
          DashboardSSDWeb,
          DashboardSSD.Integrations
        ],
        groups_for_modules: [
          Contexts: [
            DashboardSSD.Accounts,
            DashboardSSD.Clients,
            DashboardSSD.Projects,
            DashboardSSD.Deployments,
            DashboardSSD.Notifications,
            DashboardSSD.Contracts
          ],
          Schemas: [
            ~r/^DashboardSSD\.(Accounts|Clients|Projects|Deployments|Notifications|Contracts)\.[A-Z].*/
          ],
          Integrations: [~r/^DashboardSSD\.Integrations(\.|$).*/],
          "Web · LiveViews": [~r/^DashboardSSDWeb\..*Live/],
          "Web · Components": [~r/^DashboardSSDWeb\..*Components/],
          "Web · Controllers": [~r/^DashboardSSDWeb\..*Controller/],
          "Web · Other": [
            DashboardSSDWeb.Router,
            DashboardSSDWeb.Endpoint,
            DashboardSSDWeb.Telemetry,
            DashboardSSDWeb.Gettext
          ]
        ],
        skip_undefined_reference_warnings_on: [
          "README.md",
          "INTEGRATIONS.md",
          "NOTION.md",
          "specs/001-dashboard-init/tasks.md",
          "specs/002-theme/tasks.md",
          "specs/003-prepare-this-repo/tasks.md",
          "specs/004-enhance-the-existing/tasks.md"
        ]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {DashboardSSD.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.8"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1"},
      {:floki, ">= 0.30.0", only: :test},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.5"},
      {:finch, "~> 0.13"},
      {:makeup_syntect, "~> 0.1"},
      {:makeup, "~> 1.1"},
      {:makeup_elixir, "~> 1.0"},
      {:makeup_erlang, "~> 1.0"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:mox, "~> 1.1", only: :test},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:git_hooks, "~> 0.8", only: :dev, runtime: false},
      {:sobelow, "~> 0.13", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: :test, runtime: false},
      {:cloak_ecto, "~> 1.2"},
      {:ueberauth, "~> 0.10"},
      {:ueberauth_google, "~> 0.10"},
      {:doctor, "~> 0.22", only: :dev, runtime: false},
      {:mix_audit, "~> 2.1", only: :dev, runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      check: [
        "hex.audit",
        "cmd MIX_ENV=dev mix deps.audit",
        "cmd MIX_ENV=dev mix hex.outdated || true",
        "cmd SKIP_SECRET_SCAN=${SKIP_SECRET_SCAN:-false} ./scripts/secret_scan.sh",
        "cmd MIX_ENV=dev mix compile --force --warnings-as-errors",
        "cmd MIX_ENV=test mix compile --force --warnings-as-errors",
        "format --check-formatted",
        "credo --strict",
        "cmd SOBELOW_CONFIDENCE=medium MIX_ENV=dev mix sobelow --skip --exit",
        "cmd MIX_ENV=dev mix assets.setup",
        "cmd MIX_ENV=dev mix assets.build",
        "cmd MIX_ENV=dev mix dialyzer --plt",
        "cmd MIX_ENV=dev mix dialyzer --format short",
        "cmd MIX_ENV=test mix ecto.create --quiet",
        "cmd MIX_ENV=test mix ecto.migrate --quiet",
        "cmd COVERALLS_MINIMUM_COVERAGE=90 MIX_ENV=test mix coveralls",
        "cmd MIX_ENV=dev mix docs",
        "cmd MIX_ENV=dev mix doctor --summary --raise"
      ],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind dashboard_ssd", "esbuild dashboard_ssd"],
      "assets.deploy": [
        "tailwind dashboard_ssd --minify",
        "esbuild dashboard_ssd --minify",
        "phx.digest"
      ]
    ]
  end

  defp dialyzer do
    [
      plt_core_path: "priv/plts",
      plt_local_path: "priv/plts",
      list_unused_filters: true
    ]
  end

  # Configure Mix listeners conditionally
  defp listeners do
    [DashboardSSD.MixListeners.CodeReloader]
  end
end
