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
- Elixir ~> 1.18 (Phoenix LiveView application) + Phoenix ~> 1.8, Phoenix LiveView ~> 1.1, Ecto/Repo, Ueberauth + Ueberauth Google, Tailwind/Alpine (front-end) (006-simplify-rbac)
- PostgreSQL (existing `roles`, `users`, `external_identities`, audit tables) (006-simplify-rbac)
- Elixir ~> 1.18 with Phoenix 1.8 & LiveView 1.1 + Phoenix/Ecto stack, ETS cache infrastructure (`DashboardSSD.Cache`, Projects cache helpers), Google Drive service account integration, Notion sync pipeline, Oban/GenServers for jobs (007-client-facing-sow)
- PostgreSQL (new `shared_documents`, optional `document_access_logs`, Drive folder mapping fields), Google Drive/Notion as external sources (007-client-facing-sow)

## Recent Changes
- 006-simplify-rbac: Added Elixir ~> 1.18 (Phoenix LiveView application) + Phoenix ~> 1.8, Phoenix LiveView ~> 1.1, Ecto/Repo, Ueberauth + Ueberauth Google, Tailwind/Alpine (front-end)
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
- Never use `git add -A`. Always stage file paths explicitly (e.g., `git add test/...` or `git add lib/...`) to
  avoid unintentionally committing tooling, artifacts, or unrelated changes. Use `git add -p` for selective hunks.

Example sequence (commands)
- git add lib/ test/
- git commit -m "feat(feature-x): add functionality y\n\n- short bullet 1\n- short bullet 2\n"
- git add scripts/tool_x.py
- git commit -m "feat(scripts): add tool for feature x\n\n- purpose of tool\n- how it integrates\n"
- git add docs/**
- git commit -m "docs(feature-x): add docs and manifest\n\n- what was added\n- where to find it\n"

## AI Merge Conflicts (Three-way, Patch-first)

Goals
- Perform true three-way merges (base, ours, theirs).
- Generate a per-file patch proposal and present it for approval before applying.
- Keep diffs minimal and deterministic; validate with checks.

Setup (once per machine)
- Enable base markers in conflicts: `git config --global merge.conflictStyle diff3`
- Reuse prior resolutions: `git config --global rerere.enabled true`
- Auto-apply known resolutions: `git config --global rerere.autoupdate true`

When to use
- During `git merge` or `git rebase` when files are conflicted.
- For text source files only. Do NOT hand-merge binaries or generated artifacts.

Workflow
1) Identify conflicted files
   - `git diff --name-only --diff-filter=U`
2) For each conflicted file (iterate one-by-one; do not attempt to resolve all files with a single patch)
   - Collect three versions:
     - Base: `git show :1:path/to/file`
     - Ours: `git show :2:path/to/file`
     - Theirs: `git show :3:path/to/file`
   - Ask the AI to perform a precise three-way merge using the prompt template below.
   - The AI must return a patch proposal only (no commentary).
   - Present the patch to the human for review/approval.
   - On approval, apply the patch and stage the file.
   - Quick check: `mix compile` to catch early issues.
3) After all files are resolved
   - Format and lint: `mix format && mix credo --strict`
   - Test and types: `mix test && mix dialyzer` (or `mix check`)
   - Commit when green. Rerere will remember the fix for similar conflicts.

Sequential resolution reminder
- Always work on one conflicted file until it is fully resolved, approved, and staged before moving to the next.
- Do not try to produce a giant combined patch that touches multiple files at once; that defeats the per-file workflow and increases risk.

Patch format (what the AI should output)
- Preferred: Codex apply_patch envelope with a single file per patch.
  - Example:

```
*** Begin Patch
*** Update File: path/to/file.ex
@@
-old/conflicted code
+merged code
*** End Patch
```

- Alternative: Unified diff patch at repo root paths (for `git apply -p0`).
- No extra commentary, logs, or prose around the patch.
- Use workspace-relative paths; avoid absolute paths and URLs.
- Keep the diff minimal: preserve formatting, dedupe imports/aliases, avoid reordering unless necessary.

Applying the proposal
- In Codex CLI: apply the envelope with `apply_patch` after approval.
- Outside Codex: save to `merge.patch` then run `git apply -p0 merge.patch` and `git add path/to/file`.

Prompt Template (copy/paste for each file)
- Use this to ask the AI for a merge patch. Keep temperature low for determinism.

```
You are performing a precise 3-way merge. Goals:
- Keep all real logic from both sides. If both sides add different features, include both.
- If one side refactors (rename/reorder) and the other adds logic, keep the new logic within the refactor.
- Dedupe imports/aliases; preserve formatting; minimize unrelated changes.

Return ONLY a patch proposal: EITHER
1) Codex apply_patch envelope (preferred), or
2) A unified diff applying at the repo root.

No extra commentary or explanations.

FILE: path/to/file

=== BASE
<paste output of: git show :1:path/to/file>
=== OURS
<paste output of: git show :2:path/to/file>
=== THEIRS
<paste output of: git show :3:path/to/file>
```

Elixir/Phoenix nuances
- mix.lock: Prefer one side, then run `mix deps.get` to regenerate; do not hand-merge.
- Ecto migrations: Keep both migration files. Create a new migration to reconcile schema diffs; avoid forcing one side.
- Router/LiveView: Merge new routes, plugs, and pipelines additively; avoid reordering unless necessary.
- Tests: Keep both new tests; ensure `describe`/test names don’t collide.
- Generated/binary files: Regenerate rather than merging by hand.

Accuracy guardrails
- Ask for minimal diffs to reduce noise and merge risk.
- If patch application fails, regenerate with more surrounding context in the patch hunk(s).
- Run `mix check` before committing to validate formatting, lint, tests, types, and docs.

Agent behavior (enforced)
- Walk conflicted files one-by-one; one patch per file.
- Always present the patch to the human and wait for approval before applying.
- After applying each patch, run a quick `mix compile` to surface immediate errors.
- Do not attempt to auto-merge lockfiles or binaries; follow the nuances above.
