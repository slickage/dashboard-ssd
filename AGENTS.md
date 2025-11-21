# Agent Guidelines for DashboardSSD

## Commands
- **Build**: `mix compile`
- **Test all**: `mix test`
- **Test single file**: `mix test path/to/test.exs`
- **Test single test**: `mix test path/to/test.exs:line_number`
- **Lint**: `mix credo --strict`
- **Format**: `mix format`
- **Type check**: `mix dialyzer`
- **Full check**: `mix check` (format + lint + dialyzer + test + docs)
- **Setup**: `mix setup`

## Code Style
- **Language**: Elixir/Phoenix with Ecto, LiveView
- **Formatting**: `mix format` (120 char lines, imports Phoenix/Ecto/LiveView)
- **Naming**: CamelCase modules, snake_case functions/variables
- **Types**: `@type t :: %__MODULE__{...}` for schemas
- **Imports**: Group at top after module docstring
- **Error handling**: Pattern matching, Ecto changesets for validation
- **Documentation**: Module docs required, function docs optional
- **Testing**: `DashboardSSD.DataCase`, async: true when possible
- **Security**: No `IO.inspect` in production code

## Active Technologies
- Elixir (per repo), Phoenix LiveView + Ecto; Google Calendar API (OAuth2); Fireflies.ai API (token-based); JSON/HTTP client; Phoenix LiveView UI (001-add-meetings-fireflies)
- PostgreSQL (minimal tables for manual agenda items, associations, and optional Fireflies cache) (001-add-meetings-fireflies)

## Recent Changes
- 001-add-meetings-fireflies: Added Elixir (per repo), Phoenix LiveView + Ecto; Google Calendar API (OAuth2); Fireflies.ai API (token-based); JSON/HTTP client; Phoenix LiveView UI

## Commit Guidelines (Angular Convention)

Format
- <type>(<scope>): <subject>
- <blank line>
- <body>
- <blank line>
- <footer>

Rules
- Each line <= 100 characters
- Subject: imperative, present tense; lowercase first letter; no trailing period

Types
- build: build system or dependencies
- ci: CI configuration and scripts
- docs: documentation only changes
- feat: a new feature
- fix: a bug fix
- perf: performance improvements
- refactor: code change that neither fixes a bug nor adds a feature
- style: formatting/whitespace only (no logic changes)
- test: add or correct tests
- revert: revert a previous commit

Scope
- Use the area of work (e.g., models/users) or feature (e.g., meetings, fireflies, auth, schema)
- Example: feat(meetings): add association reset button

Subject examples
- good: add user info to model
- bad: added user info to model
- bad: adds user info to model

Body
- Use imperative, present tense
- Explain motivation and previous behavior
- Cover why the change is necessary, how it addresses the problem, and any side effects

Footer
- Reference issues (e.g., closes #69, resolves #420)
- BREAKING CHANGE: describe breaking changes clearly

Reverts
- revert(<scope>): <original header>
- Body: This reverts commit <hash>.

## Commit Workflow (Atomic, separated commits)

Always split work into minimal, logical commits. Do not mix code, scripts, and
docs in a single commit. Add files separately and commit separately using the
Angular format above.

Recommended grouping
- Code changes: feat|fix|refactor(<scope>)
  - Scope is the feature area (e.g., models/users, api, ui, auth).
  - Include only source code and related tests in this commit.
- Scripts and tooling: feat|build|ci(scripts)
  - Examples: scripts/*.sh, scripts/*.py, CI configs.
  - Keep script additions separate from code or docs.
- Documentation: docs(<scope>)
  - Examples: docs/**, README, AGENTS.md updates.
  - Large generated content should be its own commit.

Process (example)
1) Stage and commit code only
   - Files: src/** or lib/**, test/** (if tests are part of the code change)
   - Message: feat(feature-x): add functionality y
2) Stage and commit scripts only
   - Files: scripts/tool_x.py (or other scripts)
   - Message: feat(scripts): add tooling for feature x
3) Stage and commit docs only
   - Files: docs/**
   - Message: docs(feature-x): add documentation and manifest

Rules
- Do not include documentation files and scripts in a code commit.
- Do not include code files in a documentation-only commit.
- Prefer multiple small commits over one large mixed commit.
- Keep each commit message within 100 columns and subjects imperative.

Example sequence (commands)
- git add lib/ test/
- git commit -m "feat(feature-x): add functionality y\n\n- short bullet 1\n- short bullet 2\n"
- git add scripts/tool_x.py
- git commit -m "feat(scripts): add tool for feature x\n\n- purpose of tool\n- how it integrates\n"
- git add docs/**
- git commit -m "docs(feature-x): add docs and manifest\n\n- what was added\n- where to find it\n"
