# Tasks: Simplified Role-Based Access Control

**Input**: Design documents from `/specs/006-simplify-rbac/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Stories include targeted tests to satisfy the constitution's test-first requirement.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Prepare environment configuration references needed across stories.

- [ ] T001 Update `example.env` with `SLICKAGE_ALLOWED_DOMAINS` documentation in `example.env`
- [ ] T002 Add domain allowlist setup instructions to onboarding docs in `README.md`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Introduce capability storage and catalog required by all stories.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T003 Generate role capability migration in `priv/repo/migrations/*_create_role_capabilities.exs`
- [ ] T004 Add `DashboardSSD.Accounts.RoleCapability` schema in `lib/dashboard_ssd/accounts/role_capability.ex`
- [ ] T005 Extend `DashboardSSD.Accounts` with role capability CRUD functions in `lib/dashboard_ssd/accounts.ex`
- [ ] T006 Create capability catalog module in `lib/dashboard_ssd/auth/capabilities.ex`
- [ ] T007 Seed default role-capability assignments with audit data in `priv/repo/seeds.exs`
- [ ] T008 Load Slickage domain allowlist config in `config/runtime.exs`

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Admin curates role privileges (Priority: P1) 🎯 MVP

**Goal**: Enable admins to review, adjust, and reset capability mappings for all roles and expose supporting APIs/UI with audit visibility.

**Independent Test**: Sign in as an admin, toggle employee access to Projects via Settings, observe navigation update immediately after a refresh, then restore defaults and confirm baseline mapping.

### Tests for User Story 1 ⚠️

- [ ] T009 [P] [US1] Add role capability context tests in `test/dashboard_ssd/accounts/role_capabilities_test.exs`
- [ ] T010 [P] [US1] Add RBAC settings API controller tests in `test/dashboard_ssd_web/controllers/api/rbac_controller_test.exs`
- [ ] T011 [P] [US1] Add RBAC admin LiveView tests in `test/dashboard_ssd_web/live/settings_live/rbac_settings_test.exs`

### Implementation for User Story 1

- [ ] T012 [US1] Implement RBAC settings API controller in `lib/dashboard_ssd_web/controllers/api/rbac_controller.ex`
- [ ] T013 [US1] Register RBAC API routes and pipelines in `lib/dashboard_ssd_web/router.ex`
- [ ] T014 [US1] Render role capability matrix and controls in `lib/dashboard_ssd_web/live/settings_live/index.ex`
- [ ] T015 [US1] Add RBAC settings LiveComponent for per-role capability toggles in `lib/dashboard_ssd_web/live/settings_live/rbac_table_component.ex`
- [ ] T016 [US1] Persist admin edits with last-updated metadata in `lib/dashboard_ssd/accounts.ex`
- [ ] T017 [US1] Surface reset-to-default action with audit flash messaging in `lib/dashboard_ssd_web/live/settings_live/index.ex`

**Checkpoint**: User Story 1 is functional and independently testable

---

## Phase 4: User Story 2 - Non-admins experience consistent access (Priority: P2)

**Goal**: Enforce capability-driven access for employees and clients, restrict external domains until invited, and present clear feedback in navigation and LiveViews.

**Independent Test**: Attempt login with an external domain (blocked with guidance), sign in as an employee, confirm navigation only shows permitted areas, and verify direct `/analytics` access redirects with an explanatory message.

### Tests for User Story 2 ⚠️

- [ ] T018 [P] [US2] Add capability-based policy coverage in `test/dashboard_ssd/auth/policy_test.exs`
- [ ] T019 [P] [US2] Add external domain enforcement tests in `test/dashboard_ssd/accounts/upsert_user_with_identity_test.exs`
- [ ] T020 [P] [US2] Add navigation filtering LiveView tests in `test/dashboard_ssd_web/components/navigation_test.exs`

### Implementation for User Story 2

- [ ] T021 [US2] Update `DashboardSSD.Auth.Policy` to evaluate stored capabilities in `lib/dashboard_ssd/auth/policy.ex`
- [ ] T022 [US2] Enforce Slickage domain allowlist and pre-invite checks in `lib/dashboard_ssd/accounts.ex`
- [ ] T023 [US2] Present blocked-domain messaging in `lib/dashboard_ssd_web/controllers/auth_controller.ex`
- [ ] T024 [US2] Filter navigation items by capabilities in `lib/dashboard_ssd_web/components/navigation.ex`
- [ ] T025 [US2] Align top-level layout links with capability checks in `lib/dashboard_ssd_web/components/layouts/app.html.heex`
- [ ] T026 [US2] Guard LiveViews (home, projects, clients, analytics, kb) with capability redirects in `lib/dashboard_ssd_web/live/**/*` files
- [ ] T027 [US2] Hide restricted action controls in LiveViews (new/edit/delete buttons) when capability absent in `lib/dashboard_ssd_web/live/**/*`
- [ ] T028 [US2] Wrap shared action components with capability checks (buttons, menus) in `lib/dashboard_ssd_web/components/core_components.ex`
- [ ] T029 [US2] Ensure unauthorized flashes and redirects use consistent copy in `lib/dashboard_ssd_web/live/clients_live/index.ex`

**Checkpoint**: User Stories 1 and 2 operate independently with correct authorization behavior

---

## Phase 5: User Story 3 - Developer toggles roles for testing (Priority: P3)

**Goal**: Provide a non-production mix task to swap the current user's role among Admin, Employee, and Client for local QA.

**Independent Test**: Run `mix dashboard.role_switch --role client` locally, refresh the browser, and confirm the UI reflects Client permissions; ensure mix task refuses execution in production environment.

### Tests for User Story 3 ⚠️

- [ ] T030 [P] [US3] Add mix task role switch tests in `test/mix/dashboard_role_switch_test.exs`

### Implementation for User Story 3

- [ ] T031 [US3] Implement `mix dashboard.role_switch` task in `lib/mix/tasks/dashboard.role_switch.ex`
- [ ] T032 [US3] Provide Accounts helper to swap user roles safely in `lib/dashboard_ssd/accounts.ex`
- [ ] T033 [US3] Document role switch usage in developer guide at `DEVELOPMENT.md`

**Checkpoint**: All user stories deliver their independent value

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final refinements spanning multiple stories

- [ ] T034 [P] Refresh RBAC configuration guidance in `docs/rbac.md`
- [ ] T035 Run quickstart validation flow in `specs/006-simplify-rbac/quickstart.md`
- [ ] T036 Perform Credo/Dialyzer sweeps and format in project root
- [ ] T037 Capture release notes for RBAC changes in `CHANGELOG.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)** → Required before Foundational tasks
- **Foundational (Phase 2)** → Blocks Phases 3, 4, 5
- **User Stories (Phases 3–5)** → May proceed in parallel once Phase 2 completes, but priority order is P1 → P2 → P3 for MVP cadence
- **Polish (Phase 6)** → Runs after desired user stories land

