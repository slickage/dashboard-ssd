# Feature Specification: Simplified Role-Based Access Control

**Feature Branch**: `[006-simplify-rbac]`  
**Created**: 2025-11-03  
**Status**: Draft  
**Input**: User description: "Currently the RBAC isnt consistent. Its not quite right. I want it to be simple, there should only be three roles Admin, Employee and Client. Evaulate the current views and make your best assumptions about what each role should have access too. make this easy to update via the settings page if you are an admin. You should be able to grant more privelages to a role via the admin page if you are an admin. There should also be a function I can run to easily switch my role for testing purposes locally"

## Clarifications

### Session 2025-11-03

- Q: Which Google domains should qualify a user as part of the Slickage organization for Admin/Employee roles? → A: Maintain an env-configurable list of approved Slickage domains (default slickage.com).
- Q: How should external (non-Slickage) Google domains be handled on first sign-in attempts? → A: Block sign-in until an admin pre-invites the account as a Client.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Admin curates role privileges (Priority: P1)

As the company admin, I can review and adjust which product areas each role can see or manage from the settings page,
so that the team can react to policy changes without engineering support.

**Why this priority**: Without this, administrators cannot fix misaligned permissions and the product blocks adoption.

**Independent Test**: Sign in as an admin, change a privilege mapping, reload as another role, and confirm access reflects
the update.

**Acceptance Scenarios**:

1. **Given** an admin on the settings page, **When** they toggle access to Projects for employees, **Then** employees lose
   the Projects navigation item and are redirected if they visit its URL.
2. **Given** an admin reviewing privileges, **When** they restore defaults, **Then** all three roles regain the documented
   baseline access.
3. **Given** a saved configuration, **When** the application restarts, **Then** the chosen privileges remain in place.

---

### User Story 2 - Non-admins experience consistent access (Priority: P2)

As an employee or client, I only see pages I am allowed to use and I get a clear message when something is off-limits,
so that I can work confidently without trial and error.

**Why this priority**: Predictable access reduces support tickets and protects sensitive data.

**Independent Test**: Log in as each role, verify visible navigation matches the role matrix, and confirm restricted pages
redirect with an explanatory alert.

**Acceptance Scenarios**:

1. **Given** an employee without Analytics rights, **When** they open `/analytics`, **Then** they return to the dashboard
   with a message explaining the restriction.
2. **Given** a client user, **When** they view the navigation, **Then** only Dashboard, Projects (read-only), Knowledge Base,
   and personal settings appear.
3. **Given** an employee assigned new permissions, **When** they refresh, **Then** the new areas are available without a
   logout/login cycle.

---

### User Story 3 - Developer toggles roles for testing (Priority: P3)

As a developer or QA tester working locally, I can switch the active account between Admin, Employee, and Client test roles
with a single command, so that I can verify permission changes without manual database edits.

**Why this priority**: Fast role switching shortens QA cycles and prevents production configuration from being touched.

**Independent Test**: Run the documented role-switch command for each role in a non-production environment and confirm the
session updates immediately.

**Acceptance Scenarios**:

1. **Given** a developer on a local machine, **When** they invoke the role-switch helper with `employee`, **Then** the
   current session behaves as an employee until changed again.
2. **Given** the helper is run in production, **When** it detects the environment, **Then** it refuses to run and explains
   why.
3. **Given** the helper finished successfully, **When** the developer revisits the settings page, **Then** the displayed
   role matches the selected option.

### Edge Cases

- Admin attempts to remove the last remaining admin privilege for managing settings; system blocks the change and informs
  them why.
- Role privileges are updated while users are active; their next navigation reflects the new rules without exposing
  restricted data mid-session.
- Role data becomes inconsistent (e.g., legacy role name); the system maps or rejects it gracefully and prompts an admin
  to correct the user record.
- External-domain user attempts sign-in before invitation; login is blocked with guidance to contact an administrator.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The platform MUST recognize only three roles (Admin, Employee, Client) and ensure every user belongs to one
  of them.
- **FR-002**: The system MUST define a canonical list of manageable capabilities (Dashboard, Projects view/manage, Clients
  view/manage, Knowledge Base, Analytics, Personal Settings, RBAC Settings) used for authorization decisions.
- **FR-003**: The system MUST ship with default capability assignments: Admin = all capabilities; Employee = Dashboard,
  Projects view, Clients view, Knowledge Base, Personal Settings; Client = Dashboard, Projects view, Knowledge Base,
  Personal Settings.
- **FR-004**: Admins MUST be able to modify which capabilities belong to each role from the settings page and persist those
  changes.
- **FR-005**: Admins MUST be able to restore the default capability assignments in a single action.
- **FR-006**: Authorization MUST rely on the stored role-to-capability mapping for navigation, guard clauses, and
  action-level controls (e.g., hide manage forms when manage rights are absent).
- **FR-007**: Users MUST see navigation items and call-to-actions only for capabilities their role owns, and direct URL
  access to blocked areas MUST redirect with a clear message.
- **FR-008**: Admins MUST always retain the RBAC Settings and Personal Settings capabilities; the UI MUST prevent saving a
  configuration that would revoke these from all admins.
- **FR-009**: Changes to role privileges MUST take effect for current sessions on their next request without requiring
  logout.
- **FR-010**: The product MUST surface when privileges were last updated and by which admin, so changes are traceable.
- **FR-011**: A documented non-production helper MUST allow switching the current user’s role among the three options and
  refuse execution in production.
- **FR-012**: External Google accounts MUST be prevented from completing sign-in until the user has been pre-invited or provisioned as a Client by an admin.

### Key Entities *(include if feature involves data)*

- **Role**: Represents one of the three supported personas; stores the display name and links to users.
- **Capability**: Describes a named area of the product (e.g., “Projects (manage)”) with human-readable labels used on the
  settings page.
- **Role Capability Assignment**: Records which capabilities each role currently owns, along with metadata about who
  updated it and when.

## Assumptions

- Default content and datasets are organization-wide; there is no per-client data segregation introduced by this feature.
- Existing admins and employees are already mapped to the correct role names; migrating orphaned roles is handled via
  support, not automated here.
- Privilege changes do not need historical versioning beyond the “last updated by” indicator.
- Admin/employee accounts authenticate via Google OAuth emails matching the configured Slickage domain allowlist.
- Client users must be pre-invited or provisioned before their external Google account can sign in successfully.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For each role, 100% of hidden capabilities remain inaccessible through direct URLs, confirmed by attempting
  every restricted route once per release.
- **SC-002**: After an admin updates a privilege, affected users see the change reflected in navigation within one page
  refresh (under five seconds on a typical connection).
- **SC-003**: Privilege configurations persist through at least one application restart without manual intervention,
  validated twice during QA.
- **SC-004**: Developers can switch among all three roles locally in under 30 seconds using the documented helper,
  demonstrated during release testing.
