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
- Elixir ~> 1.18 (Phoenix LiveView application) + Phoenix ~> 1.8, Phoenix LiveView ~> 1.1, Ecto/Repo, Ueberauth + Ueberauth Google, Tailwind/Alpine (front-end) (006-simplify-rbac)
- PostgreSQL (existing `roles`, `users`, `external_identities`, audit tables) (006-simplify-rbac)
- Elixir ~> 1.18 with Phoenix 1.8 & LiveView 1.1 + Phoenix/Ecto stack, ETS cache infrastructure (`DashboardSSD.Cache`, Projects cache helpers), Google Drive service account integration, Notion sync pipeline, Oban/GenServers for jobs (007-client-facing-sow)
- PostgreSQL (new `shared_documents`, optional `document_access_logs`, Drive folder mapping fields), Google Drive/Notion as external sources (007-client-facing-sow)

## Recent Changes
- 006-simplify-rbac: Added Elixir ~> 1.18 (Phoenix LiveView application) + Phoenix ~> 1.8, Phoenix LiveView ~> 1.1, Ecto/Repo, Ueberauth + Ueberauth Google, Tailwind/Alpine (front-end)
