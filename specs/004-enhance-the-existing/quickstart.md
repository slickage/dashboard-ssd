# Quickstart: Knowledge Base Explorer Enhancements

## Prerequisites
- Elixir 1.18.0 / OTP 27, Erlang 27.1.2, Node.js 20+
- Valid Notion integration token and curated database ID list in `config/runtime.exs`
- Mix dependencies installed (`mix deps.get`) and assets built (`npm install --prefix assets`)

## Local Setup
1. Export `NOTION_TOKEN` and collection/database IDs (comma-delimited) in `.env`.
2. Run `mix setup` to seed configuration and compile.
3. Start the server with `iex -S mix phx.server` and navigate to `/kb`.

## Development Workflow
- Implement context updates in `lib/dashboard_ssd/knowledge_base/` with unit tests under `test/dashboard_ssd/knowledge_base/` using Mox to simulate Notion responses.
- Update LiveView at `lib/dashboard_ssd_web/live/kb_live/index.ex` plus supporting components; exercise flows via LiveView tests.
- Keep UI consistent by leveraging existing card/list components in `DashboardSSDWeb.Components`.

## Testing & Quality Gates
- Run `mix test test/dashboard_ssd/knowledge_base/ test/dashboard_ssd_web/live/kb_live/` for focused verification.
- Execute `mix credo --strict`, `mix format --check-formatted`, and `mix dialyzer` before submitting changes.
- Validate accessibility with LiveView tests covering keyboard navigation and ARIA labels.

## Observability & Telemetry
- Emit telemetry events for Notion API calls (`[:dashboard_ssd, :knowledge_base, :request]`).
- Log error states with structured metadata (`collection_id`, `document_id`, `reason`).
- Surface metrics in existing logging pipeline; confirm via `mix test` instrumentation assertions.

## Deployment Checklist
- Ensure environment config contains refreshed Notion database allowlist.
- Run database migrations (none expected) to confirm no accidental schema changes.
- After deploy, verify `/kb` loads collections, search, and document view using staging credentials.
