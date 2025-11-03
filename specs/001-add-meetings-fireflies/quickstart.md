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
4. Run migrations (to be added): `mix ecto.migrate`
5. Start the app: `mix phx.server`
6. Navigate to Meetings page in the UI.

## Usage
- Upcoming meetings load from Google Calendar (next 14 days by default).
- Click a meeting to view/edit agenda; “What to bring” auto-summarizes flagged items.
- After the meeting, refresh to pull summary/action items from Fireflies.
- Set Client/Project association; choose to persist for series when prompted.

## Notes
- Fireflies content is cached for 24h; use Refresh to invalidate.
- All times stored in UTC; rendered in user timezone.

