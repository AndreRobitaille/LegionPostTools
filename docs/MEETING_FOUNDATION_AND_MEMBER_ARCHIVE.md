# Meeting Foundation and Member Archive

## Purpose

LegionPostTools currently treats a dated agenda as the closest thing to a meeting. That
works while officers are preparing the next agenda, but it cannot represent a scheduled or
historical Meeting with no published agenda, and the member Meetings page has no archive.
It lists only future published agendas even though past published agenda URLs remain valid.

This milestone makes the actual American Legion Post meeting the durable occurrence. An
agenda is one document prepared for that Meeting. Minutes will later be another document
produced from it. Neither document is the Meeting itself.

The immediate outcome is deliberately concrete:

- officers can create and manage a Meeting with a date, time, and place;
- an existing or new agenda belongs to that Meeting;
- signed-in members can see upcoming and past Meetings whether or not an agenda has been
  published; and
- the page can later promote signed and accepted minutes without discarding the agenda
  that preceded them.

## Product Boundary

In scope:

- a first-class `Meeting` occurrence;
- installation-local time entry and display with UTC persistence;
- snapshotted Meeting and agenda venue details;
- safe one-to-one backfill of existing dated agendas;
- an officer Meeting creator and Meeting workspace;
- member Meeting index and detail pages;
- honest agenda availability states;
- private Meeting API and generated-handbook parity; and
- an explicit presentation contract for later attested and accepted minutes.

Out of scope:

- a reusable Places or venue-management subsystem;
- recurring meetings, calendar synchronization, events, or cancellations;
- transcripts, minutes tables, AI drafting, approval, attestation, or acceptance behavior;
- anonymous/public Meeting pages;
- email notifications or distribution; and
- a general document archive.

Minutes remain the next core milestone. This design establishes their parent and member
presentation boundary but does not implement them early.

## Core Domain Model

### Meeting

Add an organization-owned `Meeting` with:

- required `organization`;
- required `meeting_body`;
- optional `meeting_type` until an agenda is created;
- required `starts_at`, stored in UTC;
- required display `title`, defaulted from Meeting Type or Meeting Body plus local date;
- required `location_name` and optional `location_address`, stored as historical snapshot
  values; and
- normal Rails optimistic locking.

A Meeting is the occurrence. Its future relationships are:

```text
Meeting
|-- zero or one DatedAgenda
`-- zero or one Minutes
```

The structured sections and items belong inside each document. Do not create multiple
competing agenda or minutes records for one Meeting.

Every saved Meeting is readable by signed-in members. This is a private Post application,
and the required “Agenda not published yet” state only works if the occurrence is visible
before its agenda. Do not add a second draft/published lifecycle for Meeting itself.

### Meeting place

Do not add `Place` in this milestone. When the officer opens the Meeting form:

1. prefill the Meeting Body's effective location;
2. allow the officer to edit the name and address; and
3. save the submitted values directly on the Meeting.

The Meeting Body and organization values are defaults, not live historical references.
Changing a default venue later must not rewrite an earlier Meeting.

Requiring a human-readable `location_name` keeps the creator plain and makes “Online” or
another non-address place possible. A postal address remains optional.

### Dated agenda relationship and snapshots

Add a unique `DatedAgenda#meeting_id`. It may be nullable only during the data migration;
after backfill it is required. A Meeting may exist without an agenda, but an agenda may
not exist without its Meeting.

Keep the dated agenda's current title, `starts_at`, Meeting Body, and Meeting Type as
document snapshot fields. Add `location_name` and `location_address` agenda snapshot
fields and render those values instead of consulting today's Meeting Body defaults.
This duplication is deliberate:

- `Meeting` describes the occurrence as currently scheduled or historically recorded;
- `DatedAgenda` preserves what its own approved/published document says; and
- future `Minutes` preserves its separately reviewed and attested wording.

Creating an agenda copies the Meeting heading and venue. While the agenda remains draft,
editing the Meeting's date, title, or place updates those draft agenda snapshot values in
the same transaction. Once the agenda is approved or published, those Meeting fields are
locked until the agenda is explicitly reopened. There is no silent rewrite of a published
document.

Meeting Body and Meeting Type become fixed once an agenda exists because changing either
would change the document's governing context or template. An officer who chose the wrong
one must remove the still-draft agenda before correcting the Meeting; locked agenda
deletion retains its existing protected confirmation boundary.

When accepted minutes exist later, the Meeting's historically significant fields become
immutable with the official record. Corrections then belong in an amendment or later
Meeting record, not a metadata edit.

## Time Zone Contract

