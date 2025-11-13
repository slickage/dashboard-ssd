# Phase 0 Research – Client-Facing SOW Storage & Access

## Topic: Where to persist document metadata
- **Decision**: Introduce a dedicated `shared_documents` table instead of reusing knowledge-base tables so contractual artifacts (Drive + Notion) can be associated explicitly with clients/projects, visibility flags, and Drive ACL state.
- **Rationale**: Contracts require per-client scoping, audit timestamps, and Drive-specific metadata (fileId, mime type, client edit flag). Existing KB catalog lacks those attributes and is optimized for public/internal documentation, not legal deliverables.
- **Alternatives Considered**:
  - Extend KB catalog with extra columns – rejected because it would conflate internal KB taxonomy with contractual records and complicate cache invalidation.
  - Store everything only in ETS cache – volatile, would not survive restarts, and fails audit requirements.

## Topic: Download format (native vs. PDF proxy)
- **Decision**: Default to streaming the native Drive file via the service account, with optional format overrides (e.g., PDF export) controlled by MIME metadata.
- **Rationale**: Users expect SOWs/change orders to remain editable (Docs) or maintain original formatting (Sheets). Using Drive’s export APIs to convert everything to PDF could strip collaborative features and slow downloads. Native streaming, coupled with caching short-lived download metadata, keeps edits and comments intact.
- **Alternatives Considered**:
  - Always export to PDF – safer for read-only but breaks editing workflows.
  - Pre-download and store copies in Postgres – violates thin DB principle and duplicates Drive storage.

## Topic: Cache invalidation & TTL strategy
- **Decision**: Use two ETS namespaces: `:shared_documents_listings` (keyed by `{user_id, project_id}` with 5-minute TTL) and `:shared_documents_downloads` (keyed by `document_id` storing short-lived download descriptors for ≤2 minutes). All write pathways (sync, visibility toggles, ACL updates) will call a shared invalidation helper.
- **Rationale**: Listings change infrequently but must reflect admin toggles quickly; 5-minute TTL plus explicit invalidation covers both. Download URLs must expire rapidly to avoid permission leaks, so 2-minute TTL strikes balance between repeated downloads and security.
- **Alternatives Considered**:
  - No caching – would hit Drive/Notion on every view, slowing client pages.
  - Long-lived caches (>30 min) – risk staleness and client seeing outdated ACLs.

## Topic: Drive permission automation approach
- **Decision**: Store each project’s Drive folder ID and call Drive Permissions API to grant/revoke access at the folder level, letting file ACLs inherit. For files that break inheritance, the system will explicitly apply `share_folder/3` fallbacks. Permission updates will run synchronously on assignment change but enqueue retries on errors.
- **Rationale**: Managing ACLs at the folder avoids per-file churn and aligns with current Drive org structure (Clients/<Client>/<Project>/SOW...). Folder-level permissions also ensure newly added files inherit automatically.
- **Alternatives Considered**:
  - Per-file permission updates – more precise but scales poorly and increases API usage.
  - Manual Drive administration – contradicts automation goals and increases operational toil.

## Topic: Notion doc ingestion
- **Decision**: Reuse the existing Notion sync (which already fetches KB pages) by tagging relevant pages (`Doc Type`, `Visibility`). The sync job will export metadata into `shared_documents` with `source=:notion` and store the Notion page ID for rendering.
- **Rationale**: Leveraging the current sync avoids another integration surface and lets PMs continue managing internal documentation in Notion. Tagging provides a deterministic way to select which pages surface externally.
- **Alternatives Considered**:
  - Build a new Notion integration just for contracts – redundant and would fork logic.
  - Require manual entry in DashboardSSD – defeats purpose of syncing canonical docs from Notion.
