# Agent Guidelines for DashboardSSD

## Commands
- **Build**: `mix compile`
- **Test all**: `mix test`
- **Test single file**: `mix test path/to/test.exs`
- **Test single test**: `mix test path/to/test.exs:line_number`
- **Lint**: `mix credo --strict`
- **Format**: `mix format`
- **Type check**: `mix dialyzer`
- **Full check**: `mix check` (format + lint + dialyzer + test + docs)
- **Setup**: `mix setup`

## Code Style
- **Language**: Elixir/Phoenix with Ecto, LiveView
- **Formatting**: `mix format` (120 char lines, imports Phoenix/Ecto/LiveView)
- **Naming**: CamelCase modules, snake_case functions/variables
- **Types**: `@type t :: %__MODULE__{...}` for schemas
- **Imports**: Group at top after module docstring
- **Error handling**: Pattern matching, Ecto changesets for validation
- **Documentation**: Module docs required, function docs optional
- **Testing**: `DashboardSSD.DataCase`, async: true when possible
- **Security**: No `IO.inspect` in production code

## Active Technologies
- Elixir (per repo), Phoenix LiveView + Ecto; Google Calendar API (OAuth2); Fireflies.ai API (token-based); JSON/HTTP client; Phoenix LiveView UI (001-add-meetings-fireflies)
- PostgreSQL (minimal tables for manual agenda items, associations, and optional Fireflies cache) (001-add-meetings-fireflies)

## Recent Changes
- 001-add-meetings-fireflies: Added Elixir (per repo), Phoenix LiveView + Ecto; Google Calendar API (OAuth2); Fireflies.ai API (token-based); JSON/HTTP client; Phoenix LiveView UI
