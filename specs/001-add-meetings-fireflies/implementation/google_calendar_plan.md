# Google Calendar Integration Plan

This plan focuses on implementing and hardening the Google Calendar integration used by Meetings.

## Goals

- Use Google Calendar as the source of truth for upcoming events/schedules.
- Map events to `%{id, title, start_at, end_at, recurring_series_id}` for UI.
- Preserve mock mode for local QA without external calls.
- Handle user-scoped and env-scoped tokens gracefully.
- Add caching to avoid excessive API calls.

## Steps

1) Audit current module + token flow
- Verify `DashboardSSD.Integrations.GoogleCalendar` mock path works.
- Decide token sourcing strategy: user ExternalIdentity (provider "google") first; fallback to `GOOGLE_OAUTH_TOKEN` from env.

2) Add Tesla client + events.list
- Implement `GET https://www.googleapis.com/calendar/v3/calendars/primary/events` with params:
  - `timeMin`, `timeMax` (ISO8601 UTC), `singleEvents=true`, `orderBy=startTime`.
- Map response items to `%{id, title, start_at, end_at, recurring_series_id}`.
- Handle all-day events (`date` vs `dateTime`).

3) Add Integrations helper for user/env token
- Add `Integrations.calendar_list_upcoming_for_user(user, start_at, end_at, opts \\ [])` that:
  - Finds user’s `ExternalIdentity` with provider "google" to get `token`.
  - Falls back to env var `GOOGLE_OAUTH_TOKEN` when user token missing.
  - Calls `GoogleCalendar.list_upcoming/3` with `token: ...`.
  - Returns `{:error, :no_token}` when neither is present.

4) Wire MeetingsLive to Integrations + handle errors
- Update `MeetingsLive.Index` to call `Integrations.calendar_list_upcoming_for_user(@current_user, ...)`.
- Preserve `?mock=1` query to force mock data for QA.
- On `{:error, :no_token}`, show empty list with a stable page (no crashes).

5) Add caching via Meetings.CacheStore
- Cache by key `{:gcal, user_id_or_nil, window_key}` for 5 minutes (TTL configurable).
- `window_key` can be `{Date.to_iso8601(start), Date.to_iso8601(end)}`.

6) Add unit tests (transform + error paths)
- Map a sample Google response (with date/dateTime variants) to internal event shape.
- Missing token → `{:error, :no_token}`.
- Mock path remains intact and returns sample events.

7) QA notes + env updates
- Add `GOOGLE_OAUTH_TOKEN` guidance to `example.env` comments.
- Browser QA: `/meetings?mock=1` vs live tokens; validate modal behavior is unaffected.

## Commit Order (separate commits)

1. Integrations: add calendar user/env helper for list_upcoming
2. GoogleCalendar: implement Tesla client for events.list + transform
3. Meetings: use Integrations.calendar_list_upcoming_for_user and handle no-token
4. Meetings: cache GCal list_upcoming via Meetings.CacheStore (5m TTL)
5. Tests: add Google Calendar transform + error tests
6. Dev: update example.env with GOOGLE_OAUTH_TOKEN note

