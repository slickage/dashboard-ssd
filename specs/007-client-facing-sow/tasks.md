# Tasks – Client-Facing SOW Storage & Access

## Dependencies & Execution Order

1. Phase 1 → Phase 2 (schema + cache foundations must exist first)
2. Phase 2 → Phase 3 (Drive/Notion sync & cache invalidation before UI)
3. Phase 3 → Phase 4 (client portal relies on download proxy + staff tools)
4. Phase 4 → Phase 5 (workspace automation + ACL hooks depend on earlier helpers)
5. Phase 5 → Phase 6 (docs/monitoring/mix checks after functionality)

Parallel opportunities noted per task with `[P]`.

## Phase 1 – Setup & Tooling

- [ ] T001 Verify branch `007-client-facing-sow` is checked out and `/specs/007-client-facing-sow/` artifacts (spec, plan, tasks) match the latest prompts
- [ ] T002 Ensure Drive + Notion configuration keys are present in `config/dev.exs` and `config/test.exs` (service account JSON path, `DRIVE_ROOT_FOLDER_ID`, Notion integration token, contracts DB/page IDs) with sandbox-safe overrides
- [ ] T003 Update `mix.exs` aliases/scripts (adding `lib/mix/tasks/shared_documents_sync.ex` if needed) so engineers/CI can trigger shared document sync jobs via `mix shared_documents.sync`

## Phase 2 – Foundational Data, Cache & Workspace Templates

- [ ] T004 Build `priv/repo/migrations/*_create_shared_documents.exs`
- [ ] T005 Build `priv/repo/migrations/*_create_document_access_logs.exs`
- [ ] T006 Implement `DashboardSSD.Documents.SharedDocument` schema + changeset in `lib/dashboard_ssd/documents/shared_document.ex`
- [ ] T007 Implement `DashboardSSD.Documents.DocumentAccessLog` schema + changeset in `lib/dashboard_ssd/documents/document_access_log.ex`
- [ ] T008 Add Drive folder metadata fields/helpers in `lib/dashboard_ssd/projects/project.ex` + context functions
- [ ] T009 Implement ETS namespace helper `lib/dashboard_ssd/cache/shared_documents_cache.ex` (listing/download TTLs, invalidation API)
- [ ] T010 Extend `lib/dashboard_ssd/integrations/drive.ex` with `ensure_project_folder/2`, `list_documents/1`, `share_folder/3`, `unshare_folder/3`, `download_file/2` helpers plus unit tests/mocks
- [ ] T011 Create workspace template Markdown files in `priv/workspace_templates/drive/` (Contracts, SOW, Change Orders) and `priv/workspace_templates/notion/` (Project KB starter docs)
- [ ] T012 Define workspace blueprint config in `config/*.exs` listing available sections (Drive vs Notion) and mapping them to template files and folder paths; allow per-section toggles
- [ ] T013 Implement `lib/dashboard_ssd/documents/workspace_bootstrap.ex` that reads the blueprint + Markdown templates, programmatically creates Drive folders/files for selected sections, and pushes Notion page content for KB templates
- [ ] T014 Add tests for workspace bootstrap (mock Drive/Notion APIs, ensure selective section creation) in `test/dashboard_ssd/documents/workspace_bootstrap_test.exs`
- [ ] T015 Add DataCase tests for `SharedDocument` and `DocumentAccessLog` changesets in `test/dashboard_ssd/documents/shared_document_test.exs`
- [ ] T016 Add unit tests for shared documents cache helper + Drive integration helpers (`test/dashboard_ssd/cache/shared_documents_cache_test.exs`, `test/dashboard_ssd/integrations/drive_test.exs`)

## Phase 3 – User Story 1 (Client views & downloads contracts)

- [ ] T017 [US1] Introduce `contracts.client.view` capability in `lib/dashboard_ssd/auth/capabilities.ex` and enforce it in `DashboardSSD.Auth.Policy` for client portal access
- [ ] T018 [US1] Wire query functions in `lib/dashboard_ssd/documents.ex` to fetch client-visible docs scoped by assignments + cache lookup
- [ ] T019 [US1] Implement client Contracts LiveView (`lib/dashboard_ssd_web/live/clients_live/contracts.ex`) with listing, empty state, download/edit call-to-action (Notion rendered read-only)
- [ ] T020 [US1] Implement download proxy endpoint/handler (`lib/dashboard_ssd_web/controllers/shared_document_controller.ex` or LiveView handle_event) that streams Drive files via service account, leverages ETS download cache, and enforces RBAC
- [ ] T021 [US1] Record download events in `lib/dashboard_ssd/documents/document_access_log.ex` helper invoked from the proxy
- [ ] T022 [US1] Add LiveView/DataCase tests covering client listing filters, empty state, and download flow in `test/dashboard_ssd_web/live/clients_live/contracts_live_test.exs`
- [ ] T023 [P] [US1] Add integration test for download proxy auditing + caching in `test/dashboard_ssd_web/controllers/shared_document_controller_test.exs`
- [ ] T024 [US1] Implement Drive sync worker (`lib/dashboard_ssd/documents/drive_sync.ex`) that populates `shared_documents`, applies cache invalidation, and handles exponential backoff
- [ ] T025 [US1] Update Notion sync pipeline (`lib/dashboard_ssd/knowledge_base/notion_sync.ex`) to emit `shared_documents` entries for tagged pages
- [ ] T026 [US1] Add telemetry/logging for sync outcomes + stale cache detection in `lib/dashboard_ssd/documents/drive_sync.ex` and `lib/dashboard_ssd/telemetry.ex`
- [ ] T027 [US1] Add DataCase tests for Drive + Notion sync upserts/deduplication (`test/dashboard_ssd/documents/drive_sync_test.exs`, `test/dashboard_ssd/documents/notion_sync_test.exs`)