Configure one installation time zone through `APP_TIME_ZONE`, with Rails' UTC default as
the safe fallback. The Post 165 deployment supplies its Central time zone as installation
configuration; application behavior must not hard-code Wisconsin.

- Forms parse date and time in `Time.zone`.
- Database timestamps remain UTC.
- All member/admin rendering uses `Time.zone`.
- “Upcoming,” “today,” and archive year grouping use the same local zone.
- A Meeting on the local evening before a UTC date boundary stays on the intended local
  date.

The member page treats every Meeting on the current local calendar date as upcoming. It
moves into the past record at the next local midnight rather than becoming “past” as soon
as its start time arrives.

Verification must include a Central-time evening and a daylight-saving boundary while
remaining valid when another installation chooses another zone.

## Data Migration

Backfill without rewriting or recreating existing agendas:

1. add `meetings` and nullable `dated_agendas.meeting_id`;
2. create exactly one Meeting for every existing dated agenda, preserving organization,
   Meeting Body, Meeting Type, title, and start timestamp;
3. snapshot each current effective venue onto both the Meeting and dated agenda;
4. attach the agenda to its new Meeting;
5. add the unique index and non-null constraint; and
6. verify one Meeting per pre-existing agenda with matching IDs, statuses, actors,
   timestamps, sections, items, rich text, and lock versions left untouched.

The migration must be reversible in structure without pretending that later Meeting data
can be safely collapsed back into an agenda-only domain after production use. Tests should
exercise both an empty database and populated historical agendas.

Existing member agenda and PDF URLs remain valid. Only the list/workspace entry points
move to Meeting routes.

## Officer Workflow

Use `manage_agendas` for this milestone. Do not create a nearly identical Meeting
permission before real use shows a separate authority boundary.

### Administration index

Replace the **Dated Agendas** administration destination with **Meetings**. The index lists
upcoming Meetings first and past Meetings in reverse chronological order. Each row keeps
its document state and action together:

- No agenda — **Prepare agenda**
- Draft agenda — **Continue agenda**
- Approved agenda — **Open agenda**
- Published agenda — **Open published agenda**

The old dated-agenda index may redirect to the Meeting index. Existing agenda edit routes
remain valid because officers may have bookmarked them.

### New Meeting

Use one large, guided form:

1. Meeting Body;
2. Meeting Type (optional, explained as the agenda template);
3. date and start time;
4. place name and address, prefilled from the Meeting Body; and
5. optional title override.

The primary action says **Create meeting**. Creation does not also create an agenda. The
officer lands on the Meeting workspace, which plainly says **No agenda yet** and offers
**Prepare agenda**. If no Meeting Type was chosen, that action first asks for the template.

### Meeting workspace

The workspace has two quiet sections:

- **Meeting details** — date, time, place, body, and type; and
- **Meeting documents** — the agenda now, and minutes later.

This is the stable place to return for the occurrence. Agenda editing remains in the
existing structured agenda builder rather than being embedded into an oversized Meeting
form.

An empty Meeting can be deleted through the shared confirmation dialog. Once an agenda,
minutes, or another historical dependent exists, deletion is blocked. Officers remove an
eligible child record through that record's own explicit workflow; no cascade silently
erases Meeting history.

## Member Information Architecture

Add member `MeetingsController#index` and `#show`. Navigation points to `/meetings`.
Published agenda documents retain `/dated_agendas/:id` and their PDF routes.

### Index

The index has three structural regions:

1. **Next meeting** — the earliest Meeting on or after the current local date, presented
   prominently with date, time, place, and best available document state.
2. **Also coming up** — compact rows only when additional future Meetings exist.
3. **Past meetings** — reverse chronological, grouped by local calendar year.

Every Meeting row links to the Meeting detail page even when no document is available.
Empty copy must describe the occurrence, not merely the agenda database:

- “No meetings are scheduled.”
- “No past meetings have been recorded.”

### Detail and document progression

The Meeting detail page always shows the date, time, place, and Meeting Body. It then
shows only member-visible documents:

| Available record | Primary presentation | Secondary presentation |
| --- | --- | --- |
| No published agenda | Agenda not published yet | None |
| Published agenda, upcoming | Read the agenda | None |
| Published agenda, past | Read the agenda | Minutes not published yet |
| Attested minutes | Read signed minutes; Awaiting acceptance | View agenda |
| Accepted minutes | Read official minutes; Accepted by motion | View agenda |

Draft or merely approved agendas remain officer-only. Future draft or Commander-approved
minutes also remain officer-only. Adjutant attestation is the signature-equivalent point
that makes minutes member-visible, but it is not acceptance. The page must say **Awaiting
acceptance** until a real later same-body Meeting records the acceptance motion.

