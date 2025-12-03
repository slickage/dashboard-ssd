# Fireflies Integration Plan

Status: Draft for review
Scope: specs/001-add-meetings-fireflies

## Goals
- Load Fireflies summaries when viewing meetings.
- Clicking a past meeting shows Fireflies Summary notes and action items.
- Provide IEx helpers to query notes/action items directly for debugging.
- Next: pull previous meeting’s action items into the agenda field for the next occurrence.

## Current State Snapshot
- Cache exists: `lib/dashboard_ssd/meetings/cache_store.ex` wraps ETS cache for meetings.
- UI calls Fireflies:
  - List view builds agenda text using `DashboardSSD.Integrations.Fireflies.fetch_latest_for_series/2` when no manual agenda exists (`lib/dashboard_ssd_web/live/meetings_live/index.ex:62`, `:78`).
  - Detail modal shows last summary + action items using the same fetch (`lib/dashboard_ssd_web/live/meeting_live/detail_component.ex:24`, `:166`).
- Fireflies boundary is stubbed: `lib/dashboard_ssd/integrations/fireflies.ex` has TODO; it returns empty artifacts (parser removed).
- Env var present: `example.env` includes `FIREFLIES_API_TOKEN`, but `config/runtime.exs` does not yet wire it into the `:integrations` config.
- Meetings storage exists: `agenda_items` and `meeting_associations` tables + contexts.

## Key Design Choices
- API: Use Fireflies GraphQL endpoint `https://api.fireflies.ai/graphql` with Bearer token.
- Fetch strategy: Get latest processed “bite” (meeting) in the series and use structured fields (Summary schema) for notes and action_items when available; avoid local text parsing.
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
    - Use AI Apps Summary schema fields for notes/action_items when available; no local parsing.

3) Implement series-aware fetch in boundary
- Expand `DashboardSSD.Integrations.Fireflies.fetch_latest_for_series(series_id, opts \\ [])`:
  - Accept hints: `:title` (string), `:lookback_days` (default 90), `:limit` (default 25), `:ttl` (forward to cache).
  - Cache key: `{:series_artifacts, series_id}` via `Meetings.CacheStore.fetch/3`.
  - Resolution algorithm (in order):
    1. If cache has `{:series_map, series_id} => transcript_id`, use it directly.
    2. Query recent bites (mine: true, limit N). Prefer those with `created_from.id == series_id` when present.
    3. Fallback: fuzzy match by normalized title tokens within time window; pick latest `end_time`.
  - Once bite/transcript identified, fetch structured notes/action items (or fallback summary text minimally) and return without local parsing.

4) (Debugging step omitted)

5) Pass title hints from UI
- In `lib/dashboard_ssd_web/live/meetings_live/index.ex`: when deriving agenda text per meeting, call `Fireflies.fetch_latest_for_series(m.recurring_series_id, title: m.title)`.
- In `lib/dashboard_ssd_web/live/meeting_live/detail_component.ex`: call `Fireflies.fetch_latest_for_series(series_id, title: title)`.

6) Caching and refresh (Completed)
- Series artifacts cache: 24h TTL (configurable). `refresh_series/2` deletes cache and refetches.
- DB persistence: `fireflies_artifacts` keyed by `recurring_series_id` with `{transcript_id, accomplished, action_items (jsonb), bullet_gist, fetched_at}`. Persist only non-empty results.
- Retrieval order: ETS → DB → API; on success, populate ETS and upsert DB; on failure, return error and do not overwrite data.
- Rate-limit handling: Detect `too_many_requests` (or 429), surface human-readable retry time inline on the page (not a toast). Other errors show a generic inline message. Do not overwrite cache/DB on error; log details at debug (no tokens).
- Calendar has-event caching: For the three months in view, cache a Date => has_event? map for 5 minutes to bold days with meetings without repeated API calls.

7) Tests (Completed)
- Client: mapping (bites, transcript summary with notes/action_items/bullet_gist), token not logged, rate-limit mapping.
- Boundary: selection + caching behavior (API→DB→cache), DB fallback without API, rate-limit propagation (no DB writes).
- UI: inline rate-limit message on summary; robust handling when action_items is a string.

8) Documentation (Completed)
- Quickstart: document FIREFLIES_API_TOKEN and optional FIREFLIES_USER_ID; selected-date (±6 days) window; 3‑month calendar and bolding; rate-limit inline message; caching behavior.
- example.env includes both FIREFLIES_API_TOKEN and FIREFLIES_USER_ID with guidance.

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
3. Boundary (minimal): implement functions needed for IEx to fetch bites/summary for a series.
4. IEx helpers: add helpers and doc snippets (verify backend works in IEx).
5. Boundary (full): refine matching + add caching + refresh.
6. UI: pass title hints and wire to boundary in index + detail components.
7. Tests: client mapping + boundary selection with stubs.
8. Docs: quickstart and env note.

---

Please review and suggest adjustments (e.g., different matching strategy, cache TTL, IEx helper names), and I’ll proceed to implement Phase 1.