### User Story Dependencies

- **US1 (P1)** → Depends on Foundational phase only
- **US2 (P2)** → Depends on Foundational phase and shared context updates from US1
- **US3 (P3)** → Depends on foundational role capability APIs from US1

### Within Each User Story

- Tests are authored before implementation tasks
- Context/service work precedes LiveView/UI updates
- UI wiring occurs before messaging/flash polish

### Parallel Opportunities

- [P] tasks in Setup and Foundational phases can be run simultaneously by different contributors
- In US1, tests T009–T011 can be developed in parallel, followed by implementation tasks T012–T017 (some can be parallelized if coordinating on distinct files)
- In US2, tests T018–T020 and implementation tasks touching separate files (e.g., policy vs. navigation) can proceed concurrently after T021 lands
- US3’s mix task and documentation (T031–T033) can move in parallel once the helper API (T032) is ready

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phases 1–2 to establish capability storage
2. Deliver Phase 3 (US1) for admin privilege management
3. Validate via US1 acceptance test before expanding scope

### Incremental Delivery

1. MVP (US1) → ship admin controls
2. Add US2 to enforce employee/client experience
3. Add US3 to streamline QA workflows
4. Polish and documentation updates cap the release

### Parallel Team Strategy

- After Phase 2, dedicate one developer to US1, another to US2 (post-US1 context merge), and a third to US3 for tooling
- Reconvene during Phase 6 for cross-cutting polish and release preparation