When minutes become primary, the agenda remains available as quieter historical evidence.
It is never deleted or hidden merely because a later record exists.

## Visual Direction: The 1919 Meeting Record

Subject: a signed-in American Legion member checking the next assembly and finding the
Post's prior Meeting record. The page's single job is to make the next Meeting unmistakable
without burying the historical record.

Use only the established system:

- Navy `#0A2240` for authority and primary links;
- Gold `#C6A15B` for rules and the one signature accent;
- Cream `#F4EEDD` for the app field;
- Paper `#FBF7EC` for bounded Meeting surfaces;
- Ink `#1B222B` and muted `#6B7684` for readable text;
- system sans for the working page; and
- serif only inside actual agenda/minutes documents, not as archive decoration.

The signature element is a formal **Next assembly** notice composed from the existing date
plate, section header, and bounded paper surface. A restrained gold year rail gives the
past record true chronological structure. This is not a generic dashboard-card grid, an
office ledger, or a newspaper layout.

```text
MEETINGS

◆ NEXT ASSEMBLY --------------------------------------
+----------+  Membership Meeting
|  01 SEP  |  19:00 · Post Hall
|   2026   |  Agenda not published yet
+----------+

◆ ALSO COMING UP ------------------------------------
[ date ]  PEC Meeting               [Read agenda ->]

◆ PAST MEETINGS -------------------------------------
2026 | [ date ] Membership Meeting   [Official minutes ->]
     |          View agenda
     | [ date ] PEC Meeting          [Read agenda ->]
```

At 390px, the next notice and every archive row stack date above copy/actions without
horizontal overflow. The year rail becomes an inline year heading. Links retain visible
focus, state never relies on color alone, no meaningful text drops below the design
system's 13px floor, and primary interactive text remains at least 16px.

The distinctiveness review rejected a “meeting ledger” treatment because it could belong
to any records application and conflicts with The 1919's no-office-supply rule. The formal
assembly notice and year rail instead encode facts specific to Post meetings: what comes
next and when the Post's record occurred.

## Private API and Agent Handbook

The private API must preserve the same first-class boundary:

- list and show Meetings in upcoming-then-past order;
- create and update Meeting details with `manage_agendas`;
- delete only an empty Meeting;
- create a dated agenda from an exact `meeting_id`; and
- return Meeting document state without exposing draft documents to read-only member
  callers.

Update the generated handbook and examples atomically. Do not leave an agent-only path
that creates a free-standing dated agenda. Bearer-authenticated mutations keep existing
idempotency and execution provenance behavior.

## Future Minutes Contract

Slice 2 will add one structured Minutes record per Meeting. Its detailed design must be
completed before implementation, but this archive depends on these settled states:

```text
draft -> approved -> attested -> accepted
```

- Draft/review material is officer-only.
- Commander approval is not member publication.
- Adjutant attestation records signer and time and makes the minutes member-visible as
  awaiting acceptance.
- Acceptance belongs to a later same-body Meeting and makes the record official and
  immutable.
- Amendments are later linked records; they never overwrite accepted minutes.
- Transcript source remains restricted and never appears in member or print output.
- Agenda, minutes, transcript, and Endeavor continuity remain separate records connected
  through Meeting and explicit lineage.

## Verification

Before this milestone is complete, verify:

- Meeting validation, organization scoping, one-to-one agenda cardinality, and deletion
  restrictions;
- local time parsing/rendering, local-day scopes, evening UTC rollover, and a DST boundary;
- migration of populated existing agendas without changes to document content or lifecycle
  provenance;
- creation with default and overridden places;
- Meeting edits syncing only a draft agenda and locked document behavior after approval;
- member visibility with no agenda, draft/approved agenda, and published agenda;
- upcoming, additional-upcoming, past, and empty index states;
- direct access protection for unpublished agenda documents;
- admin HTML and private API authorization/idempotency;
- generated-handbook accuracy;
- desktop and 390px browser review, keyboard focus, responsive stacking, and no horizontal
  overflow; and
- the full relevant Rails test suite, RuboCop, Brakeman, and Bundler Audit.

## Implementation Sequence

1. Land and verify the in-progress Tracked Item to Endeavor rename as its own change.
2. Add installation time-zone configuration and regression tests.
3. Add Meeting, agenda snapshot fields, and the safe backfill migration.
4. Move agenda creation behind Meeting while preserving existing document URLs.
5. Build the administration index, creator, and Meeting workspace.
6. Build the member index/detail archive using agenda states only.
7. Update the private API and generated handbook.
8. Complete controller/system/browser/security verification.
9. Write the detailed structured Minutes Lifecycle design before beginning Slice 2.
