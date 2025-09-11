When generating constitution use this as a reference:
<<< ./docs/constitution.md >>>
Source requirements:
<<< ./docs/discovery.md >>>

PROJECT: Slickage Dashboard

GOAL:
MVP SPEC for a LiveView dashboard that unifies Clients → Projects (hub) with integration-first status:
- Tasks/workload from **Linear** (project-scoped, create via template, deep-links)
- Comms/alerts via **Slack** (no chat UI)
- Contracts/SOW/CR docs in **Google Drive** (metadata/audit in DB)
- KB in **Notion** (index + deep-links)
- Deployments/health (owned) + **GitHub Checks** card
- **Home** = overview of projects/clients/team workload with quick links

OUTPUT:
1) Problem, Goals, Non-Goals (integration-first; exclude chat UI)
2) Personas & top jobs (Anthony, Julie, Ryan, Chris, James, Client)
3) MVP Epics (LiveView) with user stories + **Acceptance Criteria**:
   - A) Foundation & Integrations (Google OAuth; connect Linear/Slack/Notion/GitHub/Drive)
   - A1) **Home Overview** (projects, clients, workload, incidents, CI; manual refresh)
   - B) Clients & Projects (Project = hub with provider links)
   - C) SOW & Change Requests (Drive-backed; audit; Slack notify)
   - D) Work Status (Linear, **project-scoped**; create issue; deep-links)
   - E) Deployments & Health (checks + Slack alerts; GitHub Checks card)
   - F) KB (Notion) & Case Studies (index + deep-links; public toggle metadata)
   - G) Minimal Analytics (uptime %, MTTR, Linear throughput; CSV)
4) Thin Data Model (entities/relations; Project-as-anchor)
5) Integration behaviours + relevant webhook events
6) **RBAC**: admin/employee/client visibility rules
7) **Success Metrics**; **Constitution Compliance**; Risks & mitigations

STYLE: tables/bullets; if a feature duplicates Linear/Slack/Drive/Notion, emit a Change Request instead.