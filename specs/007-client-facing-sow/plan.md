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

### Phase 1 – Setup & Tooling
- **Work**: Confirm the feature branch/spec artifacts are current, ensure Drive/Notion credentials exist in `config/*.exs`, and wire up any mix aliases (e.g., `mix shared_documents.sync`) needed for new jobs.
- **Dependencies**: Access to service account secrets and development configuration.
- **Testing**: N/A (operational pre-check that unblocks subsequent phases).

### Phase 2 – Foundational Data, Cache & Workspace Templates
- **Work**: Create `shared_documents` and `document_access_logs` tables; implement schema modules/changesets; extend Drive helper APIs and shared cache namespaces; add repository-managed Markdown templates (Drive: Contracts/SOW/Change Orders, Notion: Project KB/Runbook) plus the blueprint config and `WorkspaceBootstrap`.
- **Dependencies**: Existing clients/projects tables, Drive service account, Notion credentials.
- **Testing**: Migration/DataCase tests for schemas; cache helper unit tests; bootstrap tests mocking Drive/Notion APIs.

### Phase 3 – Client Experience (User Story 1)
- **Work**: Implement client Contracts LiveView (queries, RBAC, caching), Notion renderer, download proxy with oversized fallback, Drive/Notion sync workers with telemetry and audit logging.
- **Dependencies**: Shared document schema + bootstrap data, Drive/Notion APIs.
- **Testing**: LiveView/DataCase tests for listings, proxy integration tests, Notion renderer unit tests, sync job tests, telemetry assertions.

### Phase 4 – Staff Experience (User Story 2)
- **Work**: Build staff Contracts LiveView with toggles, warnings, and source quick actions; update capability catalog/policy; ensure cache invalidation occurs on edits.
- **Dependencies**: Client experience complete, RBAC metadata in place.
- **Testing**: LiveView RBAC tests, cache invalidation tests, policy coverage.

### Phase 5 – Workspace Automation & ACL Alignment (User Story 3)
- **Work**: Invoke workspace bootstrap on client/project creation; add admin action to regenerate sections; integrate Drive share/unshare automation with retries/backoff and audit logging.
- **Dependencies**: Workspace bootstrap module, Drive helper APIs.
- **Testing**: DataCase tests for bootstrap hooks, LiveView tests for admin action, ACL automation tests.

### Phase 6 – Telemetry, Docs & Final Verification
- **Work**: Instrument download latency, ACL propagation, visibility-toggle latency, and stale-cache percentage (<2% threshold for SC-004) with alerts; document new settings/flows; run mix format/credo/dialyzer/coveralls/doctor/check.
- **Dependencies**: All functionality implemented; telemetry pipeline available.
- **Testing**: Telemetry unit/integration tests verifying metrics/alerts, documentation review, full mix check.

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
