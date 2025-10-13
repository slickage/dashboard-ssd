# Implementation Plan: Knowledge Base Explorer Enhancements

**Branch**: `004-enhance-the-existing` | **Date**: 2025-10-13 | **Spec**: specs/004-enhance-the-existing/spec.md
**Input**: Feature specification from `/specs/004-enhance-the-existing/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Elevate the existing LiveView-based Knowledge Base Explorer so internal teammates can browse curated Notion collections, run global search across all knowledge assets, and read documents with richer metadata and reliable rendering. We will refresh the landing view to surface collections and recent activity, introduce a reusable knowledge-base context layer atop the Notion integration, and extend the LiveView to support grouped search results, robust error/empty states, and accessibility/usability upgrades while maintaining constitution constraints (no new database tables, LiveView-first UX).

## Technical Context

**Language/Version**: Elixir 1.18.0 (OTP 27)  
**Primary Dependencies**: Phoenix 1.7.x, Phoenix LiveView ~> 1.0.0-rc.1, Ecto, Tesla (Notion client), TailwindCSS components  
**Storage**: PostgreSQL (reuse existing tables; no new schema) + in-memory cache (ETS) for recent activity/session state  
**Testing**: ExUnit with Phoenix.LiveViewTest, Mox for Notion client stubs, Credo strict, Dialyzer  
**Target Platform**: Phoenix LiveView web experience (desktop + responsive mobile)  
**Project Type**: Web (Phoenix LiveView frontend with shared Elixir contexts)  
**Performance Goals**: Search results refresh under 1 second; document render within 1.5 seconds for <5k word pages; zero rendering errors for supported block types  
**Constraints**: LiveView-first UI, library/context isolation, accessibility AA compliance, no new database tables without constitution review, reuse existing Notion integration credentials  
**Scale/Scope**: Supports ~200 internal teammates; peak concurrency <50 LiveView sessions; Notion API rate limits (3 requests/sec per integration) respected

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Library-First (I)**: Introduce/extend `DashboardSSD.KnowledgeBase` context wrapping Notion API. ✅
- **LiveView-First (II)**: Continue delivering UX via `DashboardSSDWeb.KbLive.Index`. ✅
- **Test-First (III)**: Plan includes LiveView + context unit tests before implementation. ✅
- **Integration Testing (IV)**: Add integration tests covering Notion service adapter + LiveView flows. ✅
- **Observability (V)**: Instrument Notion calls and LiveView events with structured logs/telemetry. ✅
- **Simple Domain Model (VI)** / **Thin Database (X)**: No new tables; reuse existing storage and session caches. ✅
- **Integration-First (VII)**: Deepen Notion integration without duplicating KB storage. ✅

Proceed to Phase 0.

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
lib/
├── dashboard_ssd/
│   ├── knowledge_base/          # New/expanded context: collections, documents, recent activity
│   ├── integrations/            # Existing Notion client and other adapters
│   └── ...                      # Other contexts (clients, auth, etc.)
├── dashboard_ssd_web/
│   ├── live/kb_live/            # LiveView for Knowledge Base Explorer
│   ├── components/              # Shared UI components (cards, tables, nav)
│   └── ...                      # Layouts, controllers, plugs

test/
├── dashboard_ssd/knowledge_base/    # Context tests (unit + integration w/ Notion mocks)
├── dashboard_ssd_web/live/          # LiveView tests
└── support/                         # Test helpers, fixtures
```

**Structure Decision**: Extend the existing Phoenix monolith. Add/expand `lib/dashboard_ssd/knowledge_base` for orchestration logic, enrich `lib/dashboard_ssd_web/live/kb_live` for UI updates, and place tests alongside corresponding contexts/LiveViews.

## Complexity Tracking

*Fill ONLY if Constitution Check has violations that must be justified*

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |

## Constitution Re-check (Post Phase 1 Design)

- Library and LiveView principles remain satisfied: all new logic lives in `DashboardSSD.KnowledgeBase` context and `KbLive`.
- Thin Database rule upheld by leveraging `audits` for recent activity with no migrations.
- Observability commitments captured in telemetry/logging plan and quickstart checklist.
- Test-First and Integration Testing gates reaffirmed through outlined unit, LiveView, and integration suites.
