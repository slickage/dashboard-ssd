# Fireflies Integration Plan

Status: Draft for review
Scope: specs/001-add-meetings-fireflies

## Goals
- Load Fireflies summaries when viewing meetings.
- Clicking a past meeting shows Fireflies Summary notes and action items.
- Provide IEx helpers to query notes/action items directly for debugging.
- Next: pull previous meeting’s action items into the agenda field for the next occurrence.

## Current State Snapshot
- Parser exists: `lib/dashboard_ssd/meetings/parsers/fireflies_parser.ex` splits a freeform summary into `accomplished` and `action_items`.
- Cache exists: `lib/dashboard_ssd/meetings/cache_store.ex` wraps ETS cache for meetings.
- UI calls Fireflies: 
  - List view builds agenda text using `DashboardSSD.Integrations.Fireflies.fetch_latest_for_series/2` when no manual agenda exists (`lib/dashboard_ssd_web/live/meetings_live/index.ex:62`, `:78`).
  - Detail modal shows last summary + action items using the same fetch (`lib/dashboard_ssd_web/live/meeting_live/detail_component.ex:24`, `:166`).
- Fireflies boundary is stubbed: `lib/dashboard_ssd/integrations/fireflies.ex` has TODO; it returns empty artifacts.
- Env var present: `example.env` includes `FIREFLIES_API_TOKEN`, but `config/runtime.exs` does not yet wire it into the `:integrations` config.
- Meetings storage exists: `agenda_items` and `meeting_associations` tables + contexts.

## Key Design Choices
- API: Use Fireflies GraphQL endpoint `https://api.fireflies.ai/graphql` with Bearer token.
- Fetch strategy: Get latest processed “bite” (meeting) in the series, retrieve its summary text, and parse action items.
- Series matching: Prefer exact link if `created_from.id` equals a stable calendar meeting identifier; otherwise use title/time hints to match recent bites and cache the transcript mapping per series for reuse.
- Caching: Cache series artifacts via `Meetings.CacheStore` with configurable TTL (default 24h), plus explicit refresh.

## Implementation Steps (Phase 1)
1) Add runtime configuration for Fireflies token
- Update `config/runtime.exs` `:integrations` to include `fireflies_api_token: System.get_env("FIREFLIES_API_TOKEN")`.
- Ensure token is not logged anywhere; scrub sensitive headers in client logs.

2) Create Fireflies GraphQL client (Tesla)
- New module: `lib/dashboard_ssd/integrations/fireflies_client.ex`.
- Base URL: `https://api.fireflies.ai/graphql`; headers: `content-type: application/json`, `authorization: Bearer <token>`.
- Functions:
  - `list_bites(opts \\ []) :: {:ok, [map()]} | {:error, term()}`
    - Supports `mine: true`, `limit`, `skip`; optional time window filters if available; returns simplified bites with `id`, `transcript_id`, `name`, `start_time`, `end_time`, `summary`, `summary_status`, `created_from`.
  - `get_bite(id) :: {:ok, map()} | {:error, term()}`
    - Returns fields incl. `summary`, `summary_status`, `created_from`.
  - `get_summary_for_transcript(transcript_id) :: {:ok, %{notes: String.t() | nil, action_items: [String.t()]}} | {:error, term()}`
    - First try AI Apps outputs (Summary schema) if accessible; fallback to `bite.summary` text.

3) Implement series-aware fetch in boundary
- Expand `DashboardSSD.Integrations.Fireflies.fetch_latest_for_series(series_id, opts \\ [])`:
  - Accept hints: `:title` (string), `:lookback_days` (default 90), `:limit` (default 25), `:ttl` (forward to cache).
  - Cache key: `{:series_artifacts, series_id}` via `Meetings.CacheStore.fetch/3`.
  - Resolution algorithm (in order):
    1. If cache has `{:series_map, series_id} => transcript_id`, use it directly.
    2. Query recent bites (mine: true, limit N). Prefer those with `created_from.id == series_id` when present.
    3. Fallback: fuzzy match by normalized title tokens within time window; pick latest `end_time`.
  - Once bite/transcript identified, fetch summary text and action items; parse with `FirefliesParser.split_summary/1` when only freeform text is available. Cache result and `{:series_map, series_id} => transcript_id` for future.

