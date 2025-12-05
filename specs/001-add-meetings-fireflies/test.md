# Test Plan — Meetings + Integrations (001-add-meetings-fireflies)

This plan adds tests only for code introduced by this branch. No ignore-list changes.

## Scope

Add tests for the following files (branch-added):

- lib/dashboard_ssd/integrations/fireflies.ex
- lib/dashboard_ssd/integrations/fireflies_client.ex
- lib/dashboard_ssd/integrations/google_calendar.ex
- lib/dashboard_ssd/integrations/google_token.ex
- lib/dashboard_ssd/meetings/agenda.ex
- lib/dashboard_ssd/meetings/agenda_item.ex
- lib/dashboard_ssd/meetings/associations.ex
- lib/dashboard_ssd/meetings/cache_store.ex
- lib/dashboard_ssd/meetings/fireflies_artifact.ex
- lib/dashboard_ssd/meetings/fireflies_store.ex
- lib/dashboard_ssd/meetings/meeting_association.ex
- lib/dashboard_ssd_web/components/calendar.ex
- lib/dashboard_ssd_web/components/navigation.ex
- lib/dashboard_ssd_web/date_helpers.ex
- lib/dashboard_ssd_web/live/meeting_live/detail_component.ex
- lib/dashboard_ssd_web/live/meeting_live/index.ex
- lib/dashboard_ssd_web/live/meetings_live/index.ex

## Test Setup

- Use `DashboardSSD.DataCase` for context/schema tests; `ConnCase`/LiveViewTest for UI.
- HTTP stubbing per-test via `Tesla.Mock.mock/1` (adapter already set to Tesla.Mock in test).
- Fireflies tests: set `Application.put_env(:dashboard_ssd, :integrations, fireflies_api_token: "tok")` as needed.
- Google tests: seed `ExternalIdentity` for token paths; use Tesla.Mock for refresh endpoint.
- Cache: rely on globally started `DashboardSSD.Cache`; guard on `Process.whereis/1` if needed.
- Mark cache/global-process tests `async: false`.

## Process & Coverage Discipline

- After each test file is implemented, run `mix test` to verify correctness and catch regressions.
- Track code coverage locally (e.g., `mix test --cover` or your coverage tool) and ensure coverage increases with each batch.
- Before writing tests for a module, scan the module to enumerate functions and branches; include cases to exercise each function where practical, including error paths and option permutations.
- Prefer small, deterministic unit tests; use explicit HTTP mocks to reach otherwise unreachable branches (rate limits, non-200s, empty payloads).

### Coverage-Driven Prioritization (coverage.txt)

- Maintain a `coverage.txt` file with per-file coverage for the plan’s files.
- Before implementing the next tests:
  - Parse `coverage.txt` and identify the lowest-covered files from this plan.
  - Select the lowest one (or bottom 2–3 if time allows) and focus efforts there first.
  - For each selected file:
    - Scan the module to list public functions (and notable private helpers) and their branches.
    - Cross-check which functions/branches are currently exercised by existing tests.
    - Write targeted tests for unexercised functions/branches (including error paths and input permutations) until coverage meaningfully improves.
  - Re-run `mix test` (and coverage) after each addition to confirm progress.

### Line-Level Gaps (no_hit.txt)

- Maintain a `no_hit.txt` file listing file paths and line numbers with zero hits (from coveralls.json parsing).
- Before implementing tests for a selected low-coverage file:
  - Open `no_hit.txt` and filter entries for that file.
  - For each no-hit line, map it to the nearest function/branch and identify a scenario to execute it (e.g., specific params, error path, edge case).
  - Write focused tests to hit those lines (avoid over-broad assertions; prefer precise triggers).
  - Validate locally with `mix test`; re-check coverage to ensure lines are now exercised.

## Integrations — FirefliesClient (unit)

Module: `DashboardSSD.Integrations.FirefliesClientTest` (DataCase, async: true)

- list_bites/1
  - 200 OK returns bites; variables clamp `limit` to 50; nils dropped.
  - GraphQL errors list → {:error, {:rate_limited, msg}} when `code` TooManyRequests; otherwise {:graphql_error, errs}.
  - Non-200 → {:http_error, status, body}; {:error, reason} passthrough.
- get_bite/1
  - 200 OK with `data.bite` → {:ok, bite}; empty → {:error, :not_found}.
  - Errors mapping as above.
- get_summary_for_transcript/1
  - Picks first bite, returns `%{notes, action_items: [], bullet_gist: nil}`; empty → notes=nil.
  - 429 HTTP → {:error, {:rate_limited, ...}}; other errors mapped.
- list_transcripts/1
  - Variables precedence: mine vs configured_user_id vs explicit exclusives; string-list sanitization.
  - 200 OK returns list; errors mapped.
- get_transcript_summary/1
  - Prefers `overview` then `short_summary`; returns `bullet_gist`; defaults when missing.
- helpers
  - configured_user_id/0 from config/env; token/0 env precedence; strip_bearer/1 removes prefix.

## Integrations — Fireflies (boundary)

Module: `DashboardSSD.Integrations.FirefliesTest` (DataCase, async: false)

- fetch_latest_for_series/2
  - Returns DB-cached artifacts via `FirefliesStore.get/1` without API calls.
  - When missing: matches bites.mine by `created_from.id == series`, persists `{series_map, series}` and fetches transcript summary.
  - Fallback to bites.my_team when mine fails; then fallback to title-based transcript search.
  - Rate limit propagation: `{:error, {:rate_limited, _}}` preserved; `refresh_series/2` clears cache then refetches.

## Integrations — GoogleCalendar (unit)

Module: `DashboardSSD.Integrations.GoogleCalendarTest` (async: true)

