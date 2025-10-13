# Notion Integration Configuration

DashboardSSD relies on a Notion integration to fetch curated collections and documents for the Knowledge Base Explorer. Set the following environment variables locally (`.env`) and in each deployed environment.

## Required Variables

| Variable | Purpose | Notes |
|----------|---------|-------|
| `NOTION_TOKEN` *(preferred)* or `NOTION_API_KEY` | Token issued by the Notion integration. | Only one needs to be set. The runtime configuration raises in production if neither is supplied. |
| `NOTION_CURATED_DATABASE_IDS` | Allowlist of Notion database IDs that back the curated collections. | Provide a comma- or newline-separated list (e.g. `db-id-1,db-id-2`). Empty lists are rejected in production. |

## Optional Aliases

For backward compatibility you may export `NOTION_DATABASE_ALLOWLIST` or `NOTION_COLLECTION_ALLOWLIST`. These values are parsed the same way as `NOTION_CURATED_DATABASE_IDS` and should contain the curated database IDs.

## Runtime Behaviour

- Configuration lives in `config/runtime.exs` under the `:dashboard_ssd, :integrations` key.
- In production environments the boot process raises if the Notion token or curated database allowlist is missing, preventing the app from starting with incomplete configuration.
- The allowlist is parsed into a trimmed list, so white-space and new lines are ignored.

## Sample Data for Development

- `priv/notion/collections.json` contains example curated collections. When running in dev or test without the `NOTION_CURATED_DATABASE_IDS` variable set, these IDs seed the default allowlist.
- Update the JSON file to reflect the collections you want available locally; the runtime keeps the file path in configuration at `DashboardSSD.KnowledgeBase`.

## Managing the Allowlist

1. In Notion, open each curated database and copy its ID from the URL (32 characters, optionally with dashes).
2. Add the IDs to `NOTION_CURATED_DATABASE_IDS`, separated by commas or new lines.
3. Redeploy or restart the application so the updated configuration can be loaded.
