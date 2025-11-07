# Data Model – Simplified RBAC

## Role (existing)
- **Fields**: `id`, `name`, `inserted_at`, `updated_at`
- **Relationships**: `has_many :users`; `has_many :role_capabilities`
- **Validations**: `name` required, unique across records; limited to `admin`, `employee`, `client`
- **Notes**: Default seed ensures three roles exist; other names should be migrated or blocked during updates.

## User (existing reference)
- **Fields**: `id`, `email`, `name`, `role_id`, timestamps
- **Relationships**: `belongs_to :role`; `has_many :external_identities`
- **Validations**: `email` required + unique; `role_id` required after RBAC migration to avoid orphaned users
- **State**: Users authenticate via Google OAuth; role assignment may be auto-derived from email domain or admin override.

## RoleCapability (new)
- **Purpose**: Persist capability grants per role with audit metadata.
- **Fields**:
  - `id`
  - `role_id` (FK → roles)
  - `capability` (string enum, e.g., `dashboard.view`, `projects.manage`)
  - `granted_by_id` (FK → users, nullable for seed/default)
  - `inserted_at`, `updated_at`
- **Relationships**: `belongs_to :role`; `belongs_to :granted_by, DashboardSSD.Accounts.User`
- **Validations**:
  - `role_id` required; foreign key enforced
  - `capability` required and drawn from canonical capability list
  - Unique constraint on (`role_id`, `capability`)
- **State Transitions**:
  - **Grant**: insert new record with `granted_by_id`
  - **Revoke**: delete record after verifying guard rails (e.g., admin retains required capabilities)
  - **Restore defaults**: transactional replace using seeded baseline mapping

## Capability Catalog (code-driven)
- **Definition**: Enumerated list maintained in `DashboardSSD.Auth.Capabilities` module; includes metadata for settings UI (label, description, groups, manage vs view pairings).
- **Usage**: Settings form, navigation filtering, policy evaluation. Enforced through compile-time list and used to validate `RoleCapability` entries.

## Audit Metadata
- **Storage**: `RoleCapability.updated_at` + `granted_by_id` satisfy FR-010; optional extension to reuse existing audit log if heavier traceability required.
- **Access**: Settings UI displays last updated timestamp/user per role by querying latest capability change.
