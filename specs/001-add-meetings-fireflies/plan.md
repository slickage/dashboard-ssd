# Implementation Plan: Meetings with Google Calendar and Fireflies

**Branch**: `[001-add-meetings-fireflies]` | **Date**: 2025-10-31 | **Spec**: specs/001-add-meetings-fireflies/spec.md
**Input**: Feature specification from `/specs/001-add-meetings-fireflies/spec.md`

## Summary

Implement a Meetings page powered by Google Calendar as the source of truth for events and schedules, and Fireflies.ai as the source of meeting notes, summaries, and action items. Before a meeting, generate an agenda using the previous occurrence’s Fireflies output; after a meeting, show the summary and action items. Agenda editing is supported, and meetings are auto-associated to Clients/Projects by keywords with manual override. Fireflies parsing splits the latest summary by the "Action Items" section; everything from that section becomes proposed agenda items for the next occurrence, with fallbacks for missing sections.

## Technical Context

**Language/Version**: Elixir (per repo), Phoenix LiveView  
**Primary Dependencies**: Ecto; Google Calendar API (OAuth2); Fireflies.ai API (token-based); JSON/HTTP client; Phoenix LiveView UI  
**Storage**: PostgreSQL (minimal tables for manual agenda items and associations)  
**Caching**: Shared ETS cache via `DashboardSSD.Cache` with a domain wrapper `DashboardSSD.Meetings.CacheStore` (namespace `:meetings`) for Fireflies/meeting artifacts  
**Testing**: ExUnit, DataCase, LiveView tests, Mox for integration mocking, integration tests for contexts  
**Target Platform**: Web (Phoenix app)  
**Project Type**: Web application (single Phoenix app)  
**Performance Goals**: Meetings page opens in < 5s (p50); background fetches under safe rate limits  
**Constraints**: Test-first; structured logging; respect API quotas; tokens encrypted at rest  
**Scale/Scope**: Single-tenant team usage; dozens of meetings/day; hundreds of agenda items

Key integration choices and algorithms:
- Google Calendar as authoritative list of upcoming meetings; use event `recurringEventId`/`seriesId` for recurrence grouping when available.
- Fireflies latest completed meeting for the same series used to build the next agenda; parse summary by splitting on a case-insensitive heading "Action Items"; items under that heading populate next agenda; prior text is treated as "What was accomplished" for display post-meeting.
- If no explicit "Action Items" section exists, use Fireflies action items API (if available) or leave agenda empty and instruct manual additions.
- Caching uses the shared ETS-backed cache (`DashboardSSD.Cache`) through a domain wrapper `DashboardSSD.Meetings.CacheStore` under a `:meetings` namespace with sensible defaults similar to Knowledge Base.
- Association guessing via keyword match of meeting title to existing Clients/Projects; user can set/override; offer to persist decision for the series.

Unknowns / NEEDS CLARIFICATION (resolved in research.md):
- Google OAuth model: reuse existing Google OAuth identity vs. separate calendar consent.
- Fireflies API: exact endpoints and auth mechanism; rate limits and best practice for matching a Fireflies meeting to a Google event.
- Caching TTL exact value (default via `Meetings.CacheStore`; overrideable per call).

## Constitution Check

GATE evaluation against Slickage Dashboard Constitution:
- Library-First: Implement `DashboardSSD.Meetings` context (self-contained, testable). PASS
- LiveView-First: Meetings UI via LiveView; controllers only for OAuth/webhooks. PASS
- Test-First (non-negotiable): Add unit, LiveView, and integration tests before code. PASS
- Integration Testing: Required for Google Calendar and Fireflies contexts. PASS
- Observability: Add structured logs for integration calls and parsing outcomes. PASS
- Simple Domain Model: Keep Client→Project primary; Meetings are integration-sourced. PASS
- Thin Database: Add only minimal tables (agenda items, associations); use base ETS cache (no new DB cache tables). PASS (with justification below)
- Security: Scoped tokens, encrypted secrets, idempotent webhooks. PASS

