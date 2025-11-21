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

## Commit Guidelines (Angular Convention)

Format
- <type>(<scope>): <subject>
- <blank line>
- <body>
- <blank line>
- <footer>

Rules
- Each line <= 100 characters
- Subject: imperative, present tense; lowercase first letter; no trailing period

Types
- build: build system or dependencies
- ci: CI configuration and scripts
- docs: documentation only changes
- feat: a new feature
- fix: a bug fix
- perf: performance improvements
- refactor: code change that neither fixes a bug nor adds a feature
- style: formatting/whitespace only (no logic changes)
- test: add or correct tests
- revert: revert a previous commit

Scope
- Use the area of work (e.g., models/users) or feature (e.g., meetings, fireflies, auth, schema)
- Example: feat(meetings): add association reset button

Subject examples
- good: add user info to model
- bad: added user info to model
- bad: adds user info to model

Body
- Use imperative, present tense
- Explain motivation and previous behavior
- Cover why the change is necessary, how it addresses the problem, and any side effects

Footer
- Reference issues (e.g., closes #69, resolves #420)
- BREAKING CHANGE: describe breaking changes clearly

Reverts
- revert(<scope>): <original header>
- Body: This reverts commit <hash>.
