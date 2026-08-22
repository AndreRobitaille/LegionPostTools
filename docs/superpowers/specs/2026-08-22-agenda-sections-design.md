# Agenda Sections Design

## Purpose

The structured-agendas foundation currently has reusable catalog items, meeting-type
templates, and dated agendas, but each template and agenda is still one flat list.
American Legion meetings have recognizable parts—opening, administration, reports,
business, and closing—and those parts should remain visible as the meeting record moves
from a reusable template to a specific meeting.

This slice adds first-class agenda sections without beginning tracked items or minutes.
It also finishes the visual treatment at the point where officers actually assemble a
meeting agenda.

## Product Boundary

In scope:

- Ordered, titled sections on meeting-type templates.
- Independent copied sections on dated agendas.
- Adding, renaming, reordering, and removing empty sections.
- Adding catalog items to a chosen section.
- Reordering items within a section and moving an item to another section through its
  edit form.
- Section-aware officer, member, and print views.
- Structured default sections for newly seeded PEC and Membership Meeting templates.
- A safe migration of every existing flat template and dated agenda into one
  "Order of Business" section without changing item order.

Out of scope:

- Dragging an item directly between sections. Moving through the item edit form is more
  explicit and accessible for the first version.
- Tracked items, old-business suggestions, minutes, PDF generation, and distribution.
- Automatically regrouping an installation's existing agenda items based on guessed
  semantics. Officers remain the authority over local structure.
- One-off agenda items that are not copied from the catalog.

## Domain Model

Add two snapshot-level records rather than storing a section title on each item:

- `MeetingTypeAgendaSection` belongs to a meeting type and stores `title` and
  `position`.
- `DatedAgendaSection` belongs to a dated agenda, optionally references its source
  meeting-type section, and stores its own `title`, `position`, and `lock_version`.

Each existing agenda-item record belongs to the section at its own level. Item position
is unique within a section, not across the whole template or agenda.

This preserves the existing copy boundary:

```text
meeting-type section + items  ->  dated-agenda section + copied items
```

Later edits to a meeting-type section never rename, move, add, or remove sections on an
already-created dated agenda. Dated-agenda section changes never alter the template.

Sections are structural records, not catalog records. The agenda-item catalog remains a
post-wide library of reusable items; section names and arrangements belong to a meeting
template or a particular dated agenda.

## Defaults and Migration

Every new custom meeting type starts with one section named **Order of Business**. Every
directly-created dated agenda gets the same safe default.

The supplied meeting templates use restrained, meeting-shaped defaults:

- PEC Meeting: **Call to Order** and **Post Business**.
- Membership Meeting: **Opening Ceremony**, **Administration & Membership**,
  **Reports & Member Welfare**, **Post Business**, and **Closing Ceremony**.

The data migration creates one **Order of Business** section for every existing meeting
type and dated agenda and attaches its current items in their existing order. It does
not guess at local intent. An officer can rename that section and split the agenda later,
or explicitly reset a supplied template to adopt the new suggested structure.

## Editing Workflow

### Meeting-type template

The meeting-type editor presents the agenda as a vertical stack of section chapters.
Each section has:

- a numbered navy-and-ivory heading with the project's gold diamond/rule language;
- a visible item count;
- a section drag handle and automatic reorder status;
- **Rename** and, when safe, **Remove** actions;
- its own **Add catalog item** action;
- a contained item list with the existing item drag handles and edit/remove actions.

An empty section shows a deliberate, dashed empty state with one clear action. A section
cannot be removed while it contains items, and the last section cannot be removed.

### Dated agenda

The dated-agenda editor uses the same section-chapter vocabulary beneath its lifecycle
and meeting-details controls. In draft state, officers can manage sections and items.
Approved and published agendas render the same hierarchy without editing controls and
retain the existing reopen-to-edit rule.

Adding a catalog item is always launched from a section, and the picker clearly names
the destination. Editing an item includes a plain **Agenda section** select. Moving the
item through that select appends it to the chosen section, where it can then be reordered.

## Member and Print Presentation

Published agenda views render a formal agenda outline:

- section headings use the gold diamond, uppercase label, and graduated rule from "The
  1919" visual system;
- sections are numbered for orientation, while agenda items remain clean titled blocks;
- generous spacing and the 16px minimum body-text rule are maintained;
- print keeps section headings with the content that follows where practical and avoids
  breaking individual items across pages.

The working editor remains sans serif. The member/print artifact uses the existing
document treatment and does not introduce a competing visual language.

## Ordering and Concurrency

The existing Stimulus reorder behavior is reused for both section stacks and item lists.
It gains two small generalizations: a configurable handle selector and direct-child row
collection, allowing nested reorder lists without an outer section sort accidentally
collecting inner agenda items.

Section and item reorder operations require the complete ID set for their scoped parent
and use the existing two-phase, unique-index-safe `Reorderable` concern.

Dated-agenda section creation, editing, removal, and reorder are rejected when the agenda
is approved or published. Dated sections carry optimistic locking for normal edits.

## Authorization and Safety

All section management reuses `manage_agendas`. Records are resolved through the current
installation's organization and their nested meeting type or dated agenda. Model
validations prevent a section or item from crossing those parent boundaries.

Removing a section is allowed only when it is empty and another section remains. Removing
or renaming a section on an approved or published dated agenda is blocked at both the
controller and model boundary.

## Verification

Coverage should establish:

- existing flat data migrates into one section without item loss or reordering;
- new meeting types receive a default section;
- supplied templates seed the intended section structure;
- dated-agenda creation copies section titles, order, and section/item membership;
- copied sections remain independent of later template edits;
- cross-parent section assignments are rejected;
- section and per-section item reorder persist safely;
- locked dated agendas reject every section mutation;
- admin, member, and print views render the section hierarchy;
- browser QA covers template and dated-agenda editing at desktop and narrow widths,
  plus the published member presentation.
