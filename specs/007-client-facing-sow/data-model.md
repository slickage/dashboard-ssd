# Data Model – Client-Facing SOW Storage & Access

## SharedDocument (new)
- **Purpose**: Canonical metadata row for every Drive/Notion document surfaced in DashboardSSD.
- **Fields**:
  - `id` – UUID primary key.
  - `client_id` – FK → `clients.id`, required.
  - `project_id` – FK → `projects.id`, nullable for client-wide docs.
  - `source` – enum (`drive`, `notion`).
  - `source_id` – string (Drive file ID or Notion page ID), unique per `source`.
  - `doc_type` – string (e.g., `sow`, `change_order`, `runbook`).
  - `title` – string.
  - `description` – text, optional.
  - `visibility` – enum (`internal`, `client`).
  - `client_edit_allowed` – boolean, default `false`.
  - `mime_type` – string for download proxy.
  - `metadata` – map/JSONB for arbitrary tags (e.g., Notion properties, Drive custom props).
  - `etag` / `checksum` – string used to detect remote changes.
  - `last_synced_at` – UTC timestamp for sync diagnostics.
  - `inserted_at` / `updated_at`.
- **Relationships**: `belongs_to :client`, `belongs_to :project (optional)`, `has_many :document_access_logs`.
- **Validations**:
  - Presence for `client_id`, `source`, `source_id`, `title`, `visibility`.
  - Enum enforcement for `source`/`visibility`.
  - Unique constraint on `{source, source_id}`.
  - `client_edit_allowed` only true when `source = :drive`.
- **State Transitions**:
  - `sync_upsert`: update metadata if checksum changed; otherwise leave timestamps untouched.
  - `visibility_toggle`: mutate `visibility`/`client_edit_allowed` from staff UI, triggering cache invalidation + Drive ACL updates.

## DocumentAccessLog (optional, new)
- **Purpose**: Immutable audit of downloads, permission grants, and related actions.
- **Fields**:
  - `id` – bigint primary key.
  - `shared_document_id` – FK → `shared_documents`.
  - `actor_id` – FK → `users` (nullable for system jobs).
  - `action` – enum (`download`, `open_in_source`, `permissions_granted`, `permissions_revoked`, `visibility_changed`).
  - `context` – map/JSONB (e.g., Drive permission role, IP, user agent).
  - `inserted_at`.
- **Validations**: Presence for `shared_document_id` and `action`; restrict actions to enum; ensure `actor_id` references `users` when present.
- **Usage**: Download proxy writes `download`; assignment hooks write `permissions_*`; staff toggles write `visibility_changed`.

## ProjectDriveFolder (stored within existing Projects schema)
- **Purpose**: Track the Drive folder ID for each project and whether sharing inheritance is intact.
- **Fields**:
  - `project_id` – FK.
  - `drive_folder_id` – string.
  - `sharing_inherited` – boolean default true.
  - `last_permission_sync_at` – timestamp.
- **Notes**: Likely stored via new columns on `projects` table or dedicated JSON metadata; used by automation hooks.

## Cache Namespaces (ETS metadata)
- **`:shared_documents_listings`**: keys = `{user_id, project_id_or_nil}`, values = `%{documents: [...], cached_at: ...}`, TTL 5 minutes.
- **`:shared_documents_downloads`**: keys = `document_id`, values = `%{drive_file_id, mime_type, expires_at}`, TTL 2 minutes.
- **Invalidate**: `DashboardSSD.Cache.SharedDocuments.invalidate_listing/1` and `.invalidate_document/1` invoked after syncs, toggles, and permission updates.

## Capability Extensions
- **Capability Codes**:
  - `projects.contracts.view` – allows staff to view/manage Contracts tab.
  - `projects.contracts.manage` – allows toggling visibility/edit permissions.
  - `contracts.client.view` – auto-granted to client role for assigned projects.
- **Policy**: Update `DashboardSSD.Auth.Policy` to require `projects.contracts.manage` for staff UI actions, `contracts.client.view` for portal listing, and `settings.rbac` for global toggles.
