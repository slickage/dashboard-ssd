# Quickstart: Knowledge Base Explorer Enhancements

## Prerequisites
- Elixir 1.18.0 / OTP 27, Erlang 27.1.2, Node.js 20+
- Valid Notion integration token and curated database ID list in `config/runtime.exs`
- Mix dependencies installed (`mix deps.get`) and assets built (`npm install --prefix assets`)

## Local Setup
1. Export `NOTION_TOKEN` and optional variables in `.env` (see `NOTION.md` for full list):
   - `NOTION_TOKEN` (required)
   - `NOTION_CURATED_DATABASE_IDS` (comma-delimited curated database IDs)
   - `NOTION_AUTO_DISCOVER=true` (enable auto-discovery)
   - `NOTION_AUTO_DISCOVER_MODE=databases` (or `pages`)
2. Run `mix setup` to seed configuration and compile.
3. Start the server with `iex -S mix phx.server` and navigate to `/kb`.

## Development Workflow
- Implement context updates in `lib/dashboard_ssd/knowledge_base/` with unit tests under `test/dashboard_ssd/knowledge_base/` using Mox to simulate Notion responses.
- Update LiveView at `lib/dashboard_ssd_web/live/kb_live/index.ex` plus supporting components; exercise flows via LiveView tests.
- Keep UI consistent by leveraging existing card/list components in `DashboardSSDWeb.KbComponents`.
- Ensure accessibility compliance with ARIA labels, keyboard navigation, and alt text for images.

## Testing & Quality Gates
- Run `mix test test/dashboard_ssd/knowledge_base/ test/dashboard_ssd_web/live/kb_live/` for focused verification.
- Execute `mix credo --strict`, `mix format --check-formatted`, and `mix dialyzer` before submitting changes.
- Validate accessibility with LiveView tests covering keyboard navigation, ARIA labels, and alt text.
- Check telemetry output via test instrumentation assertions for Notion API calls.

## Observability & Telemetry
- Emit telemetry events for Notion API calls (`[:dashboard_ssd, :knowledge_base, :request]`).
- Log error states with structured metadata (`collection_id`, `document_id`, `reason`).
- Surface metrics in existing logging pipeline; confirm via `mix test` instrumentation assertions.

## Deployment Checklist
- Ensure environment config contains refreshed Notion database allowlist and any auto-discovery settings.
- Run database migrations (none expected) to confirm no accidental schema changes.
- After deploy, verify `/kb` loads collections (including auto-discovered), search, and document view using staging credentials.
- Confirm accessibility features (keyboard navigation, screen reader support) work as expected.

## Validation Results
- **Tests**: 499 tests passed, 1 unrelated failure in Linear integration.
- **Linting**: `mix credo --strict` - no issues.
- **Type Checking**: `mix dialyzer` - no errors.
- **Manual Smoke Test**: Start `iex -S mix phx.server`, navigate to `/kb`, verify collections load, search works, documents render with accessibility features (ARIA labels, keyboard navigation).
