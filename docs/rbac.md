# RBAC Management Guide

DashboardSSD exposes a capability-driven RBAC system with three supported roles: Admin, Employee, and Client. Admins can manage capability assignments via the app, while employees and clients receive least-privilege defaults.

## Default Capabilities

| Role     | Capabilities                                                                 |
|----------|-------------------------------------------------------------------------------|
| Admin    | All capabilities                                                              |
| Employee | `dashboard.view`, `projects.view`, `clients.view`, `knowledge_base.view`, `settings.personal` |
| Client   | `dashboard.view`, `projects.view`, `knowledge_base.view`, `settings.personal` |

The canonical capability catalog lives in `lib/dashboard_ssd/auth/capabilities.ex`.

## Updating Capabilities

1. Sign in as an admin and open **Settings → RBAC Settings**.
2. Toggle the capability checkboxes for each role.
3. Changes apply on the next navigation; users do not need to log out.
4. Use **Restore defaults** to revert to the baseline matrix.

## Environment Configuration

- `SLICKAGE_ALLOWED_DOMAINS`: Comma-separated list of Google Workspace domains that should be treated as internal Slickage users (defaults to `slickage.com` in production, `slickage.com,example.com` in tests).

External Google accounts are blocked until an admin invites the user and assigns the Client role.

## Local Role Switching

For local testing, run the mix task:

```bash
mix dashboard.role_switch --role employee [--email user@slickage.com]
```

- Defaults to the first user when `--email` is omitted.
- Only available in `dev` or `test` environments.

## Auditing

Each capability change records the `granted_by_id` and timestamp via the `role_capabilities` table. The Settings page displays the most recent change for each role.
