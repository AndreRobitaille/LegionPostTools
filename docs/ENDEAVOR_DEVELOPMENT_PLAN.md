# Endeavor Development Plan

## Status and purpose

The Endeavor MVP is the durable continuity layer for coherent American Legion Post work.
The behavior-preserving rename from Tracked Item to Endeavor establishes the final domain
name and `endeavor_id` seam. The first-class Meeting foundation and member archive are now
complete, as is structured draft-minutes seeding and human-reviewed AI assistance. The next
core product work is the official Minutes lifecycle, not expansion into project management.

`docs/ENDEAVOR_GOVERNANCE.md` remains authoritative for identity and ownership rules. This
plan records implementation order, integration contracts, validation cases, and deferred
feature work.

## Completed foundation

The MVP provides:

- organization-owned Endeavors with durable IDs;
- active/completed lifecycle with creator, completion, and reopening provenance;
- standard/important priority, raise-by date, and optional usual Meeting Body;
- append-only `EndeavorUpdate` history;
- optimistic locking and same-organization validation;
- authenticated read access and `manage_agendas` mutation authority;
- independent agenda snapshots of title, summary, and rich details;
- one linked Endeavor appearance per dated agenda while allowing standalone agenda items;
  and
- HTML, private API, generated-handbook, and test coverage under one Endeavor domain with
  no parallel Tracked Item model.

The rename must be reviewed and landed as its own coherent change before Meeting or
Minutes implementation begins so the new work starts from a clean schema and review
boundary.

## Implemented draft integration and remaining official lifecycle

Minutes are official meeting records; Endeavors are continuity records. Neither owns or
replaces the other. The implemented draft integration and remaining official lifecycle
preserve the following contract.

### First-class Meeting occurrence

- `Meeting` is the organization-owned occurrence that carries Meeting Body, optional
  Meeting Type, date/time, title, and a snapshotted venue name/address. Agenda, transcript,
  minutes, attendance, decisions, and Endeavor appearances relate through that occurrence.
- A Meeting may exist without an agenda. After existing agendas are backfilled, every
  `DatedAgenda` belongs to exactly one Meeting and the relationship is one-to-one.
- Saving a Meeting makes it visible to signed-in members. This private Post application
  does not add a second publish state for the occurrence merely because its agenda and
  minutes have their own publication/authority lifecycles.
- A Meeting's current schedule is not a substitute for a historical document snapshot.
  Creating an agenda copies the Meeting heading and venue into the agenda. An approved or
  published agenda is not silently rewritten when Meeting details change.
- Date/time entry and display use the installation's configured local time zone while the
  database stores UTC. Date-based upcoming/archive boundaries use that same local zone.
- Meeting Body and organization locations are editable form defaults, not historical
  references. Save the submitted venue on the Meeting. Do not add a Places model, events,
  recurrence, or a calendar in this milestone.
- `manage_agendas` controls Meeting creation and management. All signed-in members may read
  saved Meetings. Meeting deletion is permitted only while no agenda, minutes, or other
  dependent historical record exists.

The completed Meeting creator and member archive are described in
`docs/MEETING_FOUNDATION_AND_MEMBER_ARCHIVE.md`. Structured draft minutes now implement
the source and direct-identity boundary. The governing design for the remaining lifecycle
is `docs/MINUTES_LIFECYCLE.md`; follow its revision, confirmation, acceptance, and
immutability boundaries before making drafts official.

### Direct identity and source lineage

- A structured `MinutesItem` may have one optional direct `endeavor_id` when the item
  concerns that coherent body of work.
- When a draft minutes item is seeded from a linked `DatedAgendaItem`, deliberately copy
  the agenda item's `endeavor_id` and retain an optional source `dated_agenda_item_id`.
- Copy title, wording, section, behavior intent, and other minutes seed content as an
  independent snapshot. Later agenda or Endeavor edits must not rewrite the minutes.
- Agenda or minutes items without an Endeavor remain first-class. New business heard at a
  meeting does not automatically justify creating an Endeavor.
- Do not infer identity from titles, transcript similarity, catalog entries, behavior
  types, Four Pillars, or the meeting body. AI may suggest a link; a human confirms it.
- A human may correct an Endeavor link while minutes remain editable. Once accepted, the
  link is part of the immutable official record and corrections require an amendment or
  later meeting record.

### Cardinality and organization boundaries

