# Feature Specification: Client-Facing SOW Storage & Access

**Feature Branch**: `007-client-facing-sow`  
**Created**: 2025-11-13  
**Status**: Draft  
**Input**: User description: "Client-Facing SOW Storage & Access – Drive remains the canonical source for contracts, Notion stays for internal docs, expose cached/permission-aware listings plus download proxy for clients."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Client views and downloads a contract (Priority: P1)

Client users need a single “Contracts & Docs” tab in the portal that lists every SOW/change order tied to the projects they are assigned to so they can download or open the Google Doc (when edit access is granted) without leaving DashboardSSD.

**Why this priority**: Delivering the client-facing experience is the stated goal and directly unblocks handoffs and signature cycles.

**Independent Test**: Seed a client user with one assigned project, create a Drive-backed shared document with visibility=client, log in as that user, and confirm the list, download, and edit link behavior without touching staff-only flows.

**Acceptance Scenarios**:

1. **Given** a client user assigned to Project A with a Drive SOW marked client-visible, **When** the user opens the Contracts tab, **Then** they see the SOW entry with Download + “Edit in Google Docs” actions that mirror the Drive ACL.
2. **Given** a client user without any eligible docs, **When** they open the Contracts tab, **Then** they see an empty state explaining that no client-visible documents exist.

---

### User Story 2 - Staff curates and audits shared documents (Priority: P2)

Project managers and admins need to browse every shared document (Drive + Notion), toggle whether clients can see/edit it, and jump to the source system so they can manage contracts without context switching.

**Why this priority**: Internal control precedes automation; staff must be able to govern visibility before clients can rely on the feature.

**Independent Test**: Log in as an admin with `settings.rbac`, open the staff-facing Projects → Contracts panel, update visibility/ACL toggles, and verify the change propagates to metadata plus Drive permissions without needing the client view.

**Acceptance Scenarios**:

1. **Given** a staff user with `projects.manage`, **When** they toggle “Client can edit” on a Drive file, **Then** the system updates Drive permissions, cache entries, and immediately reflects the change in the staff list.
2. **Given** a staff user viewing a Notion-only doc, **When** they click “Open in Notion”, **Then** they are redirected using the stored Notion page link and the action is logged.

---

### User Story 3 - Automatic permission alignment during project assignment changes (Priority: P3)

When a client contact is added to or removed from a project, the system should automatically grant/revoke Drive folder/file permissions, refresh cached document listings, and audit the change so no manual Drive work is needed.

**Why this priority**: Automation reduces operational toil and prevents leaks when people leave a project; while not the initial MVP, it closes the loop promised in the requirements.

**Independent Test**: Simulate assigning a client user to a project with existing shared documents, observe Drive permission updates and cache invalidation, then unassign and confirm access disappears while the audit log records both events.

**Acceptance Scenarios**:

1. **Given** a client user without Drive access, **When** they are associated with a project that has a Drive folder, **Then** the system grants appropriate reader/writer permissions and the user can immediately download docs in the portal.
2. **Given** a user that is removed from all projects, **When** the removal completes, **Then** Drive permissions are revoked and subsequent portal visits show no documents.

### Edge Cases

