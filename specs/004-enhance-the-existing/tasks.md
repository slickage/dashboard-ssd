# Tasks: Knowledge Base Explorer Enhancements

**Input**: Design documents from `/specs/004-enhance-the-existing/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Follow constitution-driven TDD—write or update tests within the implementation tasks before committing functionality.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm environment configuration and tooling support required by all stories

- [X] T001 [P] [Setup] Validate Notion credentials and curated database ID configuration in `config/runtime.exs` and `.env.example`; document expected variables in `docs/notion.md`.
- [X] T002 [P] [Setup] Introduce curated collection allowlist source (e.g., `priv/notion/collections.json`) and loader wiring in `config/config.exs` with sample data.
- [X] T003 [P] [Setup] Ensure Notion client test stubbing via Mox is available by updating `test/support/notion_mox.ex` and registering it in `test/test_helper.exs`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T004 [Foundational] Scaffold `lib/dashboard_ssd/knowledge_base` context (catalog/search/activity modules) with public API skeletons aligned to spec requirements and shared type definitions in `lib/dashboard_ssd/knowledge_base/types.ex`.
- [X] T005 [P] [Foundational] Extend `lib/dashboard_ssd/integrations/notion.ex` to support database query and block retrieval with exponential backoff/circuit breaker; cover behaviour with integration tests in `test/dashboard_ssd/integrations/notion_test.exs`.
- [X] T006 [P] [Foundational] Implement ETS-backed cache module `lib/dashboard_ssd/knowledge_base/cache.ex` plus supervision wiring in `lib/dashboard_ssd/application.ex`; verify behaviour with unit tests in `test/dashboard_ssd/knowledge_base/cache_test.exs`.
- [X] T007 [P] [Foundational] Add telemetry + structured logging for Notion calls in `lib/dashboard_ssd/knowledge_base/instrumentation.ex` and hook into Phoenix Telemetry publishers; confirm via instrumentation tests in `test/dashboard_ssd/knowledge_base/instrumentation_test.exs`.

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Browse Collections Quickly (Priority: P1) 🎯 MVP

**Goal**: Landing view surfaces curated collections with freshness signals and recently opened documents.

**Independent Test**: Load `/kb` as an authorized teammate and confirm collections, counts, and recently opened list render with correct ordering and empty-state messaging when data is unavailable.

### Implementation for User Story 1

- [X] T008 [P] [US1] Implement `DashboardSSD.KnowledgeBase.Catalog.list_collections/1` to merge Notion metadata and cache snapshots, including count/freshness calculations; add unit coverage in `test/dashboard_ssd/knowledge_base/catalog_test.exs`.
- [X] T009 [P] [US1] Implement `DashboardSSD.KnowledgeBase.Activity` to persist `kb.viewed` audits and fetch recent documents (max five) with fallbacks; test via `test/dashboard_ssd/knowledge_base/activity_test.exs`.
- [X] T010 [US1] Update `lib/dashboard_ssd_web/live/kb_live/index.ex` to load collections + recent activity on mount and expose assigns for the landing panel; add LiveView tests in `test/dashboard_ssd_web/live/kb_live_test.exs`.
- [X] T011 [P] [US1] Create reusable UI components for collection cards and recent list within `lib/dashboard_ssd_web/components/kb_components.ex` (and template partials if needed); add component rendering tests in `test/dashboard_ssd_web/components/kb_components_test.exs`.
- [X] T012 [US1] Implement empty-state and error message rendering for missing collections/notion failures inside `lib/dashboard_ssd_web/live/kb_live/index.ex`; extend LiveView tests to cover these scenarios.

**Checkpoint**: User Story 1 functional and demo-ready (MVP)

---

## Phase 4: User Story 2 - Drill Into a Collection (Priority: P2)

**Goal**: Selecting a collection shows document list with metadata, consistent ordering, and resilient empty/error states.

**Independent Test**: From the landing view select any collection and confirm document list renders with title, excerpt, tags, owner, timestamps, plus empty/error responses.

### Implementation for User Story 2

- [X] T013 [P] [US2] Implement `DashboardSSD.KnowledgeBase.Catalog.list_documents/2` to hydrate document summaries (title, excerpt, tags, owner, timestamps, share link) and cache results; cover with unit tests in `test/dashboard_ssd/knowledge_base/catalog_test.exs`.
- [X] T014 [US2] Enhance `lib/dashboard_ssd_web/live/kb_live/index.ex` to handle collection selection, load documents, persist last-selected collection in socket/session, and manage loading states; expand LiveView tests accordingly.
- [X] T015 [P] [US2] Build document list row/table components in `lib/dashboard_ssd_web/components/kb_components.ex` including tag/owner badges; add component tests in `test/dashboard_ssd_web/components/kb_components_test.exs`.
- [X] T016 [US2] Add empty-state + error banner handling for collection view (including retry action) in `lib/dashboard_ssd_web/live/kb_live/index.ex` and verify via LiveView tests.

**Checkpoint**: User Stories 1 & 2 independently functional

---

## Phase 5: User Story 3 - Find and Read the Right Document (Priority: P3)

**Goal**: Provide global search across collections and an in-app document reader that renders supported Notion blocks with metadata and share link.

**Independent Test**: Enter a search term, observe grouped results by collection, open a document, and ensure all supported block types render correctly with metadata and retry-friendly error handling.

### Implementation for User Story 3

- [X] T017 [P] [US3] Implement `DashboardSSD.KnowledgeBase.Search.search/2` combining cached metadata filtering with Notion search fallback and collection grouping; add unit tests in `test/dashboard_ssd/knowledge_base/search_test.exs`.
- [X] T018 [US3] Extend `lib/dashboard_ssd_web/live/kb_live/index.ex` search event handling for real-time filtering, grouping labels, and persistence of last query; update LiveView tests.
- [X] T019 [P] [US3] Build document renderer components (`lib/dashboard_ssd_web/components/kb_components.ex`) supporting headings, paragraphs, callouts, images, code, tables, and unsupported notice; add component tests in `test/dashboard_ssd_web/components/kb_components_test.exs` with fixture blocks.
- [ ] T020 [US3] Add metadata panel + share-link copy affordance within `lib/dashboard_ssd_web/live/kb_live/index.ex` and ensure audits log view events via `DashboardSSD.KnowledgeBase.Activity`; extend LiveView tests.
- [X] T021 [US3] Implement error/retry flows for search, block fetch, and share-link issues with telemetry spans in `lib/dashboard_ssd_web/live/kb_live/index.ex`; verify via LiveView tests and instrumentation assertions.

**Checkpoint**: All user stories complete and independently testable

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Hardening, accessibility, documentation, and operational validation

- [ ] T022 [P] [Polish] Perform accessibility review (keyboard focus order, ARIA labels, contrast) for `/kb` and adjust components in `lib/dashboard_ssd_web/components/kb_components.ex` as needed.
- [ ] T023 [P] [Polish] Validate telemetry/log output by exercising Notion success/failure paths via `mix test` and review logs; tune configuration in `config/prod.exs` / `config/dev.exs`.
- [ ] T024 [P] [Polish] Update knowledge base guides in `docs/` and quickstart checklists to reflect new flows, including `specs/004-enhance-the-existing/quickstart.md` sync.
- [ ] T025 [Polish] Execute full quickstart validation (environment setup, `mix test`, `mix credo --strict`, `mix dialyzer`, and manual `/kb` smoke test) and record results in `specs/004-enhance-the-existing/quickstart.md` notes.

---

## Dependencies & Execution Order

### Phase Dependencies
- **Phase 1 → Phase 2**: Setup tasks unblock foundational work.
- **Phase 2 → Phases 3-5**: Foundational infrastructure must be complete before any user story implementation.
- **User Story Phases (3-5)**: Execute in priority order (P1 → P2 → P3) for MVP cadence; stories may proceed in parallel once dependent components are stable.
- **Phase 6**: Begins after desired user stories reach checkpoints.

### User Story Dependencies
- **US1** depends on Phase 2 completion; no other story dependencies.
- **US2** depends on Phase 2 and shared catalog primitives from US1.
- **US3** depends on Phase 2 plus catalog/search primitives established in US1/US2.

### Within-Story Sequencing
- Implement context/services before LiveView/UI changes.
- Update LiveView behaviour before adding polish/error handling that depends on new assigns.
- Tests accompany each task (ensure failing test first per constitution).

## Parallel Opportunities
- Setup tasks (T001–T003) are independent and can run concurrently.
- Foundational tasks T005–T007 touch separate modules and can progress in parallel once T004 scaffolding exists.
- Within US1, tasks T008, T009, and T011 target different files and may proceed concurrently after foundational readiness.
- US2 tasks T013 and T015 can run in parallel; US3 tasks T017 and T019 are similarly parallelizable.
- Phase 6 tasks T022–T024 can run in parallel; T025 waits until earlier polish tasks complete.

## Parallel Example: User Story 3

```bash
# Context + search logic can progress alongside renderer work once Phase 2 completes.
Task: T017 [P] [US3] Implement KnowledgeBase.Search service
Task: T019 [P] [US3] Build document renderer components
```

## Implementation Strategy

### MVP First (User Story 1 Only)
1. Complete Phases 1 & 2 to establish infrastructure.
2. Deliver Phase 3 tasks T008–T012 for landing view improvements.
3. Validate `/kb` landing view via LiveView tests and manual check, then demo.

### Incremental Delivery
1. Finish Setup and Foundational phases.
2. Implement US1 (Phase 3) → deploy as MVP.
3. Layer US2 (Phase 4) for collection browsing → redeploy.
4. Layer US3 (Phase 5) for global search & reader → redeploy.
5. Apply Phase 6 polish after core stories are live.

### Parallel Team Strategy
- After Phase 2, assign:
  - Developer A: Phase 3 (US1)
  - Developer B: Phase 4 (US2)
  - Developer C: Phase 5 (US3)
- Coordinate via shared fixtures and component libs; reconvene for Phase 6 polish before release.

## Notes
- Respect constitution gates: LiveView-first, no new tables, observability coverage.
- Keep tasks atomic; commit after each task or logical pair.
- Stop at each checkpoint to validate independent story completion.
- Treat telemetry/log verification as part of definition of done for external integrations.
