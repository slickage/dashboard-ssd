# Tasks: Slickage Dashboard MVP

**Input**: Design documents from `/specs/001-dashboard-init/`
**Prerequisites**: plan.md, research.md, data-model.md, contracts/

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)

## Phase 3.1: Setup
- [x] T001 [P] Initialize Phoenix project in the root directory.
- [x] T002 [P] Configure linting and formatting for the project (Credo).
- [x] T003 [P] Create database schema based on `data-model.md`.
- [x] T004 [P] Configure tooling and CI: enforce `mix format --check-formatted`, `mix credo`, `mix dialyzer`, `mix test`, and `mix docs` on pre-commit and CI/CD.

## Phase 3.2: Authentication & Authorization
 - [x] T005 [P] **Test**: Write integration test for Google OAuth user registration and login flow.
 - [x] T006 Implement user authentication with Google OAuth.
 - [x] T007 [P] **Test**: Write tests for RBAC (admin, employee, client roles).
 - [x] T008 Implement RBAC with role model and policies.

## Phase 3.3: Core Models and Contexts
- [x] T009 [P] **Test**: Write tests for Users/Auth context.
- [x] T010 Implement Users/Auth context.
- [x] T011 [P] **Test**: Write tests for Clients context.
- [x] T012 Implement Clients context.
- [ ] T013 [P] **Test**: Write tests for Projects context.
- [ ] T014 Implement Projects context.
- [ ] T015 [P] **Test**: Write tests for Contracts context.
- [ ] T016 Implement Contracts context.
- [ ] T017 [P] **Test**: Write tests for Deployments context.
- [ ] T018 Implement Deployments context.
- [ ] T019 [P] **Test**: Write tests for Notifications context.
- [ ] T020 Implement Notifications context.
- [ ] T021 [P] **Test**: Write tests for Analytics context.
- [ ] T022 Implement Analytics context.
- [ ] T023 [P] **Test**: Write tests for Integrations context.
- [ ] T024 Implement Integrations context.
- [ ] T025 [P] **Test**: Write tests for Webhooks context.
- [ ] T026 Implement Webhooks context.
- [ ] T027 [P] **Test**: Write tests for Audit context.
- [ ] T028 Implement Audit context.

## Phase 3.4: LiveViews
- [ ] T029 [P] **Test**: Write tests for Home LiveView, including the display of task summaries.
- [ ] T030 Implement Home LiveView to display projects, clients, workload (including a summary of tasks from Linear), incidents, and CI status.
- [ ] T031 [P] **Test**: Write tests for Clients LiveView.
- [ ] T032 Implement Clients LiveView to list clients.
- [ ] T033 [P] **Test**: Write tests for Projects LiveView, including the display of SOWs/CRs, a list of project-specific tasks from Linear, deployment status, and KB articles.
- [ ] T034 Implement Projects LiveView to list projects and show a project-specific hub with SOWs/CRs, a list of project-specific tasks from Linear, deployment status, and links to KB articles.
- [ ] T035 [P] **Test**: Write tests for Settings/Integrations LiveView.
- [ ] T036 Implement Settings/Integrations LiveView to connect external services.
- [ ] T037 [P] **Test**: Write tests for Analytics LiveView.
- [ ] T038 Implement Analytics LiveView to display metrics.
- [ ] T039 [P] **Test**: Write tests for KB LiveView.
- [ ] T040 Implement KB LiveView to display an indexed and searchable list of Notion documents.

## Phase 3.5: Integrations
- [ ] T041 [P] **Test**: Write contract test for POST /webhooks/linear.
- [ ] T042 Implement webhook controller for Linear.
- [ ] T043 [P] **Test**: Write contract test for POST /webhooks/slack.
- [ ] T044 Implement webhook controller for Slack.
- [ ] T045 [P] Implement background jobs with Oban for heartbeat, weekly digest, CI refresh, token refresh.

## Phase 3.6: Polish
- [ ] T046 [P] Write unit tests for all contexts and LiveViews.
- [ ] T047 [P] Write end-to-end tests for critical user flows.
- [ ] T048 [P] Update documentation (`README.md`, `quickstart.md`, etc.).
- [ ] T049 [P] Perform manual testing based on `quickstart.md` and user stories.

## Dependencies
- Setup tasks (T001-T004) must be completed first.
- Test tasks must be completed before implementation tasks.
- Core models and contexts should be implemented before LiveViews.
- LiveViews can be implemented in parallel after their corresponding contexts are done.