## Phase 4 – User Story 2 (Staff curates & audits shared documents)

- [ ] T028 [US2] Build staff Contracts LiveView (`lib/dashboard_ssd_web/live/projects_live/contracts.ex`) listing all docs with visibility/edit toggles and source jump links
- [ ] T029 [US2] Implement toggle handlers calling Drive ACL update helpers in `lib/dashboard_ssd/integrations/drive.ex` and cache invalidation helpers in `lib/dashboard_ssd/cache/shared_documents_cache.ex`
- [ ] T030 [US2] Surface audit data + warnings (e.g., ACL mismatch) in staff UI components (`lib/dashboard_ssd_web/components/contracts_components.ex`)
- [ ] T031 [US2] Update capability catalog (`lib/dashboard_ssd/auth/capabilities.ex`) and `DashboardSSD.Auth.Policy` (`lib/dashboard_ssd/auth/policy.ex`) to include `projects.contracts.view/manage`
- [ ] T032 [US2] Add LiveView tests for staff actions & RBAC gating in `test/dashboard_ssd_web/live/projects_live/contracts_live_test.exs`
- [ ] T033 [US2] Add DataCase tests for visibility toggle helper & ACL mismatch flagging in `test/dashboard_ssd/documents_test.exs`

## Phase 5 – User Story 3 (Workspaces & automatic permission alignment)

- [ ] T034 [US3] Invoke workspace bootstrap when creating clients/projects (`lib/dashboard_ssd/clients.ex`, `lib/dashboard_ssd/projects.ex`), specifying which sections (Drive contracts vs Notion KB) to generate
- [ ] T035 [US3] Add admin action (e.g., button in Projects/Settings LiveView) to generate/re-generate Drive or Notion sections selectively for existing clients/projects using `WorkspaceBootstrap`
- [ ] T036 [US3] Add tests for automatic + manual workspace generation (DataCase for creation hooks, LiveView/feature test for admin action)
- [ ] T037 [US3] Extend project assignment workflows (`lib/dashboard_ssd/projects.ex` and associates) to call Drive `share_folder/3` / `unshare_folder/3`
- [ ] T038 [US3] Implement retry/backoff job for Drive ACL sync failures (`lib/dashboard_ssd/projects/drive_permission_worker.ex`)
- [ ] T039 [US3] Hook ACL updates into cache invalidation + DocumentAccessLog entries
- [ ] T040 [US3] Add DataCase tests covering assignment-driven ACL sync + audit logs (`test/dashboard_ssd/projects/drive_permission_worker_test.exs`)
- [ ] T041 [US3] Add integration test verifying removing a client revokes portal download access (`test/dashboard_ssd_web/live/clients_live/contracts_live_test.exs`)

## Phase 6 – Polish & Cross-Cutting

- [ ] T042 Document new settings/flows (including open questions around approvals/uploads/notifications) in `docs/contracts-and-docs.md` and update `README.md` integrations section
- [ ] T043 Add monitoring/alerts for Drive ACL failures + cache staleness counters in `lib/dashboard_ssd/telemetry.ex` (and related Observer configs)
- [ ] T044 Run repo-wide quality gates (`mix format`, `mix credo`, `mix dialyzer`, `mix coveralls.ci`, `mix doctor`, `mix check`) from repository root

## Parallel Execution Examples

- Within Phase 3, tasks T017–T021 (portal RBAC/UI/proxy) can run in parallel with T024–T027 (sync + telemetry) after query helpers exist.
- Phase 4 UI work (T028–T033) can proceed alongside Phase 5 automation (T034–T041) once Drive/Notion workspace helpers are available.
- Testing tasks (T021, T022, T032, T033, T036, T040, T041) can run concurrently with related implementation tasks.

## MVP Recommendation

Ship after completing Phase 3 (User Story 1) plus foundational Phases 1–2. This delivers client-visible listings/downloads using Drive, backed by audit logging and caches, before layering staff controls, workspace automation, and ACL hooks.
