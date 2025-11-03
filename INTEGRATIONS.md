Integrations – Local Live Testing

Overview
- Tokens are read from env vars via `config/runtime.exs`.
- A local `.env` file is supported in dev/test and is auto-loaded at runtime.
- Use wrappers in `DashboardSSD.Integrations` for quick IEx testing.

Setup
- Copy `example.env` to `.env` and fill values (either name works when two are shown):
  - Linear: `LINEAR_API_KEY` or `LINEAR_TOKEN`
  - Slack: `SLACK_API_KEY` or `SLACK_BOT_TOKEN` (+ optional `SLACK_CHANNEL`)
  - Notion: `NOTION_API_KEY` or `NOTION_TOKEN`
  - Drive (optional direct access token): `GOOGLE_DRIVE_TOKEN` or `GOOGLE_OAUTH_TOKEN`
  - Google OAuth client: `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`
  - Fireflies: `FIREFLIES_API_TOKEN`
- Ensure `.env` is not committed (it is gitignored).

Google OAuth (Drive + Calendar)
- In Google Cloud Console, create OAuth 2.0 credentials and a consent screen.
- Add Authorized redirect URI: `http://localhost:4000/auth/google/callback`
- Put `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` in `.env`.
- Scope: app requests `email profile https://www.googleapis.com/auth/drive.readonly https://www.googleapis.com/auth/calendar.readonly` and asks for offline access to obtain `refresh_token`.
- Sign in at `http://localhost:4000/auth/google` to store the tokens on your user (table `external_identities`).
- After sign-in, the stored access token can be used for Drive and Calendar API calls.

Fireflies.ai for Meetings
- Provide `FIREFLIES_API_TOKEN` in `.env`.
- The Meetings feature uses Fireflies summaries to split into two sections:
  - What was accomplished: content before the `Action Items` heading.
  - Action Items: content under the `Action Items` heading, used as the starting agenda for the next meeting.
- If `Action Items` is not present in summary text, the app attempts to use Fireflies Action Items API where available; otherwise the agenda starts empty and can be edited manually.

Load `.env`
- Option 1 (recommended): it is auto-loaded on app start in dev/test by `config/runtime.exs`.
- Option 2: export manually in shell before running the app:
  - zsh/bash: `set -a; source .env; set +a`

Quick IEx Tests
- Start IEx: `iex -S mix phx.server`
- Linear: `DashboardSSD.Integrations.linear_list_issues("{ issues { id } }")`
- Slack: `DashboardSSD.Integrations.slack_send_message(nil, "Hello from DashboardSSD")`
  - Pass a channel explicitly to override default: `slack_send_message("#general", "hi")`
- Notion: `DashboardSSD.Integrations.notion_search("dashboard")`
- Drive: `DashboardSSD.Integrations.drive_list_files_in_folder("<folder_id>")`
 - Drive (user-scoped via OAuth):
   - After logging in with Google, find your user id (e.g., from session or `DashboardSSD.Accounts.list_users()`)
   - `DashboardSSD.Integrations.drive_list_files_for_user(user_id, "<folder_id>")`

 

Notes
- For Google Drive, provide an OAuth access token with the `drive` scope.
- Slack may require a channel ID (starts with `C...`) depending on workspace settings.
- Errors like `{:missing_env, "..."}` indicate the corresponding env var is unset.
