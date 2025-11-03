# Data Model: Meetings with Google Calendar and Fireflies

## Entities

### Meeting (virtual)
- Fields: `id` (composite from calendar), `title`, `start_at`, `end_at`, `status` (upcoming/completed), `calendar_event_id`, `recurring_series_id`, `attendees[]`, `client_id?`, `project_id?`
- Source: Google Calendar (authoritative)
- Notes: Not persisted as a table; populated from Calendar APIs.

### MeetingAssociation (persisted)
- Purpose: Manual override to link a meeting occurrence or series to a Client/Project.
- Fields: `id`, `calendar_event_id`, `recurring_series_id?`, `client_id?`, `project_id?`, `origin` (auto|manual), `persist_series?` (bool), `inserted_at`, `updated_at`
- Rules: Either `client_id` or `project_id` set (exclusive). If `persist_series?` true, applies to future events with same `recurring_series_id`.

### AgendaItem (persisted)
- Purpose: User-managed pre-meeting agenda items per meeting occurrence.
- Fields: `id`, `calendar_event_id`, `position` (int), `text`, `requires_preparation` (bool), `source` (manual|derived), `inserted_at`, `updated_at`
- Rules: Only `source=manual` items are user-editable; derived items can be regenerated.

### FirefliesCache (in-memory via ETS, existing module)
- Purpose: Cache Fireflies outputs to reduce latency and API calls using `DashboardSSD.KnowledgeBase.Cache` under a `:meetings` namespace.
- Fields: `key` = `{:meeting_artifacts, calendar_event_id}` or `{:series_artifacts, recurring_series_id}`; value contains `accomplished_text` and `action_items`.
- Rules: TTL aligned to Knowledge Base defaults unless overridden per call; manual refresh invalidates and refetches.

## Relationships
- MeetingAssociation links Meeting (by IDs) to Client or Project.
- AgendaItem belongs to a Meeting occurrence.
- FirefliesCache references Meeting/Series by key for quick reuse (no DB table).

## Validation Rules
- Exactly one of `client_id` or `project_id` must be present in an association.
- AgendaItem `text` is 1..2000 chars; `position` is >= 0; `requires_preparation` defaults false.
- Cache entries must be within TTL for reuse; otherwise recompute/fetch.

## State Transitions
- Upcoming → Completed: Trigger post-meeting view; enable Fireflies refresh.
- Refresh Fireflies: Replace cached `accomplished_text` and `action_items` if newer.
