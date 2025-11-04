# Tasks: Meetings with Google Calendar and Fireflies

Feature: specs/001-add-meetings-fireflies/spec.md  
Plan: specs/001-add-meetings-fireflies/plan.md

## Phase 1: Setup

- [X] T001 Consolidate env examples into single example.env; remove .env.example (example.env)
- [X] T002 Add FIREFLIES_API_TOKEN example to example.env (example.env)
- [X] T003 Document Google Calendar + Fireflies setup steps in INTEGRATIONS.md (INTEGRATIONS.md)
- [X] T004 Add Google Calendar readonly scope to OAuth provider config (config/config.exs)

## Phase 2: Foundational

- [X] T005 [P] Create Meetings context module for agenda persistence (lib/dashboard_ssd/meetings/agenda.ex)
- [X] T006 [P] Create Meetings context module for associations (lib/dashboard_ssd/meetings/associations.ex)
- [X] T007 [P] Create Fireflies parser with case-insensitive split on "Action Items" (lib/dashboard_ssd/meetings/parsers/fireflies_parser.ex)
- [X] T008 [P] Create Google Calendar integration module skeleton (lib/dashboard_ssd/integrations/google_calendar.ex)
- [X] T009 [P] Create Fireflies integration module skeleton (lib/dashboard_ssd/integrations/fireflies.ex)
- [X] T010 [P] Add Meetings index LiveView skeleton (lib/dashboard_ssd_web/live/meetings_live/index.ex)
- [X] T011 [P] Add Meeting detail LiveView skeleton (lib/dashboard_ssd_web/live/meeting_live/index.ex)
- [X] T012 Add routes for Meetings index/detail to router (lib/dashboard_ssd_web/router.ex)
- [X] T013 Add migration for agenda_items table (priv/repo/migrations)
- [X] T014 Add migration for meeting_associations table connecting meetings to Clients or Projects; enable auto-association support and manual override storage (priv/repo/migrations)
- [X] T015 Create DashboardSSD.Meetings.CacheStore wrapper over DashboardSSD.Cache (namespace :meetings) (lib/dashboard_ssd/meetings/cache_store.ex)

## Phase 3: User Story 1 – Prepare from previous notes (P1)

Goal: Show upcoming meetings and a pre-meeting agenda derived from the previous occurrence’s Fireflies outputs. Include a simple “what to bring” summary from derived items.

Independent Test Criteria: With a recurring event that has one previous Fireflies summary, the next occurrence shows agenda items parsed from the "Action Items" section and a short list of items to bring.

 - [X] T016 [P] [US1] Implement listing of upcoming meetings (next 14 days) (lib/dashboard_ssd/integrations/google_calendar.ex)
 - [X] T017 [US1] Map recurrence using Google recurringEventId/seriesId (lib/dashboard_ssd/integrations/google_calendar.ex)
 - [X] T018 [P] [US1] Implement Fireflies fetch of latest completed summary/action items for series (lib/dashboard_ssd/integrations/fireflies.ex)
 - [X] T019 [US1] Implement parser split by "Action Items" → accomplished vs. agenda items (lib/dashboard_ssd/meetings/parsers/fireflies_parser.ex)
 - [X] T020 [US1] Derive next meeting agenda from parsed action items (lib/dashboard_ssd/meetings/agenda.ex)
 - [X] T021 [P] [US1] Render Meetings index with upcoming list and agenda preview (lib/dashboard_ssd_web/live/meetings_live/index.ex)
 - [X] T022 [US1] Render meeting detail with generated agenda and simple "what to bring" (lib/dashboard_ssd_web/live/meeting_live/index.ex)
 - [X] T023 [US1] Add basic deduplication of items across notes/action items (lib/dashboard_ssd/meetings/agenda.ex)
 - [X] T024 [US1] Add structured logging for integration calls and parsing outcomes (lib/dashboard_ssd/meetings/parsers/fireflies_parser.ex)

## Phase 4: User Story 2 – Edit agenda before meeting (P1)

Goal: Users can add, edit, delete, and reorder agenda items; changes persist per meeting occurrence.

Independent Test Criteria: Open an upcoming meeting; add/edit/delete/reorder items; refresh persists state.

- [X] T025 [P] [US2] Persist manual agenda items with changesets (lib/dashboard_ssd/meetings/agenda.ex)
- [X] T026 [US2] Implement reorder/update endpoints in context (lib/dashboard_ssd/meetings/agenda.ex)
- [X] T027 [P] [US2] LiveView UI for add/edit/delete agenda items (lib/dashboard_ssd_web/live/meeting_live/index.ex)
- [X] T028 [US2] LiveView UI for drag/reorder and persistence (lib/dashboard_ssd_web/live/meeting_live/index.ex)