- Drive metadata says a file is client-visible but its ACL is missing the client’s email → system should flag the mismatch and restrict download until ACL sync succeeds.
- Shared document references a deleted Drive/Notion item → listing displays a warning badge and the sync job retries/backoff without crashing.
- Cache warmer presents stale results after manual admin change → cache invalidation must occur immediately after any metadata or ACL update to avoid showing outdated access.
- Client attempts to request download for a document larger than the proxy streaming threshold → show a friendly error instructing them to open in Drive directly (with audit log).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The platform MUST introduce a `shared_documents` catalog that stores per-document metadata (client/project associations, source system, doc type, visibility, mime type, updated_at, tags) so listings can be generated without hitting Drive/Notion in real time.
- **FR-002**: Sync workers MUST keep `shared_documents` up to date by periodically scanning Drive project folders (using metadata/custom properties) and ingesting Notion contract pages, leveraging the existing cache warmer patterns to avoid redundant scans.
- **FR-003**: Staff-facing UI MUST list every shared document tied to the selected client or project, surface source-specific quick actions (“Open in Drive/Notion”, “Download”), expose visibility/edit toggles, and require `settings.rbac` or `projects.manage` capability.
- **FR-004**: Client portal MUST display only records with `visibility = client` that match the viewer’s assigned clients/projects (per RBAC and capability checks) and hide all staff-only metadata.
- **FR-005**: Downloads MUST be served through a DashboardSSD proxy that uses the service account to fetch the Drive file (respecting mime/format), streams the content, and records an audit entry capturing user, document id, timestamp, and action.
- **FR-006**: Project assignment changes MUST trigger Drive permission grants or revocations (reader vs. writer depending on “Allow client edits”) plus cache invalidation for affected users so access stays in sync without manual work.
- **FR-007**: Cached document listings and download URLs MUST use the shared ETS cache namespaces with TTLs and be invalidated immediately after sync writes, ACL changes, or manual visibility edits to prevent stale visibility states.
- **FR-008**: The system MUST provide an audit surface (log or table) that tracks each download/open action and each automatic permission change so compliance teams can trace document distribution.
- **FR-009**: Notion-sourced docs MUST remain view-only for clients; the platform must render them server-side (HTML and downloadable PDF) via the Notion API so clients never receive direct Notion links.
- **FR-010**: Workspace scaffolding MUST be generated from repository-managed Markdown templates for Drive sections (Contracts, SOWs, Change Orders, etc.) and Notion KB pages, allowing admins to choose which sections to provision per client/project.
- **FR-011**: The system MUST emit telemetry for download latency, Drive ACL propagation time, and visibility toggle propagation so Success Criteria SC-001 to SC-003 are measurable in staging/production.

### Key Entities *(include if feature involves data)*

- **SharedDocument**: Represents any client-facing or internal contractual artifact. Attributes include `id`, `client_id`, optional `project_id`, `source` (`drive` or `notion`), `source_id`, `doc_type`, `title`, `visibility`, `mime_type`, `client_edit_allowed`, `metadata` map, timestamps, and cache-related fields (ETag/hash) used for sync deduping.
- **DocumentAccessLog**: Records each download/view action and permission automation event. Captures `shared_document_id`, `user_id`, `action` (`download`, `open_source`, `permissions_granted`, etc.), `performed_by` (system vs. human), timestamp, and contextual metadata (e.g., Drive permission role).
- **ProjectDocumentFolder**: Derived mapping between a project and its Drive folder id, required for ACL automation and stored alongside sync cursors/error state so the system knows how to re-share items.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 95% of client downloads complete in ≤3 seconds for files under 25 MB when served via the proxy, measured over a rolling 7-day window.
- **SC-002**: 100% of Drive documents tagged with `visibility = client` reflect the correct Drive ACL (reader/writer) within 1 minute of a project assignment change, as shown in audit logs.
- **SC-003**: Staff are able to toggle client visibility for any document and see the change reflected in both staff and client listings within 30 seconds, validated in staging smoke tests.
- **SC-004**: <2% of sync cycles end with stale cache entries (detected via checksum mismatch alerts), indicating caching/invalidation rules are effective.

## Assumptions & Constraints

- Visibility approval happens inside DashboardSSD; there is no separate legal approval workflow in scope for this iteration.
- Clients do not upload edited contracts back through DashboardSSD; any counter-signed uploads are handled manually in Drive for now.
- Notifications (email/Slack) about new documents are deferred; the Contracts tab serves as the discovery surface in this release.

## Dependencies

- Existing Google Drive service account credentials and root folder configuration must be available in all environments.
- Current Notion knowledge-base sync jobs must expose hooks/events so contractual pages can be tagged and ingested into `shared_documents`.
- ETS cache infrastructure (`DashboardSSD.Cache` plus namespace helpers) remains the primary mechanism for warmed listings and must support a new namespace dedicated to shared documents.

## Constitution Compliance

- **Library-First**: Workspace bootstrap, documents catalog, and sync workers live inside dedicated contexts (`DashboardSSD.Documents`, `DashboardSSD.Integrations`) with clear APIs.
- **LiveView-First**: Both staff and client experiences are Phoenix LiveViews; the only controller addition is the download proxy.
- **Thin Database**: New tables (`shared_documents`, `document_access_logs`) are limited to metadata/audit requirements and justified by compliance obligations.
- **Integration-First**: Drive remains the canonical source for contracts and Notion for knowledge base content; DashboardSSD orchestrates metadata and access without duplicating editing surfaces.
- **RBAC**: New capabilities (`contracts.client.view`, `projects.contracts.manage`) enforce least-privilege access so clients only view their own projects while admins/employees govern visibility.
