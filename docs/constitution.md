# Slickage Product Constitution (Clients → Projects → Tasks)

## Non-Negotiables
- **Simple domain model**: `Client` → `Project`. Tasks live in **Linear** (no in-app boards).
- **Integration-first**: Linear (tasks/workload), Slack (alerts/digests; no chat UI), Google OAuth (auth) + Drive (SOW/CR docs), Notion (KB/case-studies index), GitHub Checks (read-only CI).
- **LiveView-first** UI; controllers only for OAuth/webhooks.
- **Project is the hub**: Each Project links to Linear project/team, Slack channel, Drive folder, Notion DB/page, optional GitHub repo. Work Status is always **project-scoped**.
- **Home (Org Overview)**: projects + clients rollup + team workload (from Linear) + incidents/CI + quick links.
- **Thin DB**: `users`, `clients`, `projects`, `external_identities`, `sows`, `change_requests`, `deployments`, `health_checks`, `alerts`, `notification_rules`, `metric_snapshots`, `audits`.
- **Tooling gates from day 0**: `mix format`, **Credo (strict)**, **Dialyzer**, `mix test`, `mix docs` pass **pre-commit** and **CI**.
- **Types & docs required**: public modules/functions must have `@moduledoc`/`@doc`; functions carry `@spec` where it clarifies types (keep Dialyzer useful).
- **RBAC**: roles **admin**, **employee**, **client**; least-privilege; client users only see their client’s projects.
- **Time**: store UTC; display user TZ (default Pacific/Honolulu).
- **Security**: scoped tokens, encrypted secrets, idempotent webhooks; audit SOW/CR and alert acks.

## Scope Guardrails (MVP)
- **In**: Home overview; Client/Project workspaces; SOW/CR metadata (docs in Drive); Linear work status + create issue; Slack alerts/digest; Notion KB index; Deployments/Health; GitHub Checks; minimal analytics.
- **Out**: chat UI; in-app ticket board; full CRM; in-app document editor.

## Writing & Review
- Use concise bullets/tables; Gherkin where helpful.
- Every artifact includes **Constitution Compliance**, **Success Metrics**, and ≥3 **Risks** with mitigations.
