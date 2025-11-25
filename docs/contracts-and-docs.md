# Contracts & Docs Playbook

This document captures how the Contracts & Docs feature works across Drive, Notion, and
DashboardSSD so engineers can reason about templates, permissions, and automation.

## Workspace Bootstrap

* **Blueprint** – `config/*.exs` defines Drive and Notion sections (Contracts, SOW,
  Change Orders, Project KB). Each section points to a Markdown template under
  `priv/workspace_templates/**`.
* **Notion hierarchy** – `NOTION_PROJECTS_KB_PARENT_ID` (or `NOTION_CONTRACTS_PAGE_PARENT_ID`)
  points to the Projects KB database (rows = clients). Each client entry links to a child page,
  that page contains one child page per project, and each project page receives a templated
  doc (and future docs) rendered from `priv/workspace_templates/notion/project_kb.md`.
* **Automatic bootstrap** – `DashboardSSD.Documents.bootstrap_workspace/2` is invoked
  when projects are created with a Drive folder and whenever a client is created (all of
  their projects get bootstrapped). The default sections come from
  `DashboardSSD.Projects.workspace_sections/0`.
* **Manual regeneration** – Staff can open the “Regenerate” action in Projects →
  Contracts LiveView. The side form lists every enabled blueprint section so admins can
  selectively re-run Drive or Notion provisioning without touching unrelated artifacts.

## Drive ACL Automation

* Client assignment changes propagate through `DashboardSSD.Projects.handle_client_assignment_change/2`.
  Assigning a client user shares every visible Drive document for their projects. Removing the
  assignment revokes permissions, invalidates ETS caches, and records audit entries in
  `document_access_logs`.
* `DashboardSSD.Projects.DrivePermissionWorker` wraps Drive API calls with retries and
  emits telemetry for each share/unshare/lookup, including the attempt number and failure count.
* The worker can run inline in tests by setting `:drive_permission_worker_inline` or can be
  stubbed via `Application.put_env(:dashboard_ssd, :drive_permission_worker, ...)`.

## Telemetry & Monitoring

* **Downloads** – `[:dashboard_ssd, :documents, :download]` emits a `:duration` measurement
  with `status`, `source`, and user metadata for each client download (success, forbidden, oversized,
  etc.). This feeds SC-001 dashboards.
* **Visibility Toggles** – `[:dashboard_ssd, :documents, :visibility_toggle]` measures how
  long staff updates take so we can watch SC-003.
* **Drive ACL Sync** – `[:dashboard_ssd, :drive_acl, :sync]` captures share/unshare runtimes
  plus a failure counter so on-call can alert on repeated Drive errors (SC-002).
* **Cache Staleness** – Drive/Notion sync telemetry already publishes `:stale_pct`; we added
  `last_value` metrics so alerts can fire when the percentage exceeds 2%.

Hook Grafana/Observer dashboards into `DashboardSSDWeb.Telemetry.metrics/0` to export the
new metrics or wire them to StatsD/Prometheus reporters.

## Open Questions

1. **Approvals** – Workspace templates assume PMs upload signed contracts manually. We still
   need a policy for capturing approvals or electronic signatures.
2. **Client uploads** – There is no upload flow for counter-signed SOWs. What is the preferred
   handoff from clients back to Slickage (Drive request folder, email, future portal upload)?
3. **Notifications** – We do not notify clients when new docs land in the Contracts tab. Should
   we hook Slack/email once telemetry shows stable latency?
