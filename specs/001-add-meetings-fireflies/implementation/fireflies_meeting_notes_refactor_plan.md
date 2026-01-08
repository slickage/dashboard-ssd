# Meeting Notes Refactor Plan

Align meeting notes to the exact meeting occurrence (event id + date), using a cache → DB → remote
(Fireflies) flow, with batched fetch support. Prefer project‑centric naming: “meeting notes” instead of
vendor terms.

## Goals
- Display the correct notes for each occurrence (calendar event id + occurrence date).
- Read path: cache → DB → Fireflies. Write‑through on successful fetches (persist + cache).
- Batch fetch for a date range to avoid N remote calls.
- Provide IEx commands to validate and tests with mocked Fireflies responses.

## Naming & Scope
- Schema/module naming: “meeting notes” (not “artifacts”).
- Keep `fireflies_artifacts` as a transitional/fallback source until full rollout.

## Data Model (DB)
- New table: `meeting_notes`
  - `calendar_event_id` (string, NOT NULL) — Google event id
  - `recurring_series_id` (string, NULL) — Google recurrence id (if any)
  - `occurrence_date` (date, NOT NULL) — date of the occurrence in the UI/user timezone
  - `transcript_id` (string, NULL)
  - `accomplished` (text, NULL)
  - `bullet_gist` (text, NULL)
  - `action_items` (map, NULL) — stored as JSONB; normalized to `%{"items" => [..]}`
  - `fetched_at` (utc_datetime, NULL)
  - `inserted_at`/`updated_at` (utc_datetime)
- Indexes/constraints
  - UNIQUE `[:calendar_event_id, :occurrence_date]`
  - INDEX on `[:recurring_series_id, :occurrence_date]`

## Cache Strategy
- Namespace: `meeting_notes`
- Key: `meeting_notes:<calendar_event_id>:<ISO-date>` (e.g. `meeting_notes:evt-1:2025-12-11`)
- TTL: 12h (configurable)
- Value (normalized): `%{action_items: [..], bullet_gist: ..., accomplished: ..., transcript_id: ..., fetched_at: ...}`

---

## Step 1 — Migration + Schema
- Files
  - `priv/repo/migrations/*_create_meeting_notes.exs`
  - `lib/dashboard_ssd/meetings/meeting_note.ex`
- Implementation details
  - Create the table/constraints above.
  - Ecto schema `DashboardSSD.Meetings.MeetingNote` with types/specs and `changeset/2`.
  - Normalize `action_items` on changeset: when list passed, store as `%{"items" => list}`.
- Validation
  - `mix ecto.migrate`
  - `mix compile`

## Step 2 — Store Layer (DB CRUD)
- Files
  - `lib/dashboard_ssd/meetings/notes_store.ex`
- API
  - `get(event_id, date) :: {:ok, note_map} | :not_found`
  - `upsert(event_id, date, attrs) :: :ok`
- Implementation details
  - Use `Repo.one` with `calendar_event_id` and `occurrence_date`.
  - Normalize `action_items` on read to list; map schema → public map.
  - `upsert/3` auto‑stamps `recurring_series_id` (when provided) and `fetched_at` defaulting to now.
- Validation
  - Unit tests (DataCase) for insert/update/read and normalization.

## Step 3 — Fireflies Boundary (Per‑event and Batched)
- Files
  - `lib/dashboard_ssd/integrations/fireflies.ex` (extend)
- API
  - `fetch_notes_for_event(event_map, opts) :: {:ok, note_map} | :not_found | {:error, term}`
  - `fetch_notes_for_events(event_maps, opts) :: {:ok, %{event_id => note_map}} | {:error, term}`
- Inputs (event_map)
  - `%{id, recurring_series_id, starts_at, ends_at, title, participants, meeting_link}`
- Implementation details
  - Prefer exact match by `meeting_link` or remote id if present.
  - Otherwise query transcripts by `[fromDate..toDate]` around `starts_at..ends_at` (± small tolerance),
    then filter locally by time proximity and optional title/participants.
  - Normalize to `%{action_items: [..], bullet_gist: ..., accomplished: ..., transcript_id: ..., fetched_at: ...}`.
  - Batched: build one window using `min(starts_at)..max(ends_at)`; 1 GraphQL call; map results to events locally.
- Testing/mocks
  - Use `Tesla.Mock.mock_global/1` to stub GraphQL responses.

## Step 4 — Orchestration (Cache → DB → Remote)
- Files
  - `lib/dashboard_ssd/meetings/notes.ex`
- API
  - `get_or_fetch(event_map, opts) :: {:ok, note} | :not_found | {:error, term}`
  - `get_or_fetch_many(event_maps, opts) :: {:ok, %{event_id => note}}`
- Implementation details
  - Cache key = `meeting_notes:<id>:<occurrence_date>`.
  - Flow for one event:
    1) Try cache; if hit, return.
    2) Try DB via `NotesStore.get/2`; on hit, populate cache and return.
    3) Call Fireflies boundary; on success, `NotesStore.upsert/3` + cache; on `:not_found`, return `:not_found`.
  - Flow for many events:
    - Partition into cache hits vs misses; query DB for misses; remaining → single batched remote call.
