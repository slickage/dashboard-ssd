# Notion Integration Configuration

DashboardSSD relies on a Notion integration to fetch curated collections and documents for the Knowledge Base Explorer. Set the following environment variables locally (`.env`) and in each deployed environment.

## Required Variables

| Variable | Purpose | Notes |
|----------|---------|-------|
| `NOTION_TOKEN` *(preferred)* or `NOTION_API_KEY` | Token issued by the Notion integration. | Only one needs to be set. The runtime configuration raises in production if neither is supplied. |
| `NOTION_CURATED_DATABASE_IDS` | Allowlist of Notion database IDs that back the curated collections. | Provide a comma- or newline-separated list (e.g. `db-id-1,db-id-2`). Empty lists are rejected in production. |

## Optional Aliases

For backward compatibility you may export `NOTION_DATABASE_ALLOWLIST` or `NOTION_COLLECTION_ALLOWLIST`. These values are parsed the same way as `NOTION_CURATED_DATABASE_IDS` and should contain the curated database IDs.

## Optional Filters

DashboardSSD can filter Notion documents so only wiki-style content appears in the Knowledge Base:

| Variable | Purpose | Default |
|----------|---------|---------|
| `NOTION_ALLOWED_PAGE_TYPES` | Comma/newline separated list of select or status values that qualify a page as a wiki document. | `Wiki` |
| `NOTION_PAGE_TYPE_PROPERTIES` | Comma/newline separated list of property names to inspect for those values (case-insensitive). | `Type` |
| `NOTION_ALLOW_UNTYPED_DOCUMENTS` | When set to `false`, pages missing the configured property names are excluded. | `true` |

Set these values when your Notion databases use different naming or taxonomies.

## Discovery Mode

By default the dashboard indexes curated Notion databases. To index standalone wiki pages instead, set:

| Variable | Purpose | Notes |
|----------|---------|-------|
| `NOTION_KB_DISCOVERY_MODE` | Choose `pages` to read from the Notion Search API (`object=page`) instead of databases. | Results are filtered client-side so only `workspace` or `page` parents remain, which aligns with Notion's wiki hierarchy. |
| `NOTION_PAGE_COLLECTION_ID` | Stable identifier for the aggregate collection that appears in the UI when page discovery is enabled. | Defaults to `kb:auto:pages`. |
| `NOTION_PAGE_COLLECTION_NAME` | Display name shown in the collections list for the discovered pages. | Defaults to `Wiki Pages`. |
| `NOTION_PAGE_COLLECTION_DESCRIPTION` | Optional description rendered under the collection title. | Defaults to `Top-level pages from the company wiki`. |

Page discovery still honours the type filters above—only results whose configured property matches the allowlist (e.g. `Type = Wiki`) appear in the dashboard.

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