- The agenda MVP's one-appearance-per-Endeavor rule does not automatically apply to
  minutes. The same Endeavor may require more than one minutes item when the meeting record
  has distinct reports, motions, or decisions.
- Each minutes, agenda, Meeting, and Endeavor relationship must remain within one
  Organization.
- A Meeting has at most one agenda and at most one minutes record. Multiple structured
  sections/items live inside those documents; they are not multiple competing documents.
- The Meeting Body is the meeting's governing/stewarding context. It does not own the
  Endeavor and does not change Endeavor identity.

### Continuity behavior

- Draft minutes are working material and must not appear to ordinary members as settled
  Endeavor history.
- An attested minutes appearance may appear in authorized continuity views clearly labeled
  as awaiting acceptance. Accepted minutes and linked amendments are the authoritative
  meeting history.
- Meeting appearances may enrich the Endeavor timeline, but they do not silently create an
  `EndeavorUpdate`.
- A recorded decision, motion, or transcript statement does not automatically complete,
  reopen, merge, split, rename, reprioritize, or reassign an Endeavor. Those remain
  deliberate human actions with their own provenance.
- Officer-written `EndeavorUpdate` entries remain useful operational context, but they are
  never substitutes for official minutes.

### Transcript and AI boundary

- A transcript belongs to the Meeting/Minutes drafting workflow as restricted source
  material; it is not an Endeavor attachment and must not turn Endeavor into a document
  archive.
- AI may organize transcript material under agenda/minutes items, summarize discussion,
  and suggest possible existing Endeavors. It must surface uncertainty and must not invent
  identity, attendance, motions, seconds, votes, decisions, approval, attestation, or
  acceptance.
- No AI-generated Endeavor creation, merge, split, completion, or minutes link becomes
  effective without explicit human confirmation.

## First end-to-end validation case

Use the already-held meeting with a good structured agenda and available transcript as the
first proof of the integration. The workflow should demonstrate that an officer can:

1. create or backfill the first-class historical Meeting with the correct local date,
   time, Meeting Body, and snapshotted venue;
2. attach the existing dated agenda to that Meeting without rewriting the agenda;
3. confirm that the Meeting appears in the member archive with its published agenda and
   that an upcoming Meeting without an agenda is labeled honestly;
4. paste the transcript as private source material;
5. seed structured draft minutes from the agenda, including direct Endeavor links and
   source lineage;
6. review transcript-assisted wording, add unplanned business, record actual attendance,
   motions, decisions, and known outcomes without fabricated details;
7. verify that agenda wording, minutes wording, transcript source, and Endeavor continuity
   remain distinct records;
8. complete human approval and attestation with fresh intent; and
9. record acceptance only from a real later same-body meeting, or leave the minutes clearly
   awaiting acceptance when that evidence is not yet present.

The test must include at least one standalone minutes item and, when the source agenda has
one, at least one linked Endeavor. It must prove that editing the Endeavor later does not
change either historical document and that minutes drafting does not create operational
updates automatically.

## Deferred Endeavor work

The following do not block Meeting or Minutes development:

- human-confirmed merge and split workflows;
- expanded kinds or lifecycle statuses;
- Four Pillar persistence, classification, and reporting;
- events, activities, recurrence, calendars, and volunteer scheduling;
- assignments, tasks, dependencies, budgets, and project boards;
- general attachments, document archives, and evidence search;
- dashboards, reminders, analytics, notifications, and automation;
- public Endeavor pages or public APIs; and
- automatic AI creation, linking, classification, merge, split, or completion.

Revisit one of these only when a real Post workflow requires it and after the official
Meeting/Minutes lifecycle is stable.

## Exit criteria before expanding Endeavors

The Endeavor/Minutes boundary is complete enough to move on when:

- the atomic Endeavor rename is reviewed, migrated, and deployed separately;
- existing Endeavor and Action Text data is preserved;
- the local-time Meeting creator and historical backfill preserve existing agenda data;
- the member archive shows upcoming and past Meetings independently of agenda publication;
- a Meeting can own both its historical agenda and its structured minutes without either
  document becoming the Meeting itself;
- minutes seeding copies direct identity and source lineage deliberately;
- standalone minutes items remain supported;
- draft, attested, accepted, and amended appearances are labeled accurately in continuity;
- accepted minutes and their Endeavor links are immutable;
- no transcript or AI action silently changes Endeavor identity or lifecycle; and
- the first historical meeting/transcript workflow passes model, controller, system,
  browser, migration, authorization, and official-record immutability checks.
