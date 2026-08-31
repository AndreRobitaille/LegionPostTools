# Endeavor Governance

## Purpose

An **Endeavor** is the durable record of a coherent body of work undertaken by an
American Legion post. It preserves identity and history while officers, meeting bodies,
wording, phases, and individual activities change.

For Robert E. Burns Post 165, that may mean the continuing record for a car show, Buddy
Checks effort, building repair, election, ceremony, or other work that a future officer
must be able to understand and continue. The application must remain configurable for
other American Legion installations; Post 165 examples clarify the rule but do not define
application behavior.

This is a continuity record, not a project-management system and not an official meeting
record. Meetings govern and record decisions about Endeavors. Humans remain responsible
for those decisions and for the approval, attestation, acceptance, and amendment of
official minutes.

See `docs/AMERICAN_LEGION_CONTEXT.md` for the American Legion organizational structure,
Four Pillars, Legion Family, and source-authority distinctions used by this policy.

## Inclusion Test

Create or reuse an Endeavor when all of the following are true:

1. The Post can name one specific matter, undertaking, obligation, or recurring service.
2. Its decisions, evidence, or work should remain intelligible as one history over time.
3. A future officer would reasonably ask, “What has the Post already done or decided about
   this?”
4. The record is useful beyond one routine agenda appearance, isolated task, document, or
   calendar occurrence.

Duration alone is not decisive. A short event may itself be a substantial Endeavor, while
a recurring procedural agenda heading may never be one. When uncertain, keep the matter as
a standalone agenda or minutes item until a human deliberately decides that continuity is
needed.

Do not create an Endeavor for:

- a broad area such as Membership, Americanism, or Veterans Affairs;
- a Four Pillar or another reporting/classification label;
- a routine one-meeting action with no continuing history;
- a task, follow-up, or status update that belongs inside an existing Endeavor;
- an event occurrence that merely executes an existing Endeavor; or
- a document whose role is to evidence another record.

AI may suggest a possible Endeavor, link, merge, or split. A human must confirm the
identity decision; a delegated agent may then carry out that explicit instruction with the
human's current grants. Lack of certainty is a reason to defer creation, not to manufacture
continuity.

## Identity, Not Taxonomy

An Endeavor answers **which continuing body of work is this?** Taxonomy answers **what kind
of work is it or why does it matter?** Those questions must not be collapsed.

Use a specific, recognizable name for an Endeavor. “2027 Oratorical Contest” can identify
a coherent body of work. “Americanism” is a classification and cannot own the work.

Keep one Endeavor when its name, usual meeting body, urgency, leadership, or phase changes
but officers would still tell one continuous history. Split Endeavors when the work has
independent authority, outcomes, evidence, or lifecycles and either part could conclude
without concluding the other. Recurring annual work is not automatically one record or
many: humans decide whether continuity belongs to the ongoing program or to separately
governed yearly undertakings.

Merging or splitting changes institutional history and therefore requires an explicit,
reviewable human action. Neither an AI nor a status transition may silently redefine an
Endeavor's identity.

## Relationships and Ownership Boundaries

### Organization

The organization owns the Endeavor. An optional usual `MeetingBody` may help officers find
or prioritize it, but that body is a steward, not the owner. The same Endeavor may be
considered by more than one meeting body without changing identity.

### Meetings, agendas, and minutes

Meetings govern and record decisions concerning Endeavors; they do not own them. An agenda
or minutes item may optionally concern one Endeavor. A standalone meeting item remains
valid when the inclusion test does not justify long-lived tracking.

Meeting wording is a historical snapshot. Linking an item to an Endeavor must not make
later Endeavor edits rewrite that agenda or minutes item. Likewise, changing or completing
an Endeavor must not rewrite how earlier meetings classified or described the matter.

The Endeavor continuity view may cite meeting appearances and decisions, but its officer
updates are not substitutes for official minutes. Accepted minutes remain immutable;
corrections belong in later amendments or later meeting records.

### Events and activities

An event or activity normally executes an Endeavor. For example, one volunteer shift or
one scheduled occurrence belongs to the continuing work it advances. When producing the
event is itself the coherent body of work—with its own planning, decisions, evidence, and
conclusion—the event may be the subject of the Endeavor.

This distinction is conceptual for now. It does not require an event, activity, recurrence,
task, or scheduling model in the MVP.

### Documents and other artifacts

A document is evidence or an artifact associated with the record it concerns. Meeting
packets and accepted minutes concern meetings; a permit or vendor agreement may concern an
Endeavor; a roster import concerns its import record. Endeavor must not become a universal
file cabinet, and documents must not become the source of identity for the work.

The existing PDF meeting-document delivery and `RosterImport#pending_csv` attachment are
workflow-specific mechanisms, not a general document domain model.

### Four Pillars

The Four Pillars classify why American Legion work matters. They do not own Endeavors,
meetings, events, documents, or people. If classification is later implemented, one
Endeavor may relate to more than one Pillar and one Pillar may classify many Endeavors.
Changing that classification must not change the Endeavor's identity or history. The
Pillars and their application context are defined in `docs/AMERICAN_LEGION_CONTEXT.md`.

## MVP Invariants

The `Endeavor` implementation is the MVP storage for this concept. The following
invariants apply:

- Every record belongs to one `Organization`; all linked meeting records must be scoped to
  the same organization.
- Identity is deliberate and durable. Completion preserves the record, links, timestamps,
  creator, completion provenance, and history; reopening continues that same identity.
- `EndeavorUpdate` entries are append-only. Corrections are later dated updates.
- `DatedAgendaItem#endeavor_id` is an optional identity link. Agenda items without an
  Endeavor remain first-class records.
- `DatedAgendaItem.create_from_endeavor!` snapshots title, summary, and details. The
  snapshot and its section/order remain independent of later Endeavor changes.
- The current agenda MVP permits one linked appearance of an Endeavor per `DatedAgenda`.
  This uniqueness rule is not automatically imposed on future minutes, motions, events, or
  documents.
- Structured minutes items preserve an optional direct identity link when they
  concern an Endeavor, including when seeded from a linked `DatedAgendaItem`. Minutes text
  remains an independent meeting snapshot.
- Status, importance, raise-by date, usual meeting body, Pillar classification, and future
  event relationships describe an Endeavor; none of them defines its identity.
- AI can draft or suggest. Humans remain the authority for creation, linking, merging,
  splitting, completion, reopening, approval, attestation, acceptance, and amendment. A
  delegated agent may execute an explicit authorized instruction with that user's grants;
  it may not autonomously make an identity or official-record decision.

## Explicit Non-Goals

This governance decision does not now add or design:

- an Endeavor kind hierarchy or expanded status workflow;
- tasks, assignees, dependencies, percentages, budgets, or project boards;
- Four Pillar tables, reporting categories, or classification UI;
- events, activities, recurrence, calendars, attendance, or volunteer scheduling;
- a general document archive, attachment system, or evidence search;
- dashboards, analytics, public pages, notifications, or automation;
- automatic AI creation, linking, merging, splitting, or completion;
- changes to official-minutes authority or immutability; or
- a parallel or legacy domain model beside `Endeavor`.

Those capabilities require their own product decisions and should be added only when a
real Post workflow needs them.