## Phase 5: User Story 3 – Post-meeting summary and actions (P2)

Goal: After completion, show Fireflies summary and action items; show pending state until available; allow manual refresh.

Independent Test Criteria: Completed meeting with Fireflies outputs displays summary/action items; pending state visible when not yet available; refresh pulls latest.

- [X] T029 [P] [US3] Fetch and cache completed meeting summary/action items using DashboardSSD.Meetings.CacheStore (lib/dashboard_ssd/integrations/fireflies.ex)
- [X] T030 [US3] Add refresh function and cache via DashboardSSD.Meetings.CacheStore with configurable TTL (lib/dashboard_ssd/integrations/fireflies.ex)
- [X] T031 [US3] Display accomplished text and action items on detail view (lib/dashboard_ssd_web/live/meeting_live/index.ex)
- [X] T032 [US3] Add manual Refresh action and pending state UI (lib/dashboard_ssd_web/live/meeting_live/index.ex)

## Phase 6: User Story 4 – Associate meeting to Client/Project (P2)

Goal: Auto-associate meetings to Client/Project via keyword match; let users set association and choose to persist for the series.

Independent Test Criteria: Unique match auto-associates; ambiguous/no match prompts user; choice is saved; prompt to persist for series works.

- [ ] T033 [P] [US4] Implement keyword-based auto-association and confidence scoring (lib/dashboard_ssd/meetings/associations.ex)
- [ ] T034 [US4] Implement manual association set/change in context (lib/dashboard_ssd/meetings/associations.ex)
- [ ] T035 [US4] Add prompt to persist association for series and save override (lib/dashboard_ssd_web/live/meeting_live.ex)
- [ ] T036 [P] [US4] Surface association on index and detail views (lib/dashboard_ssd_web/live/meetings_live.ex)

## Phase 7: Removed — “What to bring”

Simplified agenda to a single freeform text field; no separate “What to bring” section.
The following tasks are removed:

- [ ] T037 [US5] (removed) Derived items requires_preparation
- [ ] T038 [US5] (removed) Toggle requires_preparation on manual items
- [ ] T039 [US5] (removed) Render consolidated “What to bring” section

## Final Phase: Polish & Cross-Cutting

- [ ] T040 [P] Add search/filter by title and Client/Project (lib/dashboard_ssd_web/live/meetings_live.ex)
- [ ] T041 Improve deduplication and normalization of agenda items (lib/dashboard_ssd/meetings/agenda.ex)
- [ ] T042 Add rate limiting/backoff for integrations (lib/dashboard_ssd/integrations/google_calendar.ex)
- [ ] T043 Add rate limiting/backoff for integrations (lib/dashboard_ssd/integrations/fireflies.ex)
- [ ] T044 Add metrics/logging around cache hits/misses (lib/dashboard_ssd/meetings/agenda.ex)
- [ ] T045 Update quickstart with env + scopes (specs/001-add-meetings-fireflies/quickstart.md)
- [ ] T046 Run format and lint for repo (mix format; mix credo --strict)

## Refactor & Standardization (Approval-Gated)

- [ ] T047 [P] Prepare standardization proposal (module layout, cache keys/TTL, parser conventions, LiveView patterns) (specs/001-add-meetings-fireflies/standardization-proposal.md)
- [ ] T048 Request approval on standardization proposal before implementation (specs/001-add-meetings-fireflies/standardization-proposal.md)
- [ ] T049 Apply approved standardizations in a refactor-only commit (lib/dashboard_ssd/meetings/*)
- [ ] T050 Refactor pass after each phase; no behavior changes; run format/lint/tests/coverage (lib/dashboard_ssd/meetings/*)

## Dependencies (Story Order)

1. US1 → US2 (US2 builds on agenda display from US1)
2. US1 → US3 (completed meeting rendering relies on integrations from US1)
3. US1 → US4 (associations surface with meeting listings)
4. US2 → US5 (what-to-bring refines flags introduced in US2/US1)

## Parallel Execution Examples

- T008 and T009 can be implemented in parallel ([P])
- T010 and T011 LiveView skeletons can be implemented in parallel ([P])
- US1 tasks T016 and T018 can proceed in parallel after T008/T009 ([P])
- Association display (T036) can proceed in parallel with T033 ([P])

## Implementation Strategy

- Deliver MVP with US1 only: list upcoming meetings, generate agenda from previous meeting via Fireflies summary split on "Action Items", and show a simple "what to bring".
- Iterate with US2 to enable agenda editing; then US3 to show post-meeting outcomes; add US4 associations; finish with US5 polish on preparation summary.

## Format Validation

- All tasks follow the checklist format: `- [ ] T### [P?] [US#?] Description (path)`
- Each user story has a dedicated phase with independent test criteria.
- Paths are provided for each task and map to the planned structure.
