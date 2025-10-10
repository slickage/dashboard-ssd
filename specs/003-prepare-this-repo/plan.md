# Implementation Plan: Prepare Repo for CD with ArgoCD

**Branch**: `003-prepare-this-repo` | **Date**: 2025-10-10 | **Spec**: /Users/boka/dev/dashboard-ssd/specs/003-prepare-this-repo/spec.md
**Input**: Feature specification from `/specs/003-prepare-this-repo/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Update all configurations to read from Environment. Prepare the repository with CI pipeline for Docker image build/push to GHCR if all checks pass.

## Technical Context

**Language/Version**: Elixir 1.15
**Primary Dependencies**: Docker, GitHub Actions
**Storage**: N/A (configuration files)
**Testing**: mix test
**Target Platform**: Kubernetes via ArgoCD
**Project Type**: Web application (Phoenix)
**Scale/Scope**: Single repository automated deployment

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Library-First: PASS - No new libraries required, infra setup.
- LiveView-First: PASS - No UI changes.
- Test-First: PASS - CI includes tests.
- Observability: PASS - Built-in metrics and application logs.
- Simple Domain Model: PASS - No DB changes.
- Project as Hub: PASS - Infra for project deployment.
- Home: PASS - No changes.
- Thin Database: PASS - No schema additions.
- Types & Documentation: PASS - Follows existing.
- RBAC: PASS - Basic auth.
- Time: PASS - N/A.
- Security: PASS - Environment variables for secrets.
- Scope: PASS - In-scope as deployment infra.

## Project Structure

### Documentation (this feature)

```
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```
.github/
└── workflows/
    └── ci.yml  # CI pipeline for build, test, Docker push
```

**Structure Decision**: Adds CI workflow and deployment manifests to existing Elixir Phoenix structure. No changes to lib/ or test/ directories.

## Complexity Tracking

*No violations - all gates pass.*