Justification for DB expansion: Minimal persistence is required to store manual agenda items per occurrence and manual association overrides; Fireflies data remains external and is cached via the shared ETS cache (through a Meetings CacheStore) to improve UX and reduce API calls.

## Project Structure

### Documentation (this feature)

```text
specs/001-add-meetings-fireflies/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── contracts/
    └── openapi.yaml
```

### Source Code (repository root)

```text
lib/
├── dashboard_ssd/
│   ├── meetings/                 # Context: orchestration and persistence
│   │   ├── agenda.ex
│   │   ├── associations.ex
│   │   ├── parsers/fireflies_parser.ex
│   │   └── cache_store.ex        # Wrapper around DashboardSSD.Cache
│   └── integrations/
│       ├── google_calendar.ex    # Calendar read-only sync, series/occurrence mapping
│       └── fireflies.ex          # Notes/summary/action-items fetch
└── dashboard_ssd_web/
    └── live/
        ├── meetings_live.ex      # Meetings index (upcoming)
        └── meeting_live.ex       # Meeting detail (agenda edit, post-meeting summary)

priv/repo/migrations/             # Minimal tables for agendas, associations
test/
├── dashboard_ssd/meetings/
├── dashboard_ssd/integrations/
└── dashboard_ssd_web/live/
```

**Structure Decision**: Single Phoenix app; new `meetings` context and `integrations` modules; LiveViews for index/detail; minimal migrations for agenda items and association overrides; reuse base ETS cache via a `Meetings.CacheStore` wrapper.

## Refactoring & Standardization Workflow

- Refactor cadence: Perform a light refactor at the end of each phase (Foundational, and after each User Story) focusing on naming consistency, function extraction, and dead code removal. No behavioral changes.
- Standardization proposals: Before implementing any repo-wide or context-wide standardization, prepare a short proposal and request approval.
  - Candidates: Meetings module/file layout, cache store key/TTL defaults, parser conventions (section headings), LiveView state patterns, logging fields.
  - Process: Submit proposal for approval; once approved, apply changes in a dedicated refactor commit.
- Quality gates per refactor:
  - Run: `mix format`, `mix credo --strict`, `mix dialyzer`, `mix test`, `mix coveralls` (≥90%).
  - Ensure zero functional changes and stable public APIs.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| DB expansion beyond core tables | Persist manual agenda items and association overrides | Storing only in external systems wouldn’t preserve user edits within our app |
| New integrations not listed in Integration-First block | Required to deliver Meetings value (calendar + notes) | Replicating calendar/notes internally violates Integration-First principle |

## Testing & Coverage

- Test approach: Test-first for contexts and LiveViews; integration tests for Google Calendar and Fireflies with Mox stubs.
- Unit tests:
  - Meetings.Agenda: derive agenda from parsed Fireflies data; deduplication; requires_preparation flags.
  - Meetings.Associations: keyword auto-match, manual override persistence, series persistence prompt logic.
  - Meetings.Parsers.FirefliesParser: robust split on case-insensitive "Action Items", fallback behaviors.
  - Meetings.CacheStore: namespace/TTL behavior around `DashboardSSD.Cache`.
- Integration tests:
  - Integrations.GoogleCalendar: upcoming listing (14-day window), recurrence mapping to previous occurrence.
  - Integrations.Fireflies: latest-completed summary/action-items fetch; pending state handling; cache refresh.
- LiveView tests:
  - MeetingsLive (index): renders upcoming meetings and agenda previews; search/filter.
  - MeetingLive (detail): add/edit/delete/reorder agenda; show accomplished/action items; refresh/pending; association UI.
- Coverage gates:
  - Maintain ≥ 90% coverage (see `coveralls.json` minimum_coverage = 90).
  - CI gate already configured: `mix check` runs `mix coveralls` with `COVERALLS_MINIMUM_COVERAGE=90`.
  - New code must not reduce project coverage below current baseline; add tests alongside all new modules.
