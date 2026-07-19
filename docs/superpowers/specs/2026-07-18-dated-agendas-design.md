# Dated Agendas Design

## Purpose

LegionPostTools needs the next meeting-workflow object between reusable meeting type templates and official minutes. The next slice is **dated agendas**: an officer creates an agenda for an actual meeting date from an existing meeting type template, edits it for that specific meeting, approves it when ready, and publishes it for members to view or print.

This keeps the product centered on American Legion meeting records without jumping prematurely into the minutes lifecycle.

## Product Boundary

In scope:

- Create a dated agenda from a meeting body and meeting type.
- Copy the meeting type's template agenda items into the dated agenda at creation time.
- Let authorized officers edit the copied agenda items immediately.
- Support a simple lifecycle: draft, approved, published.
- Lock approved or published agendas by default, with an intuitive reopen-for-editing action.
- Provide an officer management view.
- Provide a member-facing read-only published agenda view.
- Provide browser/HTML printable agenda rendering.
- Use basic optimistic locking to avoid silent overwrite conflicts.

Out of scope:

- Minutes drafting.
- Accepted or official minutes immutability.
- Amendments.
- App-generated PDF files.
- Email distribution.
- Real-time collaborative editing.
- Detailed audit logging unless it falls naturally out of existing patterns.

## Core Model

Add a first-class dated agenda record. It should belong to:

- organization
- meeting body
- meeting type

It should store:

- scheduled date/time
- display title, defaulted from meeting type and date
- lifecycle status
- approval and publication timestamps
- approval and publication actor references when the current-user model is available to the controller action

It should have copied agenda items that store their own meeting-specific content:

- position/order
- title
- rich text/body content
- behavior type
- optional references back to source meeting type item and catalog entry

The dated agenda is independent after creation. Editing `/admin/meeting_types` later must not silently change an agenda that already exists for a real meeting date. Editing a dated agenda must not change the meeting type template.

## Creation Flow

Use a single combined setup form rather than separate steps. The officer chooses:

- meeting body
- meeting type
- scheduled date/time
- optional title override

The UI should guide low-confidence users with plain labels and defaults. If there is a sensible default meeting type for the selected body, the form may suggest it, but it should not require users to understand internal template structure.

On create, the app copies the active ordered template agenda items into the dated agenda. If the template has no items, the agenda can still be created, but the UI should explain that the agenda starts empty.

## Editing Flow

Commander and adjutant-style users should be able to edit the dated agenda immediately after creation. The first version should support straightforward management of copied items:

- edit item title/body/behavior fields that are already editable in the template context
- reorder items
- remove meeting-specific items
- add items from the agenda catalog using the same copy-into-place pattern already used by meeting type templates

The key user promise is that the dated agenda is the working agenda for that specific meeting, not a hidden template setting.

## Lifecycle

Use a simple lifecycle:

1. **Draft** — agenda is being prepared and is editable by authorized officers.
2. **Approved** — commander or similarly authorized officer marks the agenda ready for the meeting.
3. **Published** — the approved agenda is visible to members and available for printing.

Approved and published agendas are locked by default. Editing them requires a clear **Reopen for editing** action. Reopening moves the agenda back to draft. For this first slice, reopening should use a confirmation rather than a required reason, so the workflow remains approachable.

This approval is operational readiness for the meeting. It is not the same as official minutes acceptance and should not carry the immutability rules that will apply to accepted minutes later.

## Member Visibility and Printing

Members should have a simple read-only view of published agendas. Draft and approved-but-unpublished agendas should remain officer-facing.

The first output should be browser/HTML printable rendering, not generated PDF files. Users can use browser print or print-to-PDF. App-generated PDFs can wait until finalized records and distribution workflows justify the added complexity.

The printable view should use the same agenda content as the officer/member views, with navigation and editing controls removed.

## Conflict Handling

Use normal Rails optimistic locking on dated agendas and agenda items where edits may conflict. If two officers edit the same agenda item, the later save should fail safely with a plain message such as:

> This agenda item was changed by someone else. Review the latest version before saving.

Do not build real-time collaborative editing in this slice.

## Authorization

Reuse the existing permission direction around agenda management. Officers with agenda-management authority should be able to create, edit, approve, publish, and reopen dated agendas. Members should only see published agendas through the member-facing view.

The exact permission names should follow existing Rails/domain conventions during implementation rather than introducing a broad new permission system.

## Future Minutes Boundary

Later, after a meeting is complete, the dated agenda can become the source for minutes. That later workflow should branch from the agenda into minutes drafting/review/approval/attestation/acceptance.

Accepted official minutes remain immutable. Corrections belong in later amendments or later meeting records, not silent edits to accepted minutes. Those stricter official-record controls are intentionally deferred from this dated-agenda slice.

## Testing and Verification Expectations

Implementation should include tests for:

- creating a dated agenda from a meeting type copies template items
- copied items are independent from later template edits
- editing copied agenda items does not edit the template
- lifecycle transitions draft, approved, published, and reopened draft
- approved/published agendas are locked from ordinary edits
- published agendas are visible to members while drafts are not
- printable view renders without edit controls
- optimistic locking prevents silent overwrite conflicts for dated agenda and dated agenda item edit forms

Browser-visible flows should get a smoke test when practical because intuitive UI/UX is a core requirement for this feature.
