# Feature Specification: Meetings Page with Fireflies Agendas & Summaries

**Feature Branch**: `[001-add-meetings-fireflies]`  
**Created**: 2025-10-31  
**Status**: Draft  
**Input**: User description: "Make a new page called `Meetings`. The `Meetings` page should have info from fireflies.ai, and show the agenda for a meeting before we start it as well as the meeting summary and action items once we finish. The agenda should come from fireflies.ai previous meeting notes/action items for the specified recurring meeting. We should be able to add more info to the agenda manually too. In the Meetings page I want to be able to see the upcoming meetings I have, and I want to know what info I need to bring to the the meeting (from the agenda). If possible, I want each meeting to be associated with an existing Client or Project (guess via keywords in the name of the meeting) - if the meeting cannot be associated with a Client or Project I want to be able to associate it by picking in the UI."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Prepare from previous notes (Priority: P1)

As a user, I can open a Meetings page showing my upcoming meetings and, for each, see a pre-meeting agenda automatically built from the previous occurrence’s notes and action items in Fireflies for that recurring meeting. The page highlights “what to bring” so I know what information or materials to prepare.

**Why this priority**: Enables effective preparation and is the core value of the Meetings page.

**Independent Test**: With one recurring meeting that has at least one prior occurrence in Fireflies, verify the next upcoming occurrence displays an agenda derived from the previous notes/action items and a “to bring” summary.

**Acceptance Scenarios**:

1. Given an upcoming meeting with at least one previous occurrence in the same series, When I view it, Then I see agenda items derived from the last occurrence’s notes and action items and a “to bring” summary.
2. Given an upcoming meeting with no previous occurrence, When I view it, Then I see an empty agenda with guidance to add items manually.

---

### User Story 2 - Edit agenda before meeting (Priority: P1)

As a user, I can add, edit, delete, and reorder agenda items for an upcoming meeting so the agenda reflects what I want to cover.

**Why this priority**: Users must tailor the auto-generated agenda to their needs.

**Independent Test**: Open an upcoming meeting and add/edit/delete/reorder items; changes persist for that meeting and display consistently.

**Acceptance Scenarios**:

1. Given an upcoming meeting, When I add a new agenda item, Then it appears in the list and persists on refresh.
2. Given I have multiple agenda items, When I reorder them, Then the new order is preserved.

---

### User Story 3 - Post-meeting summary and actions (Priority: P2)

As a user, after a meeting finishes, I can view the meeting summary and action items captured by Fireflies on the Meetings page.

**Why this priority**: Consolidates outcomes into one place to drive follow-up.

**Independent Test**: For a completed meeting with a Fireflies summary, verify the summary and action items appear; if not yet available, a pending state is shown.

**Acceptance Scenarios**:

1. Given a completed meeting with Fireflies outputs available, When I open the meeting, Then I see a summary and action items list.
2. Given a completed meeting where Fireflies outputs are not yet available, When I open the meeting, Then I see a pending state with a way to refresh later.

---

### User Story 4 - Associate meeting to Client/Project (Priority: P2)

As a user, I see each meeting associated with an existing Client or Project based on keyword matching in the meeting name; if none or multiple matches are found, I can select the correct Client or Project in the UI.

**Why this priority**: Organizes meetings by business context and enables downstream reporting.

**Independent Test**: With Clients/Projects that match meeting titles, verify auto-association; with ambiguous titles, verify a selection prompt and that my choice is applied to that meeting.

**Acceptance Scenarios**:

1. Given a meeting title containing a unique Client keyword, When I view the meeting, Then it is auto-associated to that Client.
2. Given a meeting title that matches multiple Clients/Projects, When I view the meeting, Then I’m prompted to choose and my selection is applied to that meeting.

---

### User Story 5 - See what to bring (Priority: P3)

As a user, I can quickly scan a “What to bring” section for each upcoming meeting, summarizing information or artifacts I should prepare based on the agenda.

**Why this priority**: Reduces prep time and missed items.

**Independent Test**: Confirm that agenda items marked as requiring preparation are summarized under “What to bring.”

**Acceptance Scenarios**:

1. Given agenda items marked as “requires preparation,” When I view the meeting, Then those items are summarized under “What to bring.”

---

### Edge Cases

