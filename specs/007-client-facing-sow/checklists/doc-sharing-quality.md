# Checklist – Document Sharing Requirements Quality

**Purpose**: Validate clarity and completeness of the Drive/Notion document sharing requirements before implementation  
**Created**: 2025-11-13  
**Feature**: specs/007-client-facing-sow/spec.md  
**Audience**: PR reviewers assessing requirements quality

## Requirement Completeness
- [ ] CHK001 Are client vs. staff visibility requirements enumerated for every surface (portal tab, staff Contracts view, download proxy) so no document state is undefined? [Completeness, Spec FR-003/FR-004]
- [ ] CHK002 Do workspace bootstrap requirements list each Drive (Contracts, SOW, Change Orders) and Notion (Project KB, Runbook) section so provisioning scope is explicit? [Completeness, Spec FR-010]
- [ ] CHK003 Are admin-triggered and automatic workspace generation flows documented, including when bootstrap must rerun for existing projects? [Completeness, Plan Phase 5, Tasks T037–T039]

## Requirement Clarity
- [ ] CHK004 Are telemetry targets (download ≤3 s, ACL ≤1 min, stale cache <2%, toggle ≤30 s) defined with measurement windows and data sources so verification is objective? [Clarity, Spec SC-001–SC-004, FR-011]
- [ ] CHK005 Is “selective generation” of workspace sections described with clear rules (defaults, per-role options, disallowed combinations)? [Clarity, Spec FR-010, Plan Phase 2]
- [ ] CHK006 Are Notion render/export limits (supported block types, read-only constraints) specified to avoid ambiguity around unsupported content? [Clarity, Spec FR-009]

## Requirement Consistency
- [ ] CHK007 Do RBAC requirements for `contracts.client.view` and `projects.contracts.manage` align across spec, plan, and tasks without conflicting capability scopes? [Consistency, Spec FR-003/FR-004, Plan Phase 4, Tasks T017–T036]
- [ ] CHK008 Are cache invalidation expectations (spec FR-007 vs. tasks T009/T029) consistent on when to bust listings and download caches? [Consistency, Spec FR-007, Tasks T009/T029]

## Scenario Coverage
- [ ] CHK009 Are all documented edge scenarios (deleted documents, missing ACLs, oversized downloads, empty states) accompanied by requirements describing expected UX responses? [Coverage, Spec Edge Cases, Tasks T019–T026]
- [ ] CHK010 Are Drive/Notion sync failure and quota/backoff flows defined, including retry telemetry and operator alerts? [Coverage, Spec FR-002, Plan Phase 3, Tasks T027–T030]

## Edge Case Coverage
- [ ] CHK011 Are requirements provided for “no assigned documents/projects” states for both client and staff personas (empty panels, messaging, next steps)? [Edge Case, Spec User Stories/Edge Cases]

## Non-Functional Requirements
- [ ] CHK012 Does the stale-cache metric specify how the <2% threshold is calculated (rolling window length, sample size) so SC-004 is testable? [Measurability, Spec SC-004, Tasks T029]
- [ ] CHK013 Are alert thresholds for download latency and ACL propagation explicitly defined (e.g., percentile, evaluation horizon)? [Non-Functional, Spec FR-011, Plan Phase 6]

## Dependencies & Assumptions
- [ ] CHK014 Are external integration dependencies (Drive service account scopes, Notion API limits, ETS capacity) captured along with assumptions and mitigation plans? [Dependencies, Spec Dependencies, Plan Technical Context]

## Ambiguities & Conflicts
- [ ] CHK015 Is the distinction between view-only vs. editable documents (Drive vs. Notion content) clearly articulated so no doc type straddles both behaviors? [Ambiguity, Spec FR-005/FR-009]
- [ ] CHK016 Are repository-managed Markdown templates versioned/owned so requirement updates remain traceable (no “mystery” template content)? [Traceability, Spec FR-010, Tasks T011–T013]