4) Pass title hints from UI
- In `lib/dashboard_ssd_web/live/meetings_live/index.ex`: when deriving agenda text per meeting, call `Fireflies.fetch_latest_for_series(m.recurring_series_id, title: m.title)`.
- In `lib/dashboard_ssd_web/live/meeting_live/detail_component.ex`: call `Fireflies.fetch_latest_for_series(series_id, title: title)`.

5) IEx debug helpers
- Add in `DashboardSSD.Integrations.Fireflies`:
  - `debug_list_bites(opts \\ [mine: true, limit: 10])`
  - `debug_summary_for_transcript(transcript_id)` → returns notes text
  - `debug_action_items_for_transcript(transcript_id)` → returns array of items
- Purpose: quick manual checks during development (`iex -S mix`).

6) Caching and refresh
- Default TTL: 24h for series artifacts (configurable via opts).
- `refresh_series(series_id, opts \\ [])` keeps interface (already present) → delete cache + refetch.

7) Tests
- Parser: add cases for summaries with/without “Action Items” section; trimming, dedup.
- Client: stub responses; map bites to internal shape; ensure token scrubbed from logs.
- Boundary: with a stubbed client, verify hint-based selection and caching behavior.

8) Documentation
- Update `specs/001-add-meetings-fireflies/quickstart.md` with a short section on Fireflies token and IEx helpers.
- Confirm `example.env` already includes `FIREFLIES_API_TOKEN` (present) and add a brief note.

## Implementation Steps (Phase 2)
- Prefill agenda from previous meeting action items of the same series.
- UX: add button in the detail modal to “Copy previous action items into agenda” to persist them as a single text blob or discrete items.
- Logic: on click, write into `agenda_items` with `source: "manual"` (so user can edit), preserving existing manual content if present or appending with divider.

## Open Questions / Assumptions
- Does `created_from.id` reliably reference the Google Calendar event/series id? If not, we will rely on title/time heuristics and cache the transcript mapping.
- For AI App Summary: confirm the exact GraphQL shape for retrieving `notes` and `action_items`. We will start with `bite.summary` and parser, add the Apps-based fetch once verified.
- Desired cache TTL for Fireflies artifacts (defaulting to 24h acceptable?).

## Acceptance Criteria (Phase 1)
- Meetings index shows agenda preview derived from Fireflies when no manual agenda exists.
- Meeting modal shows last meeting’s summary and action items for meetings in a series with at least one completed prior bite.
- `IEx` helpers work: can list recent bites and fetch summary/action items by transcript id.
- Cache layer prevents repeated vendor calls, with a manual Refresh working from the modal.

## Rollout Plan
- Behind the scenes only (no feature flag required). If token not configured, UI remains functional with manual agenda only and shows “Summary pending”.
- Add logs at debug level for fetch outcomes and matching decisions; no PII or tokens in logs.

## Rough Task Breakdown (suggested commit order)
1. Runtime config: wire `FIREFLIES_API_TOKEN` into `:integrations`.
2. Client: add `FirefliesClient` with queries and token handling.
3. Boundary: implement `fetch_latest_for_series/2` with hints + cache, `refresh_series/2`.
4. UI: pass title hints to the boundary in index + detail components.
5. IEx helpers: add helpers and doc snippets.
6. Tests: parser + client mapping + boundary selection with stubs.
7. Docs: quickstart and env note.

---

Please review and suggest adjustments (e.g., different matching strategy, cache TTL, IEx helper names), and I’ll proceed to implement Phase 1.

