# Implementation Plan: Application Theme Implementation

**Branch**: `002-theme` | **Date**: 2025-09-26 | **Spec**: [specs/002-theme/spec.md](specs/002-theme/spec.md)
**Input**: Feature specification from `/Users/kkid/Development/dashboard-ssd/specs/002-theme/spec.md`

## Execution Flow (/plan command scope)
```
1. Load feature spec from Input path
   → If not found: ERROR "No feature spec at {path}"
2. Fill Technical Context (scan for NEEDS CLARIFICATION)
   → Detect Project Type from context (web=frontend+backend, mobile=app+api)
   → Set Structure Decision based on project type
3. Evaluate Constitution Check section below
   → If violations exist: Document in Complexity Tracking
   → If no justification possible: ERROR "Simplify approach first"
   → Update Progress Tracking: Initial Constitution Check
4. Execute Phase 0 → research.md
   → If NEEDS CLARIFICATION remain: ERROR "Resolve unknowns"
5. Execute Phase 1 → contracts, data-model.md, quickstart.md, agent-specific template file (e.g., `CLAUDE.md` for Claude Code, `.github/copilot-instructions.md` for GitHub Copilot, or `GEMINI.md` for Gemini CLI).
6. Re-evaluate Constitution Check section
   → If new violations: Refactor design, return to Phase 1
   → Update Progress Tracking: Post-Design Constitution Check
7. Plan Phase 2 → Describe task generation approach (DO NOT create tasks.md)
8. STOP - Ready for /tasks command
```

**IMPORTANT**: The /plan command STOPS at step 7. Phases 2-4 are executed by other commands:
- Phase 2: /tasks command creates tasks.md
- Phase 3-4: Implementation execution (manual or via tools)

## Summary
Implement a consistent and visually appealing theme across all pages of the application, based on an existing Figma design. The implementation will be modular, with a clear separation between navigation and content to ensure a better and more intuitive user experience.

## Technical Context
**Language/Version**: Elixir ~> 1.14
**Primary Dependencies**: Phoenix ~> 1.7.14, Phoenix LiveView ~> 1.0.0-rc.1, Ecto SQL ~> 3.10, Tailwind ~> 0.2
**Storage**: PostgreSQL
**Testing**: ExCoveralls
**Target Platform**: Web
**Project Type**: Web application
**Performance Goals**: [NEEDS CLARIFICATION: Any specific performance goals for page load times or resource usage?]
**Constraints**: The theme implementation must be modular and not duplicate navigation components.
**Scale/Scope**: The theme should be applied to all existing views in the application.

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Simplicity**:
- Projects: [#] 1 (dashboard-ssd)
- Using framework directly? Yes
- Single data model? Yes
- Avoiding patterns? Yes

**Architecture**:
- EVERY feature as library? Yes, this will be a UI feature within the existing Phoenix application structure.
- Libraries listed: N/A for this feature, as it is primarily a UI change.
- CLI per library: N/A
- Library docs: N/A

**Testing (NON-NEGOTIABLE)**:
- RED-GREEN-Refactor cycle enforced? Yes
- Git commits show tests before implementation? Yes
- Order: Contract→Integration→E2E→Unit strictly followed? Yes
- Real dependencies used? Yes
- Integration tests for: new libraries, contract changes, shared schemas? N/A for this feature.
- FORBIDDEN: Implementation before test, skipping RED phase. Yes

**Observability**:
- Structured logging included? Yes
- Frontend logs → backend? Yes
- Error context sufficient? Yes

**Versioning**:
- Version number assigned? No
- BUILD increments on every change? No
- Breaking changes handled? N/A

## Project Structure

### Documentation (this feature)
```
specs/002-theme/
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── data-model.md        # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
├── contracts/           # Phase 1 output (/plan command)
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (repository root)
```
# Option 2: Web application (when "frontend" + "backend" detected)
lib/
└── dashboard_ssd_web/
    ├── components/
    ├── live/
    └── .specify/templates/

assets/
├── css/
├── js/
└── tailwind.config.js
```

**Structure Decision**: Option 2: Web application

## Phase 0: Outline & Research
1. **Extract unknowns from Technical Context** above:
   - Research the Figma MCP process and how to best extract design tokens and assets.
   - Research best practices for creating modular and reusable UI components in Phoenix LiveView.
   - [NEEDS CLARIFICATION: What is the URL or location of the Figma design file?]
   - [NEEDS CLARIFICATION: Any specific performance goals for page load times or resource usage?]

2. **Generate and dispatch research agents**:
   ```
   For each unknown in Technical Context:
     Task: "Research {unknown} for Application Theme Implementation"
   For each technology choice:
     Task: "Find best practices for Phoenix LiveView and Tailwind CSS in modular theme development"
   ```

3. **Consolidate findings** in `research.md` using format:
   - Decision: [what was chosen]
   - Rationale: [why chosen]
   - Alternatives considered: [what else evaluated]

**Output**: research.md with all NEEDS CLARIFICATION resolved

## Phase 1: Design & Contracts
*Prerequisites: research.md complete*

1. **Extract entities from feature spec** → `data-model.md`:
   - No new entities are expected for this feature.

2. **Generate API contracts** from functional requirements:
   - No new APIs are expected for this feature.

3. **Generate contract tests** from contracts:
   - No new contract tests are expected for this feature.

4. **Extract test scenarios** from user stories:
   - Each story → integration test scenario
   - Quickstart test = story validation steps

5. **Update agent file incrementally** (O(1) operation):
   - Run `./.specify/scripts/bash/update-agent-context.sh gemini`
   - If exists: Add only NEW tech from current plan
   - Preserve manual additions between markers
   - Update recent changes (keep last 3)
   - Keep under 150 lines for token efficiency
   - Output to repository root

**Output**: data-model.md, /contracts/*, failing tests, quickstart.md, GEMINI.md

## Phase 2: Task Planning Approach
*This section describes what the /tasks command will do - DO NOT execute during /plan*

**Task Generation Strategy**:
- Load `/.specify/templates/tasks-template.md` as base
- Generate tasks from Phase 1 design docs (contracts, data model, quickstart)
- Each component -> component creation task [P]
- Each view -> view update task [P]
- Each user story → integration test task

**Ordering Strategy**:
- TDD order: Tests before implementation
- Dependency order: Base layout and components before specific views.
- Mark [P] for parallel execution (independent files)

**Estimated Output**: 10-15 numbered, ordered tasks in tasks.md

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation
*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)
**Phase 4**: Implementation (execute tasks.md following constitutional principles)
**Phase 5**: Validation (run tests, execute quickstart.md, performance validation)

## Complexity Tracking
*Fill ONLY if Constitution Check has violations that must be justified*

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
|           |            |                                     |

## Progress Tracking
*This checklist is updated during execution flow*

**Phase Status**:
- [ ] Phase 0: Research complete (/plan command)
- [ ] Phase 1: Design complete (/plan command)
- [ ] Phase 2: Task planning complete (/plan command - describe approach only)
- [ ] Phase 3: Tasks generated (/tasks command)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:
- [X] Initial Constitution Check: PASS
- [ ] Post-Design Constitution Check: PASS
- [ ] All NEEDS CLARIFICATION resolved
- [ ] Complexity deviations documented

---
*Based on Constitution v1.0.0 - See `/.specify/memory/constitution.md`*
