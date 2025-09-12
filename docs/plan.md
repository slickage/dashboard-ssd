Use this as a reference:
<<< ./docs/constitution.md >>>
Source requirements:
<<< ./docs/discovery.md >>>


Produce a **TECHNICAL PLAN** to get a running Phoenix + LiveView app fast, with adapters/webhooks and tooling first.

DELIVER:
1) Architecture
   - LiveViews: Home, Clients, Projects (Project Dashboard), SOW/CR, Work Status (Linear, project-scoped), Deployments/Health, KB (Notion), Settings/Integrations
   - Contexts: Users/Auth, Clients, Projects, Contracts, Deployments, Notifications, Analytics, Integrations (Linear/Slack/Google/GitHub/Notion/Drive), Webhooks, Audit
   - Controllers only for OAuth + webhooks
2) Data Model (DDL sketch, thin): users, roles, clients, projects, external_identities, sows, change_requests, deployments, health_checks, alerts, notification_rules, metric_snapshots, audits (indexes/FKs/uniques; soft-delete/audit)
3) Integrations (behaviours + stubs + Mox): Linear (GraphQL; list & create issues; webhook), Slack (alerts/digest), Google (OAuth; Drive), Notion (pages by DB/tag), GitHub Checks (read)
4) **RBAC**: role model + policies; LiveView `on_mount` hooks; route guards
5) Background Jobs (Oban): heartbeat/SSL, weekly digest, CI refresh, token refresh
6) Home Overview queries + caching/TTL + manual refresh
7) Observability: logs/metrics/errors; audit entries
8) **Tooling, Docs & CI**: Credo strict (fail on missing docs for public APIs), Dialyzer PLT caching, ExUnit, `mix docs`, `mix format`; pre-commit + GitHub Actions mirroring gates
9) Incremental slices with risks/rollback

End with **Constitution Compliance** and a rate-limit/token/webhook risk table.
