# Slickage Dashboard Constitution

---

## Description
This constitution defines the governing principles, scope boundaries, development workflow,
and governance of the Slickage Dashboard (Clients → Projects → Tasks). It consolidates
integration rules, domain model, architectural principles, and testing requirements into a
single authoritative document.

---

## Core Principles

### I. Library-First
- Every feature MUST be built as a self-contained library (Phoenix Context).
- Libraries MUST be independently testable and documented with a clear purpose.

**Rationale**: Promotes modularity, reusability, and isolation of concerns.

---

### II. LiveView-First
- Phoenix LiveView is the primary UI surface.
- Controllers are limited to OAuth flows and webhook handling.

**Rationale**: Simplifies state management, reduces boilerplate APIs, and enables real-time UX.

---

### III. Test-First (NON-NEGOTIABLE)
- TDD is mandatory for backend and frontend.
- Tests MUST be written before implementation, following Red–Green–Refactor.
- Tooling gates (`mix format`, Credo strict, Dialyzer, `mix test`, `mix docs`) MUST pass pre-commit and in CI.

**Rationale**: Guarantees maintainable, reliable code and prevents regressions.

---

### IV. Integration Testing
- Integration tests are REQUIRED for new libraries (contexts), contract changes, and inter-service communication.

**Rationale**: Ensures stability across module and system boundaries.

---

### V. Observability
- Structured logging is REQUIRED across backend and frontend.
- Frontend logs MUST be shipped to the backend for a unified log stream.

**Rationale**: Provides visibility for debugging, incident response, and metrics.

---

### VI. Simple Domain Model
- Domain model is limited to `Client` → `Project`.
- Tasks are managed in **Linear** (no in-app Kanban/boards).

**Rationale**: Keeps database lean and avoids scope creep.

---

### VII. Integration-First
- **Linear** for tasks/workload.
- **Slack** for alerts/digests only (no chat UI).
- **Google OAuth** for authentication; **Google Drive** for SOW/CR docs.
- **Notion** for KB/case-study index.
- **GitHub Checks** for read-only CI integration.

**Rationale**: Focuses effort on orchestration, not reinvention.

---

### VIII. Project as the Hub
- Each Project links to: Linear project/team, Slack channel, Drive folder, Notion DB/page,
  and optionally a GitHub repo.
- Work Status is always **project-scoped**.

**Rationale**: Makes projects the atomic unit of coordination.

---

### IX. Home (Org Overview)
- Provides rollup of projects and clients.
- Displays workload (from Linear), incidents/CI, and quick links.

**Rationale**: Creates a single pane of glass for organizational health.

---

### X. Thin Database
- Schema restricted to:
  `users`, `clients`, `projects`, `external_identities`, `sows`, `change_requests`,
  `deployments`, `health_checks`, `alerts`, `notification_rules`, `metric_snapshots`,
  `audits`.

- **Expansion Rule**: Additional tables MAY be added only when:
  1. Required for compliance, legal, or audit obligations, OR
  2. A domain concern cannot be reasonably delegated to an external integration.
- Any schema expansion MUST include explicit documentation of rationale,
  migration implications, and Constitution Compliance review.

**Rationale**: Keeps the DB thin and pushes complexity into integrations,
but leaves a safe path for expansion when critical to product goals.

### XI. Types & Documentation
- Public modules/functions MUST include `@moduledoc` and `@doc`.
- Functions MUST include `@spec` where type clarity is important.
- Dialyzer usefulness MUST be preserved.

**Rationale**: Maintains clarity, correctness, and developer velocity.

---

### XII. RBAC
- Roles: **admin**, **employee**, **client**.
- Client users MAY only see their own projects.

**Rationale**: Ensures least-privilege access and external-facing safety.

---

### XIII. Time
- Store all timestamps in UTC.
- Display in user’s timezone (default Pacific/Honolulu).

**Rationale**: Consistent auditing and user-facing clarity.

---

### XIV. Security
- Scoped tokens REQUIRED for integrations.
- Secrets MUST be encrypted at rest.
- Webhooks MUST be idempotent.
- All SOW/CR and alert acknowledgements MUST be audited.

**Rationale**: Provides minimal enterprise-grade security posture.

---

## Scope Definition (MVP)

**In-Scope**:
- Home overview
- Client/Project workspaces
- SOW/CR metadata (stored in Drive)
- Linear work status + issue creation
- Slack alerts/digest
- Notion KB index
- Deployments & Health monitoring
- GitHub Checks
- Minimal analytics

**Out-of-Scope**:
- Chat UI
- In-app ticket boards
- Full CRM
- In-app document editing

---

## Additional Constraints

- **Technology Stack**: Elixir, Phoenix LiveView, PostgreSQL.

---

## Development Workflow

### Commit Message Convention
- Angular style semantic commit convention is enforced.
- Messages MUST follow the [Angular Commit Guidelines](https://github.com/angular/angular/blob/main/CONTRIBUTING.md#commit).

---

### Review Process
- Every PR MUST be reviewed by at least one team member.
- All CI checks MUST pass before merging.
- mix check MUST pass before committing

---

## Documentation & Review
- Concise bullets/tables are preferred.
- Gherkin permitted where helpful.
- Every artifact MUST include:
  - Constitution Compliance check
  - Success Metrics
  - ≥3 Risks with mitigations

---

## Governance
- **Amendments**: Any member may propose changes. Ratification requires admin approval
  and consensus review.
- **Versioning**: Semantic rules apply:
  - MAJOR → backward incompatible
  - MINOR → new principle/scope
  - PATCH → clarifications/typos
- **Compliance**: All new specs/features MUST include a Constitution Compliance section.
- **Review Cycle**: Constitution reviewed quarterly; risks updated with each new integration.

**Version**: 1.3.0 | **Ratified**: 2025-09-11 | **Last Amended**: 2025-10-01