- list_upcoming/3
  - `mock: :sample` returns sample events.
  - With `:token`, makes HTTP call; maps items (id, title, start_at/end_at, recurring_series_id).
  - Missing token returns `{:ok, []}`; non-200 → {:error, {:http_error, status, body}}.
- list_upcoming_for_user/4
  - Delegates using token from `GoogleToken`; non-integer/struct user → {:error, :no_token}.
- recurrence_id/1 chooses recurringEventId then :recurring_series_id.
- map_event/1 + parse_time handle dateTime and all-day `date`.

## Integrations — GoogleToken (unit/integration)

Module: `DashboardSSD.Integrations.GoogleTokenTest` (DataCase, async: true)

- get_access_token_for_user/1
  - Returns non-expiring token as-is.
  - Refreshes when expired: mocks 200 token; updates Repo with new token/expires_at.
  - Missing refresh_token → {:error, :no_token}.
  - Missing env CLIENT_ID/SECRET → {:error, {:missing_env, key}}.
  - Non-200 refresh → {:error, {:http_error, status, body}}; invalid response → {:error, :invalid_response}.

## Meetings — Agenda (unit/integration)

Module: `DashboardSSD.Meetings.AgendaTest` (DataCase, async: true)

- list/create/update/delete flow; default `source = "manual"` on create.
- reorder_items/2 updates positions; unknown ids ignored; transaction ok.
- derive_items_for_event/3: nil series returns []; with series and mocked Fireflies returns derived list with `source="derived"`.
- merged_items_for_event/3: merges manual+derived; dedup by normalized text.
- replace_manual_text/2: clears existing manual, inserts single item at position 0.

## Meetings — AgendaItem (unit)

Module: `DashboardSSD.Meetings.AgendaItemTest` (async: true)

- changeset validates `calendar_event_id`, `text` required; `source` inclusion (manual|derived).

## Meetings — Associations (unit/integration)

Module: `DashboardSSD.Meetings.AssociationsTest` (DataCase, async: true)

- get_for_event/1 → nil or record; get_for_event_or_series/2 falls back to latest `persist_series=true`.
- set_manual/2 and set_manual/4: origin="manual"; `persist_series` default true; sets `recurring_series_id` when provided.
- delete_for_event/1 and delete_series/1 remove records.
- guess_from_title/1: returns {:client, _} | {:project, _} | :unknown | {:ambiguous, list} (seed clients/projects).

## Meetings — CacheStore (unit)

Module: `DashboardSSD.Meetings.CacheStoreTest` (async: false)

- put/get/delete/flush/reset scoped to `:meetings` namespace.
- fetch/3 memoizes function result; honors `ttl` override.

## Meetings — FirefliesArtifact (unit)

Module: `DashboardSSD.Meetings.FirefliesArtifactTest` (DataCase, async: true)

- changeset normalizes list `action_items` → `%{"items" => [...]}`; validates required `recurring_series_id`.

## Meetings — FirefliesStore (unit/integration)

Module: `DashboardSSD.Meetings.FirefliesStoreTest` (DataCase, async: true)

- get/1 returns normalized artifacts.
- upsert/2 inserts then updates; sets `fetched_at` when absent.

## Meetings — MeetingAssociation (unit)

Module: `DashboardSSD.Meetings.MeetingAssociationTest` (DataCase, async: true)

- changeset validates required `calendar_event_id`; origin inclusion; foreign key constraints left to DB (light assertions only).

## Components — CalendarComponents (component)

Module: `DashboardSSDWeb.CalendarComponentsTest` (async: true)

- month_calendar/1
  - Renders headers; leading blanks correct; today highlighted; range highlight; bold busy days.
  - Compact vs non-compact markup differences asserted via fragments.

## Components — Navigation (component)

Module: `DashboardSSDWeb.NavigationTest` (async: true)

- github_releases_url/0 returns constant.
- nav/1 filters by capabilities and variant (sidebar/topbar/mobile).
- nav_active?/2 marks root and nested paths; normalize_path handles URIs.
- sidebar_footer/1 includes version + user initials when `current_user` present.

## Helpers — DateHelpers (unit)

Module: `DashboardSSDWeb.DateHelpersTest` (async: true)

- human_datetime/1 and human_date/1 for Date/DateTime/NaiveDateTime/nil.
- human_date_local/human_datetime_local/human_time_local with +/- offsets.
- today?/same_day? with edge cases across midnight at local offset.

## Live — MeetingLive.DetailComponent (component)

Module: `DashboardSSDWeb.MeetingLive.DetailComponentTest` (ConnCase, async: false)

- update/2 builds assigns from manual agenda + Fireflies post; sets guess + auto suggestion.
- save_agenda_text updates DB and refreshes assigns; refresh_post triggers boundary and refresh, rate-limited path shows message.
- assoc_save persists client/project with persist flag; assoc_reset_event and assoc_reset_series reset assigns.

## Live — MeetingLive.Index (live view)

Module: `DashboardSSDWeb.MeetingLive.IndexTest` (ConnCase, async: false)

- handle_params with `mock=1` lists meetings and agenda_texts (manual empty → derived from Fireflies).
- Calendar navigation: `cal_prev_month`/`cal_next_month`; `calendar_pick` sets range.
- tz:set affects time/date formatting via DateHelpers.
- Association chips show Client/Project names from `assoc_by_meeting`.

## Live — MeetingsLive.Index (live view)

Module: `DashboardSSDWeb.MeetingsLive.IndexViewTest` (ConnCase, async: false)

- Renders calendar triplet and highlights `has_meetings` days.
- Modal link patch preserves existing flags (mock/d/tz) and appends id/series/title.
- Agenda detail toggle renders text from `agenda_texts`.