- No previous occurrence found for a recurring meeting: show empty agenda plus guidance to add items.
- Fireflies temporarily unavailable: show agenda items already saved locally and a clear message; allow retry later.
- Fireflies returns no action items/notes for the previous occurrence: show empty agenda plus manual add.
- Summary not yet generated post-meeting: show “pending” and the last update time; allow refresh later.
- Multiple potential Client/Project matches: require user selection; do not auto-pick.
- No Client/Project match: mark as “Unassigned” and allow selection.
- Duplicate items between notes and action items: deduplicate by content and recency.
- Meeting renamed between occurrences: match by series identifier when available; otherwise match by normalized title and cadence window.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Provide a Meetings page accessible from primary navigation.
- **FR-002**: List upcoming meetings for the next 14 days by default; allow filtering by date range.
- **FR-003**: For each upcoming meeting, display title, date/time, and link to its detail view; include Client/Project association if available.
- **FR-004**: The pre-meeting agenda for an upcoming meeting must be derived from the previous occurrence in the same recurring series using Fireflies notes and action items.
- **FR-005**: When no previous occurrence exists, the agenda is empty with guidance to add items manually.
- **FR-006**: Users can add, edit, delete, and reorder agenda items for an upcoming meeting; changes persist for that meeting.
- **FR-007**: The system presents a “What to bring” summary compiled from agenda items that indicate preparation is required (e.g., items tagged or recognized as needing inputs).
- **FR-008**: After a meeting is completed, display Fireflies-generated meeting summary and action items on the meeting detail page when available; include a visible “pending” state until available and a manual refresh.
- **FR-009**: Auto-associate each meeting to an existing Client or Project via keyword matching on the meeting name (and known aliases); if multiple or no matches, require user selection in the UI.
- **FR-010**: Users can manually set or change the Client/Project association from the meeting detail view.
- **FR-011**: The system must remember my manual association choice for this specific meeting occurrence; when setting it, prompt whether to persist as the default for the recurring series. If confirmed, apply the association to future occurrences in the series.
- **FR-012**: The system must list “upcoming meetings” from the user’s primary calendar (e.g., Google/Outlook) as the source of truth.
- **FR-013**: Manual agenda additions do not propagate to future occurrences; they apply only to the selected occurrence.
- **FR-014**: Provide search/filter on Meetings page by title and by Client/Project.
- **FR-015**: All user-visible text and interactions must be understandable without technical knowledge.

### Key Entities *(include if feature involves data)*

- **Meeting**: A single scheduled event (title, start/end, attendees if available, source link, status: upcoming/completed, association to Client/Project).
- **MeetingSeries**: A recurring meeting grouping used to find the “previous occurrence.”
- **AgendaItem**: Pre-meeting item with text, optional “requires preparation” flag, order, and source (derived or manual).
- **ActionItem**: Post-meeting follow-up item with text, owner (if available), and status.
- **Summary**: Post-meeting narrative summary text.
- **Client / Project**: Existing business entities to which meetings can be associated.
- **Association**: Link from Meeting to a Client or Project; origin (auto vs manual) and confidence (for auto).

### Assumptions

- User has connected Fireflies and has historical meeting notes for some recurring meetings.
- Upcoming meetings are sourced from the user’s primary calendar by default unless specified otherwise.
- “Previous occurrence” refers to the immediately preceding meeting within the same recurring series; if unavailable, use the most recent meeting with a matching title within the last 90 days.
- “What to bring” is derived from agenda items flagged as requiring preparation and/or items recognized from previous action items assigned to the user.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can locate and open any upcoming meeting from the Meetings page in under 5 seconds (p50) with a stable network connection.
- **SC-002**: For recurring meetings with at least one prior occurrence, 90% display at least one auto-generated agenda item.
- **SC-003**: 95% of users can add, edit, and reorder agenda items without assistance in under 60 seconds for a single meeting.
- **SC-004**: Post-meeting summaries become visible within 2 hours of meeting end for 90% of meetings where Fireflies produces outputs; pending state is clearly indicated otherwise.
- **SC-005**: Auto-association to Client/Project is correct at least 80% of the time on first display; 100% of meetings can be manually corrected within two clicks.
- **SC-006**: Users report a 30% reduction in meeting preparation time after two weeks of usage (self-reported or observed).
