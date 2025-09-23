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
- [x] T013 [P] **Test**: Write tests for Projects context.
- [x] T014 Implement Projects context.
- [x] T015 [P] **Test**: Write tests for Contracts context.
- [x] T016 Implement Contracts context.
- [x] T017 [P] **Test**: Write tests for Deployments context (deployments and health checks).
- [x] T018 Implement Deployments context.
- [x] T019 [P] **Test**: Write tests for Notifications context (alerts and rules).
- [x] T020 Implement Notifications context.

## Phase 3.4: Integration APIs (Initial)
- [x] T021 [P] **Test**: Write tests for Linear API client (basic list issues by project).
- [x] T022 Implement Linear API client (basic list issues by project).
- [x] T023 [P] **Test**: Write tests for Slack API client (basic send message to channel).
- [x] T024 Implement Slack API client (basic send message to channel).
- [x] T025 [P] **Test**: Write tests for Notion API client (basic search/list pages).
- [x] T026 Implement Notion API client (basic search/list pages).
- [x] T027 [P] **Test**: Write tests for Google Drive API client (basic list files in folder).
- [x] T028 Implement Google Drive API client (basic list files in folder).

## Phase 3.5: LiveViews
- [x] T029 [P] **Test**: Write tests for Clients LiveView.
- [x] T030 Implement Clients LiveView to list clients.
- [x] T031 [P] **Test**: Write tests for Projects LiveView, including the display of SOWs/CRs, a list of project-specific tasks from Linear, deployment status, and KB articles.
- [x] T032 Implement Projects LiveView to list projects and show a project-specific hub with SOWs/CRs, a list of project-specific tasks from Linear, deployment status, and links to KB articles.
- [x] T033 [P] **Test**: Write tests for Settings/Integrations LiveView.
- [x] T034 Implement Settings/Integrations LiveView to connect external services.
- [x] T035 [P] **Test**: Write tests for Analytics LiveView. *(No longer applicable; metrics UI removed)*
- [x] T036 Implement Analytics LiveView to display metrics. *(Deprecated feature removed)*
- [ ] T037 [P] **Test**: Write tests for KB LiveView.
- [ ] T038 Implement KB LiveView to display an indexed and searchable list of Notion documents.
- [ ] T039 [P] **Test**: Write tests for Home LiveView, including the display of task summaries.
- [ ] T040 Implement Home LiveView to display projects, clients, workload (including a summary of tasks from Linear), incidents, and CI status.

## Phase 3.6: Polish
- [ ] T041 [P] Write unit tests for all contexts and LiveViews.
- [ ] T042 [P] Write end-to-end tests for critical user flows.
- [ ] T043 [P] Update documentation (`README.md`, `quickstart.md`, etc.).
- [ ] T044 [P] Perform manual testing based on `quickstart.md` and user stories.

## Dependencies
- Setup tasks (T001-T004) must be completed first.
- Test tasks must be completed before implementation tasks.
- Core models and contexts should be implemented before LiveViews.
- LiveViews can be implemented in parallel after their corresponding contexts are done.
