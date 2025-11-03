# Implementation Plan: Simplified Role-Based Access Control

**Branch**: `[006-simplify-rbac]` | **Date**: 2025-11-03 | **Spec**: [specs/006-simplify-rbac/spec.md](specs/006-simplify-rbac/spec.md)
**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Implement a consistent RBAC model for Admin, Employee, and Client personas by standardising capability-based permissions,
simplifying navigation/guard checks, and enabling admins to adjust role privileges via the settings page. Build on the
existing Google OAuth authentication flow so admins and employees authenticate within the Slickage Google organisation,
while clients may authenticate with external Google accounts. Provide a non-production helper to switch roles quickly for
local testing and ensure privilege changes persist and apply across the product.

## Technical Context

**Language/Version**: Elixir ~> 1.18 (Phoenix LiveView application)  
**Primary Dependencies**: Phoenix ~> 1.8, Phoenix LiveView ~> 1.1, Ecto/Repo, Ueberauth + Ueberauth Google, Tailwind/Alpine (front-end)  
**Storage**: PostgreSQL (existing `roles`, `users`, `external_identities`, audit tables)  
**Testing**: `mix test` with `DashboardSSD.DataCase` and LiveView tests; Credo/Dialyzer per constitution  
**Target Platform**: Phoenix web application deployed for Slickage internal dashboard  
**Project Type**: Single-project Phoenix app (`lib/dashboard_ssd`, `lib/dashboard_ssd_web`)  
**Performance Goals**: Privilege updates should reflect within one page refresh (<5s) aligned with existing LiveView responsiveness  
**Constraints**: Must enforce Slickage Google Workspace membership for admins/employees; allow external Google OAuth for clients; honour constitution RBAC principle  
**Scale/Scope**: Single-tenant Slickage deployment serving dozens of staff and a few hundred client users

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Library-First**: RBAC adjustments stay within existing contexts (`DashboardSSD.Accounts`, `DashboardSSD.Auth`) and expose clear APIs. ✅
- **LiveView-First**: All UI changes occur in LiveViews/components already in place; no new controllers beyond OAuth. ✅
- **Test-First**: Plan will mandate tests for policy matrix, settings UI, and helper workflows before implementation. ✅
- **Integration-First**: OAuth remains Google-based, aligning with constitution; any new capability storage will reuse existing DB tables (no new integrations). ✅
- **Simple Domain Model**: No new core entities beyond role-capability assignments; remains within RBAC scope. ✅
- **RBAC Principle**: Explicitly maintains Admin/Employee/Client roles and least privilege. ✅
- **Thin Database**: Reuse existing tables or document rationale if role-capability mapping needs persistence (investigate before Phase 1). ✅
- **Post-Phase-1 Review**: RoleCapability table introduces new schema but remains within thin DB rule by documenting compliance and audit rationale. ✅

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
lib/
├── dashboard_ssd/
│   ├── accounts/
│   ├── auth/
│   ├── clients/
│   ├── projects/
│   ├── analytics/
│   └── integrations/
├── dashboard_ssd.ex
└── dashboard_ssd_web/
    ├── components/
    ├── controllers/
    ├── live/
    ├── plugs/
    └── router.ex

priv/
├── repo/
│   ├── migrations/
│   └── seeds.exs
└── gettext/

assets/
├── css/
├── js/
└── tailwind.config.js

test/
├── dashboard_ssd/
├── dashboard_ssd_web/
└── support/
```

**Structure Decision**: Single Phoenix application where RBAC logic lives inside `lib/dashboard_ssd/accounts` and
`lib/dashboard_ssd/auth`, with LiveView surfaces in `lib/dashboard_ssd_web/live` and shared navigation in
`lib/dashboard_ssd_web/components`. Tests reside in `test/dashboard_ssd*` folders using DataCase/ConnCase helpers.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