- Validation
  - Unit tests to assert short‑circuiting behavior; partial hits merged correctly.

## Step 5 — LiveView Wiring (Meetings list/detail)
- Files
  - `lib/dashboard_ssd_web/live/meetings_live/index.ex`
  - `lib/dashboard_ssd_web/live/meeting_live/detail_component.ex`
- Implementation details
  - After meetings are loaded for the selected range, build `events` list with required fields.
  - Call `Notes.get_or_fetch_many(events, mock?: params["mock"] == "1")`.
  - Attach notes per meeting: `meeting.notes` based on `id` + derived `occurrence_date` (see below).
  - Rendering shows only notes for that occurrence; if absent, show a friendly placeholder.
- Occurrence date derivation
  - Use the same timezone logic as the UI (e.g., `tz_offset`/selected date param) to compute the
    local occurrence date from `starts_at`.
- Validation
  - LiveView tests asserting that unrelated notes do not appear and correct ones render.

## Step 6 — Batched Fetch Optimization
- Implementation details
  - Build one transcript window from the current page’s events: `min(starts_at)..max(ends_at)`.
  - Map results to events by `meeting_link` or by nearest timestamp; tolerate small skews.
  - Persist/cache all matched notes; leave unmatched as `:not_found` without exceptions.
- Validation
  - Tests asserting only one external call for multiple events; multiple notes returned and persisted.

## Step 7 — Persistence Rules & Normalization
- On successful fetch/persist:
  - Trim strings; coerce `action_items` to list on read; store as `%{"items" => [...]}`.
  - Always set `fetched_at` to now if missing.
  - Upsert uniqueness on `[calendar_event_id, occurrence_date]`.

## Step 8 — Testing Plan
- NotesStore (DataCase)
  - get/2 returns normalized map; upsert insert/update; unique constraint enforced.
- Fireflies boundary
  - Exact match path using `meeting_link`.
  - Windowed search returns multiple; correct matching by time/title/participants.
  - `:not_found` path; error propagation (e.g., 429/HTTP error).
  - Batched query returns notes for multiple events.
- Orchestration
  - Cache hit short‑circuits; DB hit fills cache; remote hit persists and caches.
  - Many: partial cache/DB/remote mix.
- LiveView
  - Meetings list and detail render only their own notes; placeholder when absent.
- Mocks
  - Use `Tesla.Mock.mock_global/1` in setup; restore adapter on exit where needed.

## Step 9 — IEx Validation
- Start IEx: `iex -S mix`
- Example event
  ```elixir
  event = %{
    id: "evt-1",
    recurring_series_id: "series-1",
    starts_at: ~U[2025-12-11 17:00:00Z],
    ends_at: ~U[2025-12-11 18:00:00Z],
    title: "Weekly – Client A",
    participants: ["a@x.com", "b@x.com"],
    meeting_link: "https://meet.google.com/abc",
    occurrence_date: ~D[2025-12-11]
  }
  DashboardSSD.Meetings.Notes.get_or_fetch(event, mock?: true)
  ```
- Batch
  ```elixir
  events = [event1, event2, event3]
  DashboardSSD.Meetings.Notes.get_or_fetch_many(events, mock?: true)
  ```
- Direct store
  ```elixir
  DashboardSSD.Meetings.NotesStore.get("evt-1", ~D[2025-12-11])
  ```

## Step 10 — Backfill (Optional)
- For recent ranges (e.g., last 30 days):
  - Load meetings via existing calendar integration; call `get_or_fetch_many/2` with `mock?: false`.
  - Seed DB while caching.

## Step 11 — Rollout & Checks
- Sequence
  1) Step 1: Schema/migration → compile/migrate.
  2) Step 2: NotesStore → unit tests green.
  3) Step 3: Fireflies per‑event/batch APIs → boundary tests green with mocks.
  4) Step 4: Orchestration → unit tests for cache/DB/remote paths.
  5) Step 5: LiveView wiring → LV tests assert per‑occurrence notes.
  6) Step 6: Batched optimization → verify single-call behavior.
  7) Backfill if desired.
- Commands
  - `mix format && mix credo --strict`
  - `mix test`
  - `mix dialyzer`
  - `mix check`
- Commit guidelines
  - Atomic commits per step, Angular format, explicit paths staged, run `mix format` before committing.

## Edge Cases & Notes
- Timezone: compute `occurrence_date` using the same logic as the UI’s current tz (e.g., `tz_offset`).
- Missing transcripts: return `:not_found`; do not show unrelated notes.
- Series fallback: keep `fireflies_artifacts` as a temporary fallback; log when used.
- Errors/rate limits: propagate errors from boundary; cache short TTL negative results only if desired (optional).

## Acceptance Criteria (per step)
- Step 1: Migration + schema compile and migrate successfully.
- Step 2: NotesStore read/write paths work; normalization correct.
- Step 3: Boundary returns correct notes for event and batch with mocks.
- Step 4: Orchestration respects cache→DB→remote, persists and caches results.
- Step 5: LiveView shows only the matching occurrence notes.
- Step 6: Batch fetch reduces remote calls for multiple events.
- Tests: cover positive/negative paths; no external API calls under MIX_ENV=test.
