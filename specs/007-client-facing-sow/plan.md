# Implementation Plan: Client-Facing SOW Storage & Access

**Branch**: `007-client-facing-sow` | **Date**: 2025-11-13 | **Spec**: [specs/007-client-facing-sow/spec.md](specs/007-client-facing-sow/spec.md)  
**Input**: Feature specification from `/specs/007-client-facing-sow/spec.md`

**Note**: This template is filled via the `/speckit.plan` workflow described in `.specify/templates/commands/plan.md`.

## Summary

Create a canonical `shared_documents` catalog plus automation so Drive-stored SOWs/contracts and Notion-based internal docs can be listed, downloaded, and (optionally) edited through DashboardSSD. Key pieces include schema migrations, Drive helper/ACL tooling, repo-managed workspace templates (for Drive + Notion) with selective bootstrap, cache-aware sync jobs, RBAC-gated LiveViews (with Notion previews rendered server-side), a download proxy with audit logging, project assignment hooks, and telemetry to track download latency and ACL propagation.

## Technical Context

**Language/Version**: Elixir ~> 1.18 with Phoenix 1.8 & LiveView 1.1  
**Primary Dependencies**: Phoenix/Ecto stack, ETS cache infrastructure (`DashboardSSD.Cache`, Projects cache helpers), Google Drive service account integration, Notion sync pipeline, Oban/GenServers for jobs  
**Storage**: PostgreSQL (new `shared_documents`, optional `document_access_logs`, Drive folder mapping fields), Google Drive/Notion as external sources  
**Testing**: `mix test` for DataCase/ConnCase/LiveView, integration mocks for Drive/Notion, Credo/Dialyzer enforcement  
**Target Platform**: Phoenix web dashboard deployed to Slickage infra  
**Project Type**: Single Phoenix application (`lib/dashboard_ssd`, `lib/dashboard_ssd_web`)  
**Performance Goals**: Client downloads ≤3 s for files ≤25 MB; Drive ACL propagation ≤1 min after assignment change; listings refresh ≤30 s after metadata edits  
**Constraints**: Must not expose raw Drive URLs, must respect Drive quota/backoff rules, must document new tables per constitution thin DB clause, all actions gated via RBAC capabilities  
**Scale/Scope**: Tens of internal staff and hundreds of client contacts per tenant, dozens of docs per project

## Constitution Check

*Gate satisfied before research; reconfirmed post-design.*

- **Library-First**: Changes live inside existing contexts (`DashboardSSD.Projects`, `.Integrations.Drive`, `.Cache`), exposing clear APIs. ✅
- **LiveView-First**: UI delivered via Projects + Client LiveViews; no controller expansion. ✅
- **Test-First**: Each phase mandates tests (migrations, cache, LiveView, audits) before implementation. ✅
- **Integration-First**: Documents remain in Drive/Notion; DB only holds metadata. ✅
- **Thin Database**: New tables justified for audit/compliance and limited to metadata + logs. ✅
- **RBAC Principle**: Introduce capabilities like `contracts.view/manage`, enforce existing Policy checks, keep clients scoped. ✅
- **Observability/Audit**: Download proxy and ACL automation emit structured audit logs. ✅

## Project Structure

### Documentation (feature)

```text
specs/007-client-facing-sow/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
└── tasks.md  (created via /speckit.tasks)
```

### Source Code (repository root)

```text
lib/
├── dashboard_ssd/
│   ├── accounts/
│   ├── cache/
│   ├── clients/
│   ├── integrations/
│   │   ├── drive/
│   │   └── notion/
│   ├── knowledge_base/
│   ├── projects/
│   └── deployments/
├── dashboard_ssd.ex
└── dashboard_ssd_web/
    ├── components/
    ├── controllers/
    ├── live/
    ├── plugs/
    └── router.ex

priv/repo/migrations/

test/
├── dashboard_ssd/
├── dashboard_ssd_web/
└── support/
```

**Structure Decision**: Maintain the monolithic Phoenix structure—contexts own schemas and sync jobs, integrations contain Drive/Notion helpers, LiveViews render UI, migrations captured under `priv/repo/migrations`, and DataCase/LiveView tests live under `test/`.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| _(none)_ | – | – |

## Implementation Phases

### Phase 0 – Setup & Tooling
- **Work**: Confirm the feature branch/spec artifacts are current, ensure Drive/Notion credentials exist in `config/*.exs`, and wire up any mix aliases (e.g., `mix shared_documents.sync`) needed for new jobs.
- **Dependencies**: Access to service account secrets and development configuration.
- **Testing**: N/A (operational pre-check that unblocks subsequent phases).

### Phase 1 – Schema & Data Foundations
- **Work**: Create `shared_documents` (UUID PK, client/project FKs, enums for source + visibility, `client_edit_allowed`, metadata JSONB, checksum/hash, timestamps) and optional `document_access_logs`. Define schema modules/contexts with validations and typed enums. Document constitution rationale in migration notes.
- **Dependencies**: Existing clients/projects tables; audit/logging requirement.
- **Testing**: DataCase tests for changesets (required fields, enum constraints) and migration verification for indexes (unique `source/source_id` combo).

