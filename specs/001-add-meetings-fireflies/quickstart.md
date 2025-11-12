# Quickstart: Meetings with Google Calendar and Fireflies

## Prerequisites
- Elixir/Phoenix app boots locally (`mix setup`, `mix phx.server`).
- Google OAuth configured (existing app) and able to request Calendar scopes.
- Fireflies API token available.

## Environment
- GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET present (existing OAuth app)
- FIREFLIES_API_TOKEN set
- ENCRYPTION keys configured (repo standard)

## Scopes
- Google Calendar read scope: `https://www.googleapis.com/auth/calendar.readonly`

## Steps
1. Enable Meetings feature flag (if used) and add Calendar scope to Google OAuth consent.
2. Authenticate with Google; ensure tokens include Calendar scope.
3. Set Fireflies token: `export FIREFLIES_API_TOKEN=...`
   - Optional: set `FIREFLIES_USER_ID=...` to scope transcript queries to a default user.
4. Run migrations (to be added): `mix ecto.migrate`
5. Start the app: `mix phx.server`
6. Navigate to Meetings page in the UI.

## Usage
- Selected date window: The Meetings page shows a 13‑day window centered on the selected date (±6 days). Clicking any day in the calendar sets the selected date and recenters the calendar.
- Calendar strip: Displays previous, current, and next months. Days with meetings are bolded across all three months (cached 5 minutes).
- Local time: Times render in the browser’s local timezone automatically.
- Meeting details: Click a meeting to view/edit agenda. After the meeting, refresh to pull summary/action items from Fireflies. Associations can be set and persisted for the series.

## Notes
- Caching
  - Fireflies series artifacts (summary/action_items) are cached for 24h (in ETS) and persisted to DB; use Refresh on the meeting page to invalidate.
  - Calendar has‑event days for the 3‑month strip are cached for 5 minutes.
- Rate‑limits: If Fireflies returns `too_many_requests`, an inline message displays with the human‑readable retry time. Data is not overwritten on errors.
- All times stored in UTC; rendered in the browser’s local timezone.
