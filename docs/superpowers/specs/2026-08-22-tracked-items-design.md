# Tracked Items Design

## Purpose

American Legion business often lasts longer than one meeting or one officer's term. A car
show, Buddy Checks, an election, a building repair, or an unresolved member question can
return for months. Agendas capture what will happen at one meeting; tracked items preserve
why the business exists, what should happen next, and where it has appeared over time.

This feature creates the continuity layer between structured agendas. It is intentionally
meeting-shaped, not a general project-management system.

## Product Boundary

In scope:

- Organization-owned tracked items with a title, short summary, rich context, importance,
  optional raise-by date, optional usual meeting body, and active/completed lifecycle.
- An append-only stream of dated officer updates.
- A read-only view for every signed-in member and editing for users with
  `manage_agendas`.
- Plain-language prioritization of active business into Necessity, Focus, Delegate, and
  Keep tracking groups.
- Adding a tracked item to a chosen section of a draft dated agenda.
- Snapshotting tracked-item wording into the agenda so later tracker edits do not rewrite
  an approved or published agenda.
- Showing agenda appearances beside manual updates as one continuity record.

Out of scope:

- Assignments, subtasks, percentage complete, dependencies, or other broad project
  management.
- Comments, notifications, file attachments, and committee-specific permissions.
- Automatic AI creation, merging, or splitting. Any later AI suggestions require human
  confirmation.
- Editing or deleting a historical update. A correction is another dated update.
- Changing the agenda presentation or the remaining disabled navigation destinations;
  those are the next roadmap milestone.

## Domain Model

### TrackedItem

`TrackedItem` belongs to an organization, optionally belongs to the meeting body that
usually handles it, and records the user who created it. It stores:

- `title` — recognizable business wording.
- `summary` — a short explanation or next step used in lists and copied to agendas.
- `details` — Action Text context for the durable item page.
- `importance` — `standard` or `important`.
- `raise_by_on` — an optional date by which the item should return for attention.
- `status` — `active` or `completed`.
- completion provenance and optimistic `lock_version`.

Tracked items are not deleted. Managers mark them complete and may reopen them. The
optional meeting body improves suggestions without preventing the same post business from
appearing before another body.

### TrackedItemUpdate

`TrackedItemUpdate` belongs to a tracked item and an author and contains an Action Text
body. Updates are append-only. Model callbacks reject later edits or deletion so the
continuity record is honest without claiming the legal finality of accepted minutes.

### Agenda link and snapshot

`DatedAgendaItem` gains an optional `tracked_item` reference. A tracked item can appear at
most once on a dated agenda. Adding it copies the current title, summary, and details into
the dated agenda item with `business_item` behavior. The copied agenda item remains fully
independent and obeys the agenda's existing draft/approved/published lock rules.

Agenda appearances are derived from these links and displayed on the tracked item's
continuity spine. Removing an item from a draft removes that planned appearance; locked
agenda items cannot be removed.

## Prioritization

The existing visual-system decision is implemented directly rather than exposing a matrix.
An item is urgent when its raise-by date is within 30 days (including overdue dates).

| Importance | Urgency | Officer-facing group |
| --- | --- | --- |
| Important | Urgent | Important and urgent — Necessity |
| Important | Not urgent | Important, not urgent — Focus |
| Standard | Urgent | Time-sensitive — Delegate or handle |
| Standard | Not urgent | Keep tracking |

Items without a raise-by date are not urgent. The UI explains the reason with the actual
date and importance rather than showing abstract quadrant labels. Within each group,
raise-by date comes first and undated items follow alphabetically.

## Workflows

### Review and manage tracked business

Every signed-in user can open Tracked Items from the primary navigation and read active or
completed items. A user with `manage_agendas` can create and edit an item, add an update,
mark it complete, or reopen it. Forms use plain wording and explain how importance and the
raise-by date affect meeting suggestions.

### Bring business to an agenda

Each draft agenda section offers **Add tracked business** beside **Add catalog item**. The
picker keeps the chosen destination visible, groups active items by the four priority
labels, favors items associated with the agenda's meeting body, and marks items already on
that agenda. Adding creates the independent agenda snapshot and returns to the agenda
editor. Approved and published agendas reject the operation.

## Frontend Design Direction

This design follows the installed `frontend-design` skill and the established “1919”
system. The concrete subject is an officer carrying unfinished post business across
meetings; the interface's job is continuity, not productivity theater.

### Tokens and type

- Authority navy `#0A2240`
- Working navy `#0D2C54`
- Legion gold `#C6A15B`
- Paper cream `#F4EEDD`
- Ink `#1B222B`
- Completed green `#3F6B3F`

Working screens retain the legible system sans stack. Tracked items are working records,
so serif remains reserved for published agendas and official documents. Body and controls
remain at least 16px, secondary text at least 14px, and labels at least 13px.

### Layout

The index is a bounded business docket, not a card dashboard:

```text
+--------------------------------------------------------------+
| Tracked Items                           [Track new business]  |
| Business that needs to survive the next meeting and officer  |
+--------------------------------------------------------------+
| IMPORTANT AND URGENT — NECESSITY                             |
| ◆ Car Show permits       Raise by 15 SEP     Membership  >   |
| ◆ Roof repair bids       Overdue              PEC         >   |
+--------------------------------------------------------------+
| IMPORTANT, NOT URGENT — FOCUS                                |
| ...                                                          |
+--------------------------------------------------------------+
```

The item page uses one main record column and a restrained facts rail:

```text
+------------------------------------------+-------------------+
| Title and durable context                | Status / priority |
|                                          | Meeting body      |
| CONTINUITY                               | Raise-by date     |
| ◆ 22 AUG  Officer update                 | [Edit] [Complete] |
| │                                        |                   |
| ◆ 05 AUG  Added to Membership agenda     |                   |
+------------------------------------------+-------------------+
```

### Signature and critique

The signature element is the gold **continuity spine** joining officer updates and agenda
appearances. It is structural: it shows the history that the feature exists to preserve.
No stat tiles, progress rings, gratuitous animation, or generic kanban treatment are used.
The initial idea of giving every priority group a heavily decorated panel was rejected as
too dashboard-like; quiet rules and strong headings keep the spine as the one visual risk.

Hover and focus states are visible, reduced-motion preferences are respected, and the
two-column detail layout collapses to one column without shrinking meaningful text.

## Authorization and Safety

- Reading requires authentication.
- Creation, editing, lifecycle changes, updates, and agenda insertion require
  `manage_agendas`.
- Every record is resolved through the current installation's organization.
- The optional meeting body and any linked agenda must belong to that organization.
- Cross-organization and duplicate agenda links are rejected at model and database levels.
- Optimistic locking protects concurrent item edits; lifecycle methods use row locks.
- Update immutability is enforced in the model, not only by omitting UI controls.

## Verification

Coverage should establish:

- tracked-item validation, priority grouping, ordering, lifecycle, and organization scope;
- append-only update behavior;
- read access versus `manage_agendas` mutation access;
- cross-organization meeting bodies and agenda links are rejected;
- agenda insertion snapshots content, prevents duplicates, and respects agenda locking;
- later tracker edits do not change the agenda snapshot;
- active navigation and plain empty/error states;
- desktop and narrow-width browser flows for index, creation, detail/history, and adding a
  tracked item to an agenda;
- the full Rails test, RuboCop, Brakeman, and Bundler Audit checks.
