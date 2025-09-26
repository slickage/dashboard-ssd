# Tasks: Application Theme Implementation

**Input**: Design documents from `/Users/kkid/Development/dashboard-ssd/specs/002-theme/`
**Prerequisites**: plan.md, research.md, data-model.md, quickstart.md

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Path Conventions
- **Web app**: `lib/dashboard_ssd_web/`, `assets/`

## Phase 3.1: Setup
- [ ] T001 [P] Configure Tailwind CSS to include new theme colors, fonts, and spacing based on the Figma design. Modify `assets/tailwind.config.js`.
- [ ] T002 [P] Create a new `assets/css/theme.css` file to define any custom CSS variables or base styles required by the new theme.

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3
**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**
- [ ] T003 [P] Create a new test file `test/dashboard_ssd_web/live/theme_live_test.exs` to verify that the main application layout renders with the new theme structure.
- [ ] T004 [P] Add a test to `test/dashboard_ssd_web/live/theme_live_test.exs` to ensure the shared navigation component is present on all pages.

## Phase 3.3: Core Implementation (ONLY after tests are failing)
- [ ] T005 Create a new layout file `lib/dashboard_ssd_web/components/layouts/theme.html.heex` that defines the main structure of the new theme, including the shared navigation and content areas.
- [ ] T006 Create a new navigation component `lib/dashboard_ssd_web/components/navigation.ex` and `lib/dashboard_ssd_web/components/navigation.html.heex` for the shared navigation bar.
- [ ] T007 [P] Update the `live_session` in `lib/dashboard_ssd_web/router.ex` to use the new `DashboardSSDWeb.Layouts.Theme` layout.
- [ ] T008 [P] Refactor existing LiveViews in `lib/dashboard_ssd_web/live/` to use the new theme layout and components.

## Phase 3.4: Integration
- [ ] T009 [P] Ensure all pages are responsive and match the Figma design on desktop, tablet, and mobile screen sizes.

## Phase 3.5: Polish
- [ ] T010 [P] Review all pages for visual consistency and adherence to the Figma design.
- [ ] T011 [P] Run the tests in `test/dashboard_ssd_web/live/theme_live_test.exs` and ensure they pass.
- [ ] T012 [P] Manually verify all steps in `specs/002-theme/quickstart.md`.

## Dependencies
- T001, T002 must be done before T005.
- T003, T004 must be done before T005, T006, T007, T008.
- T005 must be done before T007, T008.
- T006 must be done before T007, T008.

## Parallel Example
```
# Launch T001 and T002 together:
Task: "Configure Tailwind CSS to include new theme colors, fonts, and spacing based on the Figma design. Modify `assets/tailwind.config.js`."
Task: "Create a new `assets/css/theme.css` file to define any custom CSS variables or base styles required by the new theme."

# Launch T003 and T004 together:
Task: "Create a new test file `test/dashboard_ssd_web/live/theme_live_test.exs` to verify that the main application layout renders with the new theme structure."
Task: "Add a test to `test/dashboard_ssd_web/live/theme_live_test.exs` to ensure the shared navigation component is present on all pages."
```
