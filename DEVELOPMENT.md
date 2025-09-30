# Development Guide

## Required Tools

- Elixir & Erlang (managed via `asdf` or similar)
- PostgreSQL
- Node/Tailwind tooling (`mix assets.setup` installs these automatically)
- **Security**: `gitleaks` (via `brew install gitleaks` or Docker fallback)

Run `mix setup` to install Elixir deps and prepare the database.

## Local Checks (`mix check`)

`mix check` runs the same validations that CI executes before allowing a push:

1. `mix hex.audit`
2. `mix deps.audit`
3. `./scripts/ci/secret_scan.sh` (gitleaks-based secret scan)
4. `mix compile --force --warnings-as-errors` (dev and test envs)
5. `mix format --check-formatted`
6. `mix credo --strict`
7. `mix sobelow --exit` (confidence ≥ medium)
8. `mix assets.setup` / `mix assets.build`
9. `mix dialyzer --plt` then `mix dialyzer --format short`
10. `mix ecto.create --quiet` & `mix ecto.migrate --quiet`
11. `COVERALLS_MINIMUM_COVERAGE=90 mix coveralls`
12. `mix docs`
13. `mix doctor --summary --raise`

## CI Pipeline

GitHub Actions (`.github/workflows/ci.yml`) mirrors the above steps, plus:

- Compiles with warnings-as-errors (test env) before running excoveralls.
- Publishes coverage using `mix coveralls.multiple --type local --type github`.
- Runs docs coverage via `mix doctor --summary --raise`.

Both the pre-push hook and CI use the same `scripts/ci/secret_scan.sh`, so secret
scanning must pass locally before code can be pushed.

## Git Hooks

Project uses `git_hooks` with the following configuration (see `config/config.exs`):

- `pre_push`: runs `./scripts/ci/secret_scan.sh` and `mix check`.
- Hooks auto-install on `mix deps.get` in development; adjust via
  `SKIP_SECRET_SCAN=true` if you must temporarily bypass the secret scan.

## Check Categories & Purpose

**Security**
- `mix deps.audit` / `mix hex.audit`: catch vulnerable Hex packages.
- `./scripts/ci/secret_scan.sh`: gitleaks-based scan to prevent leaked credentials.
- `mix sobelow --exit`: Phoenix security lint (XSS, CSRF, config issues).

**Quality & Style**
- `mix format --check-formatted`: enforce standard Elixir formatting.
- `mix credo --strict`: static analysis for code smells and readability.

**Correctness**
- `mix compile --force --warnings-as-errors` (dev/test): ensure clean builds.
- `mix test`: unit/integration tests.
- `mix coveralls`: enforce ≥90% coverage.
- `mix doctor --summary --raise`: documentation/spec coverage.
- `mix dialyzer`: type and success typing analysis.

**Infrastructure**
- `mix assets.setup` / `mix assets.build`: install/build frontend assets.
- `mix ecto.create` / `mix ecto.migrate`: verify database migrations run.
- `mix docs`: generate HTML docs to ensure doctests compile.
  - Docs are built during CI; main-branch pushes (or a manual dispatch with
    `deploy_docs=true`) publish the contents of `doc/` to GitHub Pages.
