# Phase 0 Research: Meetings with Google Calendar and Fireflies

## Decisions and Rationale

### 1) Source of upcoming meetings
- Decision: Use Google Calendar as the source of truth for events and schedules (primary calendar of the authenticated user).
- Rationale: Aligns with spec and user direction; provides the broadest, user-expected view of upcoming meetings and recurrence metadata (recurringEventId/seriesId).
- Alternatives: Fireflies-scheduled meetings only (too narrow); Internal scheduling (adds scope, diverges from integration-first).

### 2) Google OAuth model for Calendar access
- Decision: Reuse existing Google OAuth identity and request the Calendar scope when enabling Meetings; store/refresh tokens via existing external_identities.
- Rationale: Constitution states Google OAuth is standard; avoids new auth flows and leverages existing identity management.
- Alternatives: Service account (not suitable for user calendars); separate OAuth app (extra ops burden).

### 3) Mapping recurrence/previous occurrence
- Decision: Prefer Google `recurringEventId`/`seriesId` to link occurrences. If missing, fallback to normalized title+attendees within a 90-day window, same weekday/time band.
- Rationale: Series IDs are canonical; fallback ensures resilience when IDs are absent (imports/renames).
- Alternatives: Title-only (fragile); attendees-only (ambiguous).

### 4) Fireflies authentication and endpoints
- Decision: Use Fireflies API with a project-level API token. Fetch latest completed meeting artifacts (summary, action items) for the mapped series.
- Rationale: Token-based auth is typical for vendor APIs; fits Integration-First.
- Alternatives: Webhooks-only (not sufficient to pull prior notes); scraping (not acceptable).

### 5) Agenda generation algorithm from Fireflies
- Decision: Parse the latest meeting summary text by splitting on a case-insensitive heading `Action Items`.
  - Text before `Action Items` => "What was accomplished" (for post-meeting display)
  - Text under `Action Items` => list items; each becomes an agenda item for the next occurrence
  - If `Action Items` section not found: attempt vendor action-items endpoint; if not available or empty, leave agenda empty and prompt manual add.
- Rationale: Matches user direction and provides a deterministic baseline with graceful fallbacks.
- Alternatives: Full NLP extraction/LLM; more capable but adds cost/complexity and possible drift.

### 6) Caching strategy for Fireflies artifacts
- Decision: Use existing ETS-backed cache (`DashboardSSD.KnowledgeBase.Cache`) under a `:meetings` namespace; cache Fireflies summary/action items per meeting/series with TTL aligned to Knowledge Base defaults; invalidate on explicit refresh.
- Rationale: Reuses established caching approach used by Knowledge Base (and consistent with app patterns); minimizes new infra and follows “do the same thing”.
- Alternatives: New DB cache table (adds complexity); no cache (risk rate limits/latency);

### 7) Manual association persistence
- Decision: When the user sets a Client/Project for a meeting, prompt to persist for the series; if accepted, apply to future occurrences.
- Rationale: Minimizes repetitive work; aligns with spec clarification.
- Alternatives: Always persist (risk mis-association); never persist (too much friction).

### 8) Security and secrets
- Decision: Store tokens/keys encrypted at rest; scope least privilege; redact logs.
- Rationale: Constitution Security principle.
- Alternatives: None acceptable.

## Implementation Notes
- Rate limiting: Add exponential backoff and jitter for Calendar/Fireflies calls.
- Time zones: Use UTC storage, user TZ display (HST default per constitution); rely on Calendar event timezone for rendering.
- Error handling: Show clear pending/unavailable states; non-blocking UI for third-party delays.
