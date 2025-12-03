# Phase 0 Research – Simplified RBAC

## Topic: Performance Goals for RBAC updates
- **Decision**: Treat RBAC configuration as infrequent admin activity with the same UX responsiveness targets already in place (navigation updates within one page refresh; no new latency budget needed).
- **Rationale**: Spec success criteria require privilege changes to show up on next refresh (<5s). Existing LiveView renders and Ecto queries already meet sub-second response times; no additional service-level objectives surfaced by stakeholders.
- **Alternatives Considered**:
  - Define stricter p95 latency (e.g., <200ms) – rejected because RBAC changes happen rarely and depend on existing subsystem performance.
  - Introduce background jobs/event buses – unnecessary for current scale and would add complexity without value.

## Topic: Expected Scale/Scope of RBAC usage
- **Decision**: Design for dozens of internal Slickage staff and up to a few hundred active client users per tenant, with single-tenant administration.
- **Rationale**: Constitution limits domain to Slickage organisation; product serves internal teams plus client stakeholders. RBAC changes remain manageable in-memory without sharding.
- **Alternatives Considered**:
  - Global multi-tenant rollout (thousands of organisations) – outside current roadmap and would require multi-tenant architecture not described in spec.
  - One-off per-project overrides – conflicts with simplified three-role model.

## Topic: Enforcing Google Workspace membership for admins/employees while allowing external clients
- **Decision**: Validate Google OAuth email domains after login: users whose email matches configured Slickage domains (`slickage.com` et al.) can be assigned Admin/Employee roles; clients with other domains default to Client role and may be promoted manually by admins if their email is later federated.
- **Rationale**: Aligns with user directive to base access on OAuth while keeping internal roles within the company workspace. Email domain checks are supported by Ueberauth Google data without extra API calls.
- **Alternatives Considered**:
  - Rely on Google Directory API to verify organisation membership – provides stronger assurance but requires additional scopes, consent, and infrastructure.
  - Manual whitelist entry – shifts burden to admins and risks misconfiguration.

## Topic: Persisting capability assignments
- **Decision**: Store role-to-capability mappings in a dedicated schema table (e.g., `role_capabilities`) managed through the Accounts context, leveraging existing Repo and audit patterns.
- **Rationale**: Persistent storage ensures changes survive deploys and can record `updated_by` metadata demanded by spec FR-010. Existing tables (`roles`) do not capture capability granularity, and storing in application config would not meet audit requirements.
- **Alternatives Considered**:
  - Serialize mappings in app config – volatile across releases and lacks traceability.
  - Use JSON column on `roles` – feasible but mixes concerns and complicates querying/auditing.

## Topic: Local role-switch helper implementation
- **Decision**: Provide a mix task (`mix dashboard.role_switch --role ROLE`) that updates the current development/test session via Repo adjustments or session reset helpers, gated to non-prod environments.
- **Rationale**: Mix tasks are idiomatic for development utilities in Elixir, leverage existing contexts, and can enforce environment guards before mutating sessions.
- **Alternatives Considered**:
  - Custom Phoenix endpoint – risk of exposure beyond local dev.
  - Manual database updates – slower and error-prone for QA.