### Phase 2 – Drive Helper Enhancements & Cache Namespace
- **Work**: Extend `DashboardSSD.Integrations.Drive` with folder discovery, file listing (returning doc_type/visibility props), permission helpers (`share_folder/3`, `unshare_folder/3`, `apply_permissions/3`, `download_file/2`). Establish ETS namespaces `:shared_documents_listings` and `:shared_documents_downloads` via `DashboardSSD.Cache`, including TTL/invalidation APIs.
- **Dependencies**: Phase 0 schemas; service account credentials; Projects context for folder mapping.
- **Testing**: Unit tests using mocked HTTP responses or Bypass verifying helper outputs; cache tests confirming TTL + invalidation hooks register.

### Phase 3 – Workspace Templates & Bootstrap
- **Work**: Store template Markdown files under `priv/workspace_templates/` for Drive sections (Contracts, SOWs, Change Orders) and Notion KB pages; define a blueprint config that maps templates to folder/page hierarchies; implement `WorkspaceBootstrap` to create requested sections (Drive vs Notion) per client/project and expose admin-selectable options.
- **Dependencies**: Drive helper APIs, Notion credentials, repo template files.
- **Testing**: Unit tests mocking Drive/Notion APIs to ensure correct folder/page creation and selective generation; DataCase tests verifying metadata persistence.

### Phase 4 – Sync Jobs (Drive & Notion) with Cache Coordination
- **Work**: Implement Drive sync worker (Oban job or periodic GenServer) iterating project folders, transforming Drive metadata into `shared_documents` upserts with dedup via checksum, marking stale records, and invalidating caches. Update existing Notion sync to also populate `shared_documents`. Introduce telemetry/backoff for API quotas.
- **Dependencies**: Phase 1 helpers + cache APIs; Notion pipelines.
- **Testing**: DataCase tests for upsert/invalidation logic, Notion sync fixtures verifying filtering by doc tags, resilience tests for Drive quota errors (ensuring retries + warnings).

### Phase 5 – Portal UI, Notion Rendering & RBAC Updates
- **Work**: 
  - Staff LiveView: list, filter, toggle visibility/edit flags, jump to Drive/Notion, show ACL state. 
  - Client portal tab: show only `visibility=:client` docs tied to assignments, with Download/Open actions depending on Drive ACL and server-rendered Notion previews/PDF exports. 
  - RBAC updates: define `contracts.view`/`contracts.manage` (or similar) capability constants, wire into `DashboardSSD.Auth.Policy`.
  - Cache integration: fetch listing via ETS, bust when toggles invoked.
- **Dependencies**: Populated `shared_documents`; RBAC constants; cache API.
- **Testing**: LiveView tests for staff/client roles, ensuring unauthorized access blocked; Policy tests verifying new capabilities; tests for cache misses/hits when toggling states.

### Phase 6 – Download Proxy & Audit Logging
- **Work**: Build download endpoint (controller or LiveView handle_event) that validates RBAC, fetches metadata, proxies Drive download via service account, optionally caches signed URLs, handles oversized downloads gracefully, and records `document_access_logs`. Provide Notion render/download fallback via the renderer helper.
- **Dependencies**: Drive download helper, DocumentAccessLog schema, ETS download namespace.
- **Testing**: ConnCase tests covering success, unauthorized, oversized files, missing ACL, Notion preview, audit entry creation.

### Phase 7 – Automation Hooks, Workspace Actions & Telemetry Monitoring
- **Work**: Wire project assignment changes to `share_folder/3` / `unshare_folder/3`, update caches, and emit audit log entries; expose admin trigger to regenerate Drive/Notion sections; add telemetry collectors for download latency, ACL propagation time, and UI toggle propagation; update documentation (README/INTEGRATIONS); run final tooling gauntlet.
- **Dependencies**: Completed helpers + download proxy; workspace bootstrap module; Accounts/Projects assignment flows.
- **Testing**: DataCase + LiveView tests ensuring assignment/unassignment triggers ACL updates and caches clear; tests verifying workspace generation action; telemetry assertions covering download/ACL metrics and alert thresholds.

## Testing Strategy Overview
- **Schema/DataCase**: Validate migrations, enums, associations, and upsert logic.
- **Integration**: LiveView RBAC flows, download proxy streaming, Drive ACL automation.
- **Cache**: ETS namespace tests ensuring TTL/invalidation and per-user/per-project scoping.
- **Audit/Logging**: Tests verifying document access + ACL updates create structured log entries for compliance.
- **Resilience**: Simulated Drive quota/network failures to test exponential backoff + warning banners.

## Risks & Mitigations
1. **Drive ACL drift** – If permission updates fail, clients may see docs but lack access. *Mitigation*: queue retries with exponential backoff, flag mismatched docs in UI, and send telemetry alert when repeated failures occur.
2. **Cache staleness** – Without consistent invalidation, clients could see outdated visibility/edit states. *Mitigation*: centralize cache helpers, trigger invalidation after every Ecto upsert/toggle, and add telemetry counters for stale hits.
3. **Audit log volume** – Document downloads may explode log size. *Mitigation*: archive `document_access_logs` monthly (partitioned indexes) and reuse existing audit pruning tools.
4. **Notion fidelity** – Rendered Notion exports might lose formatting. *Mitigation*: provide PDF download fallback plus inline render message clarifying limitations.

## Completion Checklist

- Address phases sequentially, satisfying dependencies (schema → helpers → sync → UI → proxy → automation).
- Before handing off the branch, run (in order): `mix format`, `mix credo`, `mix dialyzer`, `mix coveralls.ci`, `mix doctor`, and finally `mix check` to ensure parity with CI expectations.
