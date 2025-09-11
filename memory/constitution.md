# Slickage Dashboard Constitution

## Core Principles

### I. Library-First
Every feature is built as a self-contained library (Phoenix Context). Libraries must be independently testable and documented with a clear purpose.

### II. API-First
Functionality is exposed through well-defined APIs, primarily LiveViews for UI and JSON endpoints for webhooks.

### III. Test-First (NON-NEGOTIABLE)
TDD is mandatory for both backend and frontend development. Tests are written before the implementation, following a strict Red-Green-Refactor cycle.

### IV. Integration Testing
Integration tests are required for new libraries (contexts), contract changes, and inter-service communication.

### V. Observability
Structured logging is required for all services. Frontend logs should be sent to the backend for a unified stream.

## Additional Constraints

- **Technology Stack**: Elixir, Phoenix LiveView, PostgreSQL.
- **Code Style**: `mix format` is enforced. Credo is used for static analysis.

## Development Workflow

### Commit Message Convention
This project enforces the Angular style semantic release convention for commit messages.
All commit messages must follow this format.
For more information, see the [Angular Commit Message Guidelines](https://github.com/angular/angular/blob/main/CONTRIBUTING.md#commit).

### Review Process
- All pull requests must be reviewed by at least one other team member.
- All CI checks must pass before merging.

## Governance
This constitution supersedes all other practices. Amendments require documentation, approval, and a migration plan. All pull requests and reviews must verify compliance with this constitution.

**Version**: 1.0.0 | **Ratified**: 2025-09-11 | **Last Amended**: 2025-09-11