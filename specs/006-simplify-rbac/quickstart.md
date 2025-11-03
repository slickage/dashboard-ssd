# Quickstart – Simplified RBAC

1. **Sync branch**: `git checkout 006-simplify-rbac` and pull latest changes.
2. **Ensure Google OAuth config**: Populate `GOOGLE_CLIENT_ID`/`SECRET` and set `SLICKAGE_ALLOWED_DOMAINS` env list (comma-separated) for restricting admin/employee logins.
3. **Run setup**: `mix setup` to fetch deps and prepare the database.
4. **Apply migrations**: `mix ecto.migrate` (adds `role_capabilities` table and constraints).
5. **Seed defaults**: `mix run priv/repo/seeds.exs` ensures baseline role-capability mapping.
6. **Start server**: `iex -S mix phx.server` and visit `/settings` as an admin to verify RBAC configuration UI.
7. **Run tests**: `mix test` followed by `mix check` before submitting changes.
8. **Local role switch**: `mix dashboard.role_switch --role employee` (non-prod only) to validate permissions per role.
