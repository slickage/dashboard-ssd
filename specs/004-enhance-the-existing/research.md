# Research: Knowledge Base Explorer Enhancements

## Decision 1: Collection and document discovery strategy
- **Decision**: Build `DashboardSSD.KnowledgeBase.Catalog` to consume Notion database + page APIs, surfacing curated collections and their documents via cached metadata refreshed on demand.
- **Rationale**: The existing Notion search client only returns generic search results. Leveraging the Database Query API with pre-approved database IDs keeps scope bounded, enables collection-level metadata (counts, last updated), and aligns with the spec’s curated workspace assumption.
- **Alternatives considered**:
  - **Reuse /v1/search exclusively**: Rejected because it cannot guarantee collection boundaries or reliable ordering needed for the landing view.
  - **Manual YAML configuration**: Rejected to avoid drift from Notion and duplicate content maintenance.

## Decision 2: Global search implementation
- **Decision**: Implement LiveView search backed by a `KnowledgeBase.Search` service that queries cached metadata first, then falls back to Notion search for cache misses, and groups results by collection in-memory.
- **Rationale**: Reduces API calls (respecting 3 req/sec limit), delivers sub-second updates, and satisfies clarification outcome requiring global search with collection labeling.
- **Alternatives considered**:
  - **Direct passthrough to Notion on every keystroke**: Rejected due to latency and rate limits.
  - **Nightly static index**: Rejected because fresh metadata and last-updated indicators must reflect near-real-time changes.

## Decision 3: Document rendering
- **Decision**: Fetch page content blocks via Notion’s `/v1/blocks/{page_id}/children` endpoint, transform them into LiveView-safe assigns, and render with reusable components for headings, callouts, images, code, and tables.
- **Rationale**: Ensures parity with Notion formatting while keeping rendering inside LiveView (constitution LiveView-first principle). Component approach simplifies testing for “supported block types render without clipping.”
- **Alternatives considered**:
  - **HTML export**: Rejected for inconsistent styling and sanitization concerns.
  - **Third-party renderer**: Rejected to maintain control over accessibility compliance and avoid new dependency surface.

## Decision 4: Recently opened persistence
- **Decision**: Record knowledge base view events in the existing `audits` table (event type `kb.viewed`) and query the latest five per user.
- **Rationale**: Meets spec requirement without introducing new tables (Constitution X). Audit trail already stores per-user metadata and timestamps, simplifying compliance and reuse in analytics.
- **Alternatives considered**:
  - **New `recently_opened_docs` table**: Rejected against Thin Database rule.
  - **Session-only tracking**: Rejected because the spec requires persistence across visits.

## Decision 5: Observability & resilience
- **Decision**: Add telemetry events and structured logs for Notion API calls and LiveView error states, and implement exponential backoff + circuit-breaker pattern in the Notion adapter to degrade gracefully when Notion rate limits.
- **Rationale**: Aligns with constitution observability requirement and ensures clear operator signals when external dependency fails.
- **Alternatives considered**:
  - **Minimal logging only**: Rejected because it impedes incident response and violates observability principle.
  - **Full-blown queue-based retry**: Deferred until needed; current scope favors lightweight retry to meet availability goals.
