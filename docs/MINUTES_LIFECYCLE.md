# Structured Minutes Lifecycle

## Purpose

Minutes are the Post's durable account of what happened at a Meeting. They are not an
edited agenda, a transcript, an Endeavor update, or a single rich-text page. This design
defines the structured drafting, human authority, member visibility, acceptance,
correction, and immutability rules required before minutes implementation begins.

The first proof case is an already-held Post meeting with a structured agenda and an
available transcript. The expected Adjutant workflow is AI-assisted: the app assembles a
controlled prompt from the Meeting, agenda structure, and transcript; asks the OpenAI API
for a structured first pass; then gives the Adjutant a source-aware interface for fixing,
accepting, or discarding what the model attempted. The result still passes through human
approval and Adjutant attestation, and either records later acceptance or remains honestly
marked as awaiting acceptance.

This specification governs Slices 2 through 5 of `docs/ROADMAP.md`. Slice 2 implements the
structured editor and source model first as engineering prerequisites, then completes the
same slice with the OpenAI-generated first pass as the primary user path. Later slices add
the official lifecycle, acceptance and amendments, PDF delivery, and delegated API access.

## Source and Authority Boundary

The 2026 American Legion Officer's Guide describes the Adjutant as the administrative
officer who may maintain meeting minutes and emphasizes the importance of those records.
Its suggested order of business has the Commander ask for corrections after the prior
minutes are read and then declare that the minutes stand approved as corrected. That is
national guidance, not proof that every Post uses one identical procedure.

LegionPostTools therefore enforces the authenticity of the record, but it does not
hard-code a motion as the only way minutes can be accepted. The applicable Post and
Department governing documents and the act that actually occurred control the procedure.
The application records one of these factual dispositions:

- accepted as presented;
- accepted as corrected;
- accepted by a recorded motion; or
- another explicitly described procedure.

Every acceptance still belongs to a real later Meeting of the same Meeting Body. The
record names the later Meeting, the disposition, the person who recorded it, when it was
recorded, and the source minutes item or other explanation when available. The software
does not infer acceptance merely because time passed or another Meeting occurred.

## Product Decisions

- Use one `MeetingMinutes` record per `Meeting`. The UI calls it **Minutes**.
- Store editable content in structured sections, items, attendance rows, and outcomes.
- Copy from an agenda only once when the draft is seeded. Every copied value becomes an
  independent minutes snapshot with explicit source lineage.
- Use narrative plus structured motion/decision outcomes. Do not build a general
  parliamentary procedure engine.
- Treat a transcript as restricted source material. It never appears in member HTML,
  print, PDF, search, Endeavor history, or the official minutes revision.
- Make **Create first draft** from the transcript the primary post-Meeting action. The app
  owns and versions the prompt; the Adjutant should not need to invent prompt text.
- Use the OpenAI Responses API with strict structured output, `store: false`, no tools, and
  a replaceable provider boundary. Save local provenance and suggestions, not provider
  conversation state.
- Use `gpt-5.6-sol` with high reasoning effort as the initial minutes-drafting default.
  Evaluate other reasoning levels against representative Post transcripts; use Terra or
  Luna for a lower-risk task only after task-specific evidence shows that quality holds.
- Draft selectively complete minutes, not a skeletal outline and not a transcript. A member
  who was absent should be able to understand what happened, why it matters, the material
  viewpoints or disagreement, and any dates, numbers, costs, commitments, or next steps
  needed to participate or follow up.
- Keep every model-produced statement visibly reviewable against transcript line/time
  ranges or agenda sources. Missing facts remain missing.
- Preserve exact approved versions in immutable `MinutesRevision` records. Member and
  official document routes render a revision, never mutable draft rows.
- Keep the lifecycle `draft -> approved -> attested -> accepted`. “Review” is work within
  draft, not another status.
- Approval and attestation are separate human acts by different people. Explicit
  capabilities authorize the acts; position-title strings do not.
- Attestation makes an approved revision member-visible as **Awaiting acceptance**.
- Acceptance points to the already-attested revision. Content cannot change between
  attestation and acceptance.
- Reopening an approved or attested record creates an append-only audit event and returns
  the working record to draft. It never deletes the superseded revision or attestation.
- Accepted minutes never reopen. Corrections are immutable linked amendments adopted or
  recorded at later Meetings.
- Official actions require a fresh, one-use confirmation bound to the exact record,
  action, revision or lock version, and content digest. A session or bearer token alone is
  never enough.
- Agents may assist with drafts under the person's current `manage_minutes` authority.
  They cannot approve, attest, accept, or amend a record without the exact human
  confirmation and execution provenance designed here.

## Product Boundary

### Included across the minutes slices

- structured draft minutes seeded from an optional agenda;
- minutes-owned meeting heading and venue snapshots;
- sections and items with independent rich-text narrative;
- standalone items for unplanned business;
- actual officer roll-call attendance copied from the agenda worksheet when available;
- structured motions and decisions with only the facts actually known;
- optional direct Endeavor identity and agenda-item source lineage;
- transcript paste and narrowly constrained plain-text upload;
- an OpenAI-generated structured first pass with prompt/run provenance, source-bound
  suggestions, and explicit Adjutant review;
- approval, Adjutant attestation, reopen, acceptance, and amendment provenance;
- immutable approved revisions and accepted official records;
- member Meeting-page and document progression;
- the shared print-first official document shell and later PDF generation; and
- private API/handbook parity after the HTML workflow is proven.

### Deliberately excluded from the first AI-assisted slice

- audio or video upload, transcription, playback, or streaming;
- automatic speaker identification;
- a general parliamentary engine, rules adjudication, or quorum determination;
- vote-by-member ballots or secret-ballot storage;
- automatic Endeavor creation or lifecycle changes;
- a freeform “chat with the transcript” experience or user-authored production prompts;
- public or anonymous minutes;
- email distribution before final document generation is stable;
- handwritten-signature images or decorative signature simulation; and
- reusable document, evidence, or attachment libraries.

## Vocabulary

- **Meeting** — the occurrence: when and where a Meeting Body assembled.
- **Agenda** — the ordered plan distributed before the Meeting.
- **Working minutes** — editable structured rows used by authorized officers.
- **Approved revision** — an immutable snapshot approved for Adjutant review. It remains
  officer-only until attested.
- **Attestation** — the Adjutant's fresh human confirmation that an exact approved revision
  is the minutes record being presented to members. It is signature-equivalent in the app,
  but is displayed as an attestation rather than a simulated handwritten signature.
- **Acceptance** — the later same-body Meeting's factual act accepting the attested
  revision, as presented or with explicit corrections.
- **Amendment** — an immutable later correction linked to the accepted revision. It adds
  authority; it never overwrites the original text.
- **Transcript** — restricted drafting evidence, not the official record.
- **Revision** — an immutable structured payload and digest created by human approval.

## Domain Model

```text
Meeting
|-- zero or one DatedAgenda
|-- zero or one MeetingTranscript
`-- zero or one MeetingMinutes
    |-- many MinutesSections
    |   `-- many MinutesItems
    |       `-- many MinutesOutcomes
    |-- many MinutesAttendanceEntries
    |-- many immutable MinutesRevisions
    |   `-- lifecycle events / current attestation / acceptance
    `-- many immutable MinutesAmendments after acceptance

Endeavor <---- optional direct link ---- MinutesItem
DatedAgendaItem <---- optional source ---- MinutesItem
Later same-body Meeting <---- evidence ---- MinutesAcceptance / MinutesAmendment
```

All relationships remain inside one `Organization`. A Meeting has at most one agenda, one
transcript source record, and one minutes record. Structured child rows provide detail;
they are not competing documents.

### `MeetingMinutes`

Use class `MeetingMinutes` and table `meeting_minutes`; the association may be
`meeting.minutes` with an explicit class name. The mass noun reads naturally in product
copy while avoiding a misleading singular `Minute` model.

Required fields and relationships:

- `organization_id` and unique `meeting_id`;
- snapshot `meeting_body_id` and optional `meeting_type_id`;
- snapshot `title`, `starts_at`, `location_name`, and `location_address`;
- `status`, constrained to `draft`, `approved`, `attested`, or `accepted`;
- optional `current_revision_id`, pointing only to one of its own revisions;
- optimistic `lock_version`; and
- timestamps.

The heading is copied when minutes are first created. If a published agenda exists, its
historical heading and venue snapshots are the source. Otherwise the Meeting snapshots are
the source. The draft heading can be deliberately corrected by a minutes editor, but it
does not automatically follow later Meeting or agenda changes. Once a revision is
approved, the revision owns the heading that readers will see.

The `Meeting` cannot be deleted once minutes exist. Its historically significant heading,
time, body, and venue become immutable when the minutes are accepted. Later corrections
belong to an amendment or a later Meeting record.

An accidentally created minutes draft may be deleted only while it has never produced a
revision or lifecycle event. Use the shared destructive confirmation pattern. Once any
approval has occurred, the minutes record and all superseded revisions are historical and
cannot be deleted, even if the current status later returns to draft.

### `MinutesSection`

- belongs to `MeetingMinutes`;
- optional `source_dated_agenda_section_id`;
- snapshotted `title`;
- unique integer `position` inside the minutes record;
- optimistic `lock_version`; and
- timestamps.

Sections are copied in agenda order. Empty agenda sections may be retained because their
place in the Meeting's order can still help an officer add unplanned business accurately.
An editor may add, rename, reorder, or remove sections while draft.

### `MinutesItem`

- belongs to `MeetingMinutes` through one `MinutesSection`;
- optional `source_dated_agenda_item_id`;
- optional direct `endeavor_id`;
- snapshotted `title`, `behavior_type`, and `position`;
- Action Text `body` for factual narrative;
- a stable opaque `record_key` copied into revisions and used by later amendments;
- optimistic `lock_version`; and
- timestamps.

The item retains behavior intent such as report, business item, roll call, reading, or
motion/decision, but behavior never fabricates an outcome. More than one minutes item may
link to the same Endeavor when distinct reports, motions, or decisions require separate
entries. The agenda's one-Endeavor-appearance uniqueness rule does not apply here.

When seeded from an agenda item:

- always copy the title, behavior, section, position, source item id, and optional direct
  Endeavor id;
- copy rich-text wording only when `show_wording_in_minutes` is true;
- never copy Commander-only cues;
- never make later agenda or Endeavor edits rewrite the minutes item; and
- never infer a missing Endeavor link from title, transcript similarity, catalog entry,
  behavior, section, or Meeting Body.

A standalone item has no agenda source and is fully valid. The editor labels it **Added
during the meeting**, not “unscheduled” or “exception,” because unplanned business is an
ordinary meeting fact.

### `MinutesOutcome`

An item may contain zero or more ordered outcomes. Use one model rather than embedding
motions in narrative so decisions can later be found and rendered consistently.

- belongs to `MinutesItem`;
- `kind`: `motion` or `decision`;
- required factual `text`;
- optional `mover_person_id` and `mover_name` snapshot;
- optional `seconder_person_id` and `seconder_name` snapshot;
- `disposition`: `adopted`, `lost`, `withdrawn`, `postponed`, `referred`, `no_vote`, or
  `not_recorded`;
- optional short `vote_summary`, used only for an actually recorded phrase such as
  “unanimous” or “7–2”;
- integer `position`, optimistic `lock_version`, and timestamps.

For a `decision`, mover and seconder normally remain blank. For a motion, those names are
optional because the source may not establish them. `not_recorded` is a deliberate draft
warning produced when the source or AI first pass does not establish a result; it is not a
normal peer choice for the human reviewer, and a blank field must never cause the app or AI
to assume that a motion passed.

#### Roster-backed participant resolution

The human review workflow replaces the free-text-only mover and seconder fields with
an inline roster-backed identity resolver. The source wording remains visible, and the AI
may preserve exactly the first name, nickname, or uncertain spelling it heard, but it must
not choose a `Person` from similarity or likelihood.

The review card exposes one compact **Motion record** with **Outcome**, **Moved by**, and
**Seconded by** visible together. Do not hide these fields behind progressive disclosure or
repeat the same result and names in a separate AI summary. The **Edit before using** page
uses the same three-part structure. Both surfaces show **AI heard** above the resolver.
The reviewer searches the bounded Post roster locally and explicitly chooses a full name;
fuzzy ranking may help find candidates but never confirms one. The picker also offers
**Could not identify from the roster** when the source supplied a name that the reviewer
cannot safely resolve. A confirmed choice writes `mover_person_id` or
`seconder_person_id` and freezes the person's full displayed name into the corresponding
name snapshot. Later roster or role changes never rewrite that minutes record. The ordinary
outcome editor uses the same picker so later edits cannot degrade a verified identity back
to ambiguous free text. The same pattern may later support other attributed participants
when the source and minutes format call for it. Sick Call and Service Officer case details
never enter this identity workflow.

#### Plain-language motion result review

For a motion, label the field **Outcome** and present **Passed**, **Failed**, and
**Other outcome** as mutually exclusive choices. Store those first two choices as the
existing `adopted` and `lost` domain values. **Other outcome** reveals the factual choices
**Withdrawn**, **Postponed**, **Referred**, and **No vote taken**. Do not expose
`not_recorded` as an equivalent radio choice.

When an AI suggestion has `not_recorded`, show an amber **AI could not determine the
result** warning and require the reviewer to choose a result before adding the motion.
The suggestion remains unreviewed until the reviewer supplies the missing result or
discards it. Rendered working minutes use the plain phrases **Motion passed** and **Motion
failed**, even though the stored values remain `adopted` and `lost` for compatibility.

This structure does not decide whether a second was legally required, whether debate was
proper, whether quorum existed, or whether the procedure was valid. It records what the
human source says occurred.

### `MinutesAttendanceEntry`

- belongs directly to `MeetingMinutes`;
- optional source `dated_agenda_roll_call_entry_id`;
- optional `position_title_id` and `person_id`;
- snapshotted `office_name` and optional `person_name`;
- `status`: `present`, `absent`, `excused`, `vacant`, or `not_recorded`;
- integer `position`, optimistic `lock_version`, and timestamps.

Seeding copies the agenda officer-list snapshot rather than today's assignments. A vacant
agenda row becomes `vacant`; every named officer begins as `not_recorded`. An editor records
the actual result. The app does not infer presence from who edited the minutes, a transcript
speaker label, or a current office assignment.

The first slice records the officer roll call only. General member attendance, guests, and
quorum may be described in a normal minutes item until a real Post workflow justifies
additional structured attendance kinds.

### `MeetingTranscript`

The transcript belongs to the Meeting, not to an Endeavor or an individual minutes item.
It may exist before minutes are created and remains a source for that Meeting's drafting
workflow.

- unique `meeting_id` and matching `organization_id`;
- `source_kind`: `pasted_text` or `text_upload`;
- plain UTF-8 `content` for pasted text or one Active Storage attachment for upload;
- original filename, byte size, media type, and SHA-256 digest metadata;
- `retention_policy`: `delete_after_acceptance` or `retain_restricted`;
- creator, creation time, optional `purge_scheduled_at`, `purged_at`, and purger;
- optimistic `lock_version`; and
- timestamps.

The upload path accepts only UTF-8 `text/plain` files up to 5 MB in the first slice. It
does not accept Word, PDF, captions, audio, video, archives, or executable formats. Paste
is the primary path.

Transcript reads require `manage_minutes` or `view_internal_records`. Transcript content
is excluded from member serializers, document renderers, logs, search indexing, error
messages, and agent handbook examples. Draft API access waits for the later delegated
slice and must return transcript content only when explicitly requested.

At creation, the officer must choose a retention policy:

- **Delete after acceptance** is the recommended default. Acceptance schedules content
  deletion after a 30-day recovery window. The digest and non-content audit metadata
  remain.
- **Retain as restricted source** keeps the source under the same restricted access until
  an authorized person deliberately deletes it.

An authorized officer may deliberately purge source content earlier with a destructive
confirmation and audit event. Purging source never deletes or changes a minutes draft,
revision, acceptance, amendment, or PDF. This is record-source retention, not an assertion
about any external audio file from which the transcript came.

Before the first OpenAI request, the screen plainly states that transcript content will be
sent to OpenAI to create a draft and summarizes the installation's provider-retention
posture. Send transcript text directly in a foreground Responses API request with
`store: false`; do not upload it to OpenAI Files or create a provider Conversation merely
for this workflow. OpenAI API data is not used to train models by default, but ordinary
abuse-monitoring logs may retain customer content for up to 30 days unless the API project
has approved data controls. This disclosure is separate from the app's own transcript
retention choice.

## Draft Seeding

Creating minutes is a transaction and is idempotent at the Meeting boundary:

1. lock the Meeting and reject creation if it already has minutes;
2. copy the historical heading from the published/approved agenda when present, otherwise
   from the Meeting;
3. create sections in source order;
4. copy every active agenda item, its source lineage, and its optional Endeavor link;
5. copy item wording only where `show_wording_in_minutes` permits it;
6. copy roll-call rows into minutes-owned attendance with unknown results made explicit;
7. leave outcomes empty; and
8. land on the structured draft workspace with a concise seeding summary.

An agenda is helpful but not required. Without one, create an empty **Meeting record**
section and direct the officer to add what actually occurred. Minutes never require a
fictitious agenda merely to satisfy the data model.

Seeding does not publish, approve, attest, accept, create an Endeavor, append an
`EndeavorUpdate`, or copy transcript text into official fields.

Seeding creates the safe relational scaffold on which the AI first pass operates. When a
transcript is available, the normal next action is **Create first draft**. **Write manually**
remains a secondary path for missing transcripts, provider outages, or an Adjutant who
prefers not to send that Meeting's source to an external provider.

## Immutable Revisions and Audit History

Mutable rows are appropriate for drafting but insufficient once an attested version has
been shown to members. Reopening must not silently replace what they previously read.

### `MinutesRevision`

Approval creates an append-only revision containing:

- parent minutes id and monotonically increasing revision number;
- a versioned canonical JSON payload containing heading, sections, items, rich-text HTML,
  source/Endeavor lineage, attendance, and outcomes in display order;
- `schema_version` and `renderer_version`;
- SHA-256 `content_digest` over canonicalized payload bytes;
- source minutes `lock_version`;
- approving user id, snapshotted person/office labels, and approval time; and
- timestamps.

The JSON payload is an immutable document artifact, not the editable domain model. Core
working data remains relational and structured. Member HTML and later PDFs render the
revision payload, ensuring that reopening or editing draft rows cannot rewrite an already
attested document.

Revision rows are append-only at the PostgreSQL layer: reject `UPDATE` and `DELETE`. An
approved revision can be superseded by a later revision, never altered. Store neither
transcript content nor Commander cues in the payload.

### `MinutesLifecycleEvent`

Every state transition creates an append-only event with:

- minutes and optional revision ids;
- `event_type`: `approved`, `attested`, `reopened`, or `accepted`;
- prior and resulting status;
- actor user id plus person and office snapshots;
- occurrence time;
- the consumed official-action confirmation id where required; and
- structured metadata such as reopen reason or superseded revision id.

PostgreSQL rejects update/delete of lifecycle events. `MeetingMinutes.status` and
`current_revision_id` are transactionally maintained projections for ordinary queries;
the events and revision preserve history.

## Lifecycle

```text
                       reopen + reason
                  +------------------------+
                  |                        |
draft --approve--> approved --attest--> attested --accept--> accepted
  ^                    |                       |
  +------ reopen ------+---------- reopen ----+

accepted has no outbound transition
```

### Draft

- visible only to users with `manage_minutes` and to other explicitly authorized internal
  record viewers;
- all structured content is editable;
- transcript sources may be added or purged;
- an officer can preview a visibly marked **Draft minutes** document; and
- no member Meeting page implies that minutes are available.

### Approval

Approval requires `approve_minutes`, an exact one-use human confirmation, and a fully
valid draft. The confirmation screen renders the final document preview and states:

> Approve this exact draft for Adjutant attestation.

The transaction rechecks capability, record status, lock version, and content digest;
creates the immutable revision and approval event; sets `status=approved`; and points
`current_revision_id` to it. Working content becomes read-only.

Approval is officer-only and is not publication, acceptance, or proof that the Meeting
Body acted. UI copy says **Approved for attestation**, not merely “Approved.”

### Attestation

Attestation requires `attest_minutes`, a different person from the revision approver, and
another exact one-use confirmation bound to that revision and digest. The confirmation
screen states:

> Attest that this exact revision is the minutes record being presented to members.

The transaction rechecks the revision digest and current status, creates the append-only
attestation event, and sets `status=attested`. No draft content is copied or regenerated.

The member document now becomes available and shows:

- **Attested minutes**;
- the attester's snapshotted name and office label;
- the attestation date and local time; and
- **Awaiting acceptance at a later meeting**.

The interface must not call these accepted, final, or official minutes yet.

### Reopen

Reopening requires a reason and exact human confirmation.

- From `approved`, require `approve_minutes`.
- From `attested`, require `attest_minutes`.
- The person reopening may be the person who performed the prior act or another person
  with the same explicit capability.

The transaction records a `reopened` event naming the superseded revision and returns the
working record to `draft`. It does not delete the revision, approval, or attestation.

If an attested record was member-visible, its old revision remains retained and auditable.
The Meeting page says **Minutes are being revised** and does not substitute mutable draft
content. A quiet link to the superseded attested revision remains available so previously
published history is not erased. The next approval creates revision N+1 and the full
approval/attestation sequence repeats.

### Acceptance

Rename the unused capability `record_acceptance_motions` to
`record_minutes_acceptance`, migrating any existing literal grants. The action records
acceptance; it does not assume a motion was the procedure.

Acceptance requires:

- current `attested` status and exact attested revision;
- a later Meeting in the same Organization and Meeting Body;
- later means a strictly later `starts_at`, not merely a higher database id;
- an explicit disposition;
- `record_minutes_acceptance` and exact human confirmation;
- optional source `MinutesItem` from the accepting Meeting's minutes; and
- a required factual note when no source item exists, supporting historical backfill.

Use a unique `MinutesAcceptance` record with the accepted minutes/revision, accepting
Meeting, optional source item, disposition, factual note, recorder, actor snapshots,
recorded time, and confirmation. The acceptance and lifecycle event are created in one
transaction and are append-only.

For `accepted_as_corrected`, create one or more amendment records in the same confirmed
transaction. Never edit the attested revision before accepting it. For
`accepted_by_motion`, the optional source outcome can preserve the mover, seconder, and
disposition that were actually recorded; the app does not manufacture those facts.

Accepted member copy shows **Official minutes**, the accepting Meeting and disposition,
the attestation, and every amendment. The original revision remains visually primary as
the historical text; corrections appear immediately with it, not hidden in an audit page.

### Amendments after acceptance

An amendment requires an already accepted revision, a later same-body Meeting,
`record_minutes_acceptance`, and one-use human confirmation. `MinutesAmendment` stores:

- accepted minutes and revision ids;
- a stable target `record_key` or whole-document target;
- adopting/recording Meeting and optional source MinutesItem;
- required concise title and exact correction text;
- recorder and actor snapshots;
- adopted/recorded time and sequence; and
- confirmation id and timestamps.

Amendments are append-only at the database layer. A mistaken amendment is corrected by a
later amendment, never by editing or deleting it. The UI and document renderer present the
complete chain in order.

## Official-Action Confirmation

Recent authentication is useful for creating an agent token, but it is not specific
enough for official records. Add a reusable `OfficialActionConfirmation` boundary.

Each confirmation is bound to:

- one user and current session;
- one record type/id;
- one action (`approve`, `attest`, `reopen`, `accept`, or `amend`);
- exact lock version and content/revision digest;
- optional agent access token/execution request context;
- creation and short expiry times;
- confirmation and consumption times; and
- a random selector/token stored only as a digest where a bearer value is needed.

The human sees the record identity, action, current status, and exact consequence before
confirming with a passkey or the session-bound email code/link fallback. The confirmation
expires after ten minutes, works once, and is consumed in the same transaction as the
official mutation. Capability, user status, session, record version, digest, and lifecycle
state are rechecked at consumption. A stale confirmation fails safely and changes nothing.

No administrator implication grants `approve_minutes`, `attest_minutes`, or
`record_minutes_acceptance`. There is no bypass for support staff, console UI, bearer
tokens, or an agent. Emergency repair of corrupt data is an exceptional database operation
outside normal product behavior and must never masquerade as a valid lifecycle act.

The initial lifecycle implementation exposes confirmations only through signed-in HTML.
The later API may let an agent prepare an exact pending action and direct the human to its
confirmation page. The agent can complete only that confirmed action, with idempotency and
`AgentApiExecution` provenance linking the confirmation and mutation.

## Officer Workflow

### Meeting workspace

The existing Meeting workspace gains a Minutes document row:

- before the Meeting: **Minutes begin after the meeting**;
- past Meeting with transcript: **Create first draft**;
- past Meeting without transcript: **Add transcript** with secondary **Write manually**;
- draft: **Continue draft** with last-edited context;
- approved: **Awaiting Adjutant attestation**;
- attested: **Visible to members · Awaiting acceptance**;
- accepted: **Official minutes**; and
- reopened after attestation: **Under revision** with preserved prior revision.

Starting minutes uses the agenda automatically when one exists and starts from the Meeting
when it does not. It does not silently create minutes merely because the Meeting date
passed. The app explains what sources will be used before **Create first draft** sends
anything to OpenAI.

### Draft workspace

The page's single job is to help an Adjutant correct an AI-generated first pass into an
accurate, reviewable Meeting record while always knowing what came from a source, what the
model inferred, and what remains unconfirmed.

Desktop uses a quiet two-column working layout:

```text
MINUTES · Membership Meeting · 07 JUL 2026
[ Draft — officer working record ]

+--------------------------------------------+  +--------------------------+
| AI FIRST PASS · 14 items need review       |  | SOURCE                   |
| Attendance                  [Review]        |  | Transcript · restricted  |
| I. Opening Ceremony                        |  | 00:03:14–00:04:02        |
| II. Roll Call, Minutes & Guests            |  | “The minutes from...”    |
|     Prior minutes            [AI draft]     |  |                          |
|     [Edit] [Use] [Discard]                  |  | RECORD STATUS            |
| III. Reports                               |  | Draft                    |
| ...                                        |  | 1 Correct first pass     |
| [Add business the model missed]            |  | 2 Commander approval     |
+--------------------------------------------+  | 3 Adjutant attestation   |
                                                | 4 Later acceptance       |
                                                +--------------------------+
```

The main column is the proposed record, not a form dashboard or chatbot. Sections follow
the real Meeting order. Model-written fields carry a visible **AI draft** label until the
Adjutant uses, edits, or discards them. Selecting a field updates the source pane to the
supporting transcript range and agenda item. Each item opens one correction editor with
plain labels:

- **What was reported or discussed?**
- **Was a motion or decision recorded?**
- **Does this concern an existing Endeavor?**
- **Source** — exact agenda item and transcript line/time ranges when available.

**Use** accepts the proposed wording as working draft content; editing it both saves the
human wording and marks the proposal reviewed; **Discard** removes it without deleting the
source. There is no one-click **Accept all**. Section-level review is allowed only after
every contained warning, attendance result, and motion/decision outcome has an explicit
human disposition.

Using or discarding an individual suggestion updates that ledger row in place. The page
must preserve the Adjutant's scroll position, replace the action with a plain **Added to
minutes**, **Edited and added**, or **Discarded** state, and update the remaining-review
count without a page-level flash or redirect to the top.

Attendance is the deliberate exception to the one-card-per-suggestion presentation. Show
one officer roll-call sheet containing every snapshotted office. Each named officer has a
mutually exclusive radio group for **Present**, **Absent**, **Excused**, and the safety
escape **Not established**; a vacant office remains visibly fixed as **Vacant**. An
unreviewed model proposal preselects and labels its supported choice, while rows without a
supported proposal retain their current minutes value. **Save attendance review** is one
bounded human review of the visible roll-call sheet, not a general accept-all action. It
records every displayed choice, marks matching attendance suggestions used and corrected
choices edited, preserves optimistic-lock failures, and updates the sheet in place.

The side column is a truthful source and lifecycle boundary, not a collection of equal
cards. At narrow widths, the selected source excerpt appears immediately after the field
being reviewed rather than forcing the Adjutant to jump between distant page regions.
Sticky positioning is desktop-only and must not obscure keyboard focus.

Autosave is not required. Explicit **Save changes** buttons, optimistic-lock conflict
messages, and stable return anchors are preferable for users with lower computer
confidence. Reordering keeps accessible move controls; drag behavior may remain an
enhancement.

### Review and official actions

**Review minutes** renders the exact prospective revision in the shared document shell
with a structured completeness panel outside the document. Completeness checks warn but
do not invent or require facts that may genuinely be unavailable:

- attendance still marked **Not recorded**;
- a motion with **Not recorded** disposition;
- blank narrative under an agenda business item;
- an Endeavor suggestion not human-confirmed; or
- retained transcript policy not selected.

Only actual validation failures block approval. Warnings require deliberate acknowledgement
on the approval confirmation page rather than forcing false data.

Approval, attestation, reopen, acceptance, and amendment each use a dedicated consequence
page. Do not place all lifecycle buttons beside one another or rely on a generic browser
confirmation dialog.

## Member Experience

The Meeting page continues to show the best available record:

| State | Primary member action | Secondary context |
| --- | --- | --- |
| No attested minutes | Published agenda when available | Minutes not published yet |
| Attested | Read attested minutes | Awaiting acceptance; view agenda |
| Attested revision reopened | Minutes are being revised | Read prior attested revision; view agenda |
| Accepted | Read official minutes | Acceptance details; view agenda |
| Accepted with amendments | Read official minutes with corrections | View original text and agenda |

Draft and approved revisions remain officer-only. Direct URLs enforce the same boundary.
An attested or accepted document is available to every signed-in member; no separate
minutes publication button exists.

The member document renders revision content, not live draft rows. Its authority block
states exact facts:

- **Approved for attestation by** name and date;
- **Attested by** name, office snapshot, and date;
- **Awaiting acceptance** or the accepting Meeting/disposition; and
- amendments, when any, with their later Meeting evidence.

Avoid the ambiguous standalone word **Final**. “Official” appears only after acceptance.

## Visual Direction: The 1919 Record of Proceedings

This design follows the established “The 1919” system and the shared official meeting
document shell. The concrete subject is an Adjutant preparing a Post's permanent record;
the primary reader is an officer reviewing it carefully and later a member finding the
authoritative account. The single visual job is to distinguish working source, human
authority, and official record without making the document feel like software status
machinery.

### Tokens and type

- Authority navy `#0A2240` — headings and primary actions;
- Legion gold `#C6A15B` — one authority rule and active focus accent;
- Cream field `#F4EEDD` — application background;
- Paper `#FBF7EC` on screen and white `#FFFFFF` in print;
- Ink `#1B222B` and muted slate `#6B7684` — readable working text; and
- Officer blue `#2F5F87` — restricted source boundary only.

Use the application system sans for editor controls, status, attendance, and provenance.
Use Georgia only inside the actual minutes document and revision preview. Do not use a
cursive signature font; identity is established by the confirmation record, not visual
theater.

### Signature element

The minutes family's one memorable element is the **attestation folio**: a restrained
gold-ruled block at the end of the document that accumulates exact human acts. In draft it
is a quiet preview of what remains. In attested and accepted revisions it names the people,
times, revision digest abbreviation, and later Meeting evidence.

```text
------------------------------------------------------------------
RECORD OF AUTHORITY
Approved for attestation  Pat Example · 12 Jul 2026
Attested                  Alex Example, Adjutant · 13 Jul 2026
Acceptance                Awaiting a later Membership Meeting
Revision                  2 · 7f4c91d2…
------------------------------------------------------------------
```

The folio is not a faux seal, rubber stamp, certificate, signature line, or progress-card
grid. Its structure encodes real provenance and remains useful in grayscale.

### Document composition

Reuse the official US Letter shell, organization identity, location, navy/gold rule,
Georgia document face, Roman-numeral section outline, and running footer. Add:

- **Draft minutes**, **Attested minutes**, or **Official minutes** as the document kind;
- actual attendance as a compact ruled table;
- narrative followed by distinct, break-resistant motion/decision blocks;
- visible **Not recorded** wording rather than blank factual fields;
- the attestation folio after the record; and
- amendments immediately after the affected item where possible plus a complete correction
  register after the folio.

Transcript excerpts, AI confidence, internal warnings, Commander cues, editor controls,
and agent provenance never render inside member or print minutes.

### Narrow and accessible behavior

- At 390px the workspace is one column with lifecycle/source context before the outline.
- Attendance rows stack office, person, and result without a horizontal table scroll.
- Outcome fields stack; mover and seconder never sit in a cramped two-column form.
- Source and lifecycle meaning always has text, never color alone.
- Interactive text remains at least 16px and no meaningful text falls below 13px.
- Focus is visibly navy/gold and not clipped by sticky or scroll containers.
- Reduced motion is respected; no lifecycle animation is necessary.
- Print is white US Letter and never includes application chrome or restricted source.

### Distinctiveness critique

A generic four-card workflow and a colorful status stepper were rejected. They make
official authority look like project tracking and give every step equal visual weight.
The truthful sequence remains in plain text at the workspace edge, while the single
designed gesture is the provenance-bearing attestation folio in the record itself.

A legal-certificate treatment with seals, script signatures, and large “APPROVED” stamps
was also rejected because it would visually claim authority beyond what the stored human
acts establish. The quieter record-of-proceedings direction belongs specifically to an
American Legion Meeting and preserves readability for older members.

## Endeavor Continuity

- Draft minutes never appear as settled Endeavor history.
- Attested appearances may appear only in authorized continuity views and must say
  **Awaiting acceptance**.
- Accepted revision items and amendments are authoritative Meeting history.
- Minutes seeding copies an existing direct `endeavor_id`; it never derives identity.
- A human may add, remove, or correct an Endeavor link while draft.
- The revision freezes the link. Reopening may create a new superseding revision; an
  accepted link changes only through an amendment or later Meeting record.
- Recording a motion, decision, or report never creates an `EndeavorUpdate` or changes the
  Endeavor's title, priority, lifecycle, usual body, or ownership.
- More than one minutes item may concern the same Endeavor when the record contains
  distinct actions.

## OpenAI-Generated First Pass

The manual editor must work before the provider is wired in so every model suggestion has
a safe destination and the Post is never blocked by an API outage. That is implementation
order, not the intended daily experience. Slice 2 is not complete until an Adjutant can
create and correct an OpenAI-generated first pass through the web interface.

### Request assembly

Use a replaceable `MinutesDraftProvider` with an OpenAI implementation. The domain models
must not depend on OpenAI response classes or model names. The request uses the Responses
API and contains:

1. a versioned developer prompt defining the Post-record task and anti-fabrication rules;
2. the exact JSON schema for sections, item suggestions, attendance, outcomes, source
   references, uncertainties, and missing facts;
3. Meeting and snapshotted agenda structure, including item behavior and direct Endeavor
   ids already confirmed by humans, plus a bounded list of relevant existing Endeavor ids,
   titles, summaries, and statuses;
4. the transcript with stable line numbers and preserved timestamps when supplied; and
5. an explicit instruction to use `null` / `not_recorded` rather than guessing.

The first pass organizes facts by the supplied agenda structure rather than transcript
chronology. A late officer report belongs under that officer's report item. Substantive
discussion that strays from the current item belongs under a more specific agenda item
when one exists. If no agenda item fits, the model checks the supplied existing Endeavors;
a clear match becomes a proposed added minutes item with a human-reviewable Endeavor link.
Only genuinely unrelated material with no better destination belongs under **Good of The
American Legion**. The transcript citation remains at the lines where the words were
actually spoken. Brief asides and uncertain classifications are omitted or flagged for
review rather than forced into a misleading destination.

Use strict Structured Outputs rather than asking the model to imitate JSON in prose. Do
not enable web search, file search, code execution, or other tools. Do not let the model
read the current Post roster to infer speakers or attendance. The initial request is
stateless with `store: false` and runs in Solid Queue rather than inside the initiating
web request. Creating a run returns the Adjutant immediately to an authenticated
draft-dispatch page. That page monitors the durable `pending`, `running`, `succeeded`,
and `failed` states and moves to the existing review ledger when the run finishes. The
Adjutant may safely leave and return while OpenAI is working.

The waiting interface follows the established **The 1919** document system. Its single
job is to make the handoff legible to a low-confidence computer user: request received,
OpenAI working, then human review. It must show only recorded states, not invented
percentages or pseudo-progress. Use a restrained dispatch-docket treatment in navy,
cream, and gold; keep a manual status check available; announce state changes accessibly;
and avoid animation that implies more precision than the application has.

The prompt lives in versioned application code or a later guarded prompt-template store;
the Adjutant sees a plain explanation of what the app will do, not a prompt-engineering
textbox. Persist prompt version and SHA-256, provider, exact model, request/response ids,
token usage, source digest, schema version, requester, timestamps, and terminal status in
`MinutesDraftRun`.

The initial OpenAI provider sends `model: "gpt-5.6-sol"` and
`reasoning: { effort: "high" }`. Keep model and reasoning selection in provider
configuration rather than domain records, while recording the effective values on every
run. Sol is still an untrusted drafting assistant: the source-evidence, missing-fact, and
human-review rules apply regardless of model capability.

### Suggestion staging

The structured response creates `MinutesDraftSuggestion` staging rows, not approved
minutes and not invisible direct mutations. Each suggestion records:

- target section/item or a proposed standalone item;
- optional proposed link to an exact supplied existing Endeavor, for an added item only;
- field/kind and proposed wording or structured value;
- exact transcript line/time ranges and agenda source ids;
- model-reported uncertainty and missing-fact flags;
- `unreviewed`, `used`, `edited`, or `discarded` review state;
- reviewer and review time; and
- draft-run provenance.

Applying an outcome, attendance, or additional-item suggestion copies its value into the
normal editable minutes row. Applying an item-summary suggestion appends a reviewed
paragraph so separate supported passages and existing agenda wording cannot overwrite one
another. Later prompt runs create new suggestion sets and never overwrite human-edited content. Regeneration
requires a deliberate choice of whether to target only unresolved fields or start a new
draft; the default is unresolved fields only.

AI may summarize discussion and suggest possible links to the supplied bounded list of
relevant existing Endeavors. The model receives only the id, title, summary, and status,
not a roster or an invitation to infer identity. A link stays a suggestion until the human
uses it unchanged or confirms/corrects it in the edit form. AI may not create, merge,
split, complete, reopen, rename, prioritize, or reassign an Endeavor.

The model may propose attendance, mover, seconder, vote, and outcome values only when it
also identifies direct supporting transcript evidence. Those proposals remain visibly
unreviewed; unsupported values must be `not_recorded`. The model never proposes approval,
attestation, acceptance, amendment, or confirmation.

The first pass uses medium text verbosity and an explicit absent-member usefulness test.
It preserves directly supported material context, significant viewpoints or disagreement,
reasons, proposals, names, dates, places, costs, quantities, statistics, commitments, and
next steps while omitting repetition and minor banter. This is selective completeness, not
verbatim transcription. Attribute a viewpoint only when the source identifies its speaker.

### Failure and privacy behavior

Sick Call and Service Officer reports are a deliberate exception to the normal detail
standard. Their suggestions may retain anonymous or aggregate counts and general activity,
but never names or identifying health, benefit, financial, or case details. Reviewers must
not relocate private details to another item merely to preserve them.

Provider timeout, refusal, schema failure, context overflow, partial output, or an
unexpected worker failure leaves the minutes scaffold intact and explains the next
action: retry, reduce the transcript, or continue manually. The browser must not time out
while the background draft is still progressing. Persist safe error category and request
id, never transcript or model output in logs.

Preflight estimates whether the selected model can accept the full prompt without
truncation. The first implementation fails clearly rather than silently dropping early
transcript content. Evidence-preserving chunk/merge drafting may be added after a real
oversized transcript establishes the need.

OpenAI API data is not used to train models by default. `store: false` avoids Responses API
application-state storage, but ordinary abuse-monitoring retention may still apply. The UI
and deployment documentation must preserve that distinction and must not promise zero
retention unless the configured API project has approved controls.

## Private API and Agent Handbook

Add API behavior only after the corresponding HTML behavior is stable.

### Draft slice

With `manage_minutes`, list/show minutes working records; create minutes for an exact
`meeting_id`; edit draft heading, sections, items, attendance, and outcomes; and reorder
within exact sections. Preserve optimistic locking, organization scope, idempotency, and
`AgentApiExecution` provenance.

The web app, not a delegated agent, initiates the normal OpenAI first-pass run. Later API
parity may allow an authorized agent to request a draft run, but model suggestions retain
the same source evidence and human review states.

Transcript content is a separate explicit endpoint requiring `manage_minutes` or
`view_internal_records`. It is never embedded in ordinary Meeting or minutes responses.
Destructive transcript purge is listed only when asked.

### Official actions

Do not expose approve, attest, reopen, accept, or amend as ordinary bearer mutations. A
later agent flow may:

1. prepare an exact action request and receive a human confirmation URL;
2. pause while the human reviews and confirms that exact action;
3. consume the confirmation once with the same idempotency key and request fingerprint;
4. record the user, token, execution, confirmation, revision, and lifecycle event; and
5. fail without mutation if any bound fact changed.

The handbook must label these separately from routine draft work and plainly say that an
agent cannot confirm them.

## Database and Immutability Rules

Use foreign keys, check constraints, and unique indexes for status enums, one-to-one
Meeting cardinality, section/item positions, revision numbers, one acceptance per minutes
record, and same-parent relationships where PostgreSQL can enforce them directly.

Application validations enforce same-Organization and same-Meeting-Body boundaries, but
accepted authority cannot depend only on controller paths:

- PostgreSQL rejects update/delete of `minutes_revisions`, lifecycle events,
  acceptances, and amendments;
- PostgreSQL rejects content update/delete of working minutes, sections, items,
  attendance, and outcomes whenever the parent status is not `draft`;
- PostgreSQL rejects every transition away from `accepted` and deletion of a minutes
  record that has any revision or lifecycle event;
- model validations and destroy callbacks provide clear user-facing errors for approved,
  attested, and accepted states;
- member/document rendering always uses the immutable revision payload; and
- no `dependent: :destroy` path may erase official or superseded history.

Action Text remains appropriate for draft item narrative. The revision payload freezes
sanitized rich-text HTML at approval, so an accepted official document is not dependent on
later mutable Action Text rows. Accepted-parent database guards still protect the working
rows and direct Endeavor links.

## Migration and Rollout

No existing minutes data requires backfill. Add the schema in bounded migrations and keep
the feature inaccessible until its full slice is internally coherent.

Before production transcript use:

- verify Active Storage persistence across a container restart;
- verify plain-text type/size/content validation;
- exercise both retention policies and purge jobs;
- confirm transcript content is absent from logs, member pages, PDFs, JSON defaults, and
  error reporting; and
- document backup implications: a deleted transcript may remain in older infrastructure
  backups according to the operator's backup retention, even after application purge.

Seed no fake minutes, acceptance, or authority events. Existing capability names are
already present; migrate `record_acceptance_motions` to `record_minutes_acceptance` before
the first grant is used by this workflow.

## Verification Contract

### Models and database

- one minutes record and transcript per Meeting;
- organization/body/source boundary validation;
- agenda seeding with and without wording, Endeavors, empty sections, and roll call;
- standalone sections/items and multiple items for one Endeavor;
- explicit unknown attendance and outcome values;
- no transcript or Commander content in revisions;
- canonical revision digest stability;
- append-only revision/event/acceptance/amendment database guards;
- accepted working-row and Endeavor-link immutability;
- meeting deletion and historical-heading restrictions; and
- concurrency failures leave status and official history unchanged.

### Authorization and confirmation

- each draft and official capability independently;
- `manage_settings` does not imply identity-bound official acts;
- approver and attester must be different users;
- passkey and email confirmation paths;
- wrong user/session/record/action/version/digest, expiry, reuse, revocation, and disabled
  user failures;
- stale confirmation causes no partial transition;
- no bearer-only official mutation; and
- exact agent execution/confirmation provenance when that later surface ships.

### Lifecycle and visibility

- every valid transition and every invalid transition;
- approval creates revision N and locks working content;
- attestation exposes only that revision to members;
- reopen preserves the superseded member-visible revision and creates revision N+1 only
  after another approval;
- acceptance requires a later same-body Meeting and does not require a fictitious motion;
- accepted-as-corrected atomically creates amendments;
- accepted minutes never reopen or delete; and
- amendment chains render without changing original text.

### Transcript and AI safety

- pasted and uploaded text limits, encoding, digest, and malware-safe content handling;
- restricted reads and deliberate purge;
- delete-after-acceptance scheduling and retained-source behavior;
- member, print, PDF, API-default, logs, and search leakage tests;
- transcript purge leaves official records intact;
- the OpenAI request uses the exact versioned prompt and strict output schema, disables
  tools, and sets `store: false`;
- response/request identifiers, model, token counts, prompt and source digests, and
  suggestion source ranges are recorded without copying transcript text into logs;
- suggestions move independently through unreviewed, used, edited, and discarded states;
- individual suggestion actions and the bounded attendance sheet update in place without
  losing scroll position, while retaining an ordinary HTML fallback;
- attendance review covers every snapshotted office, preserves explicit vacancies and
  unknowns, and records AI-matching versus human-corrected suggestion provenance;
- reruns preserve human edits and default to unresolved content rather than replacing the
  working draft;
- provider refusal, timeout, malformed output, and oversized-context failures leave the
  manual editor usable; and
- AI runs cannot approve, attest, accept, amend, or mutate Endeavors.

### Browser and document review

- complete AI-first historical Meeting workflow and manual fallback at desktop and 390px;
- source-pane selection, AI labels, use/edit/discard review, and the absence of a one-click
  accept-all path;
- keyboard-only editing, reordering, review, confirmation, and return focus;
- no horizontal overflow, clipped focus, or unreadable status text;
- draft/approved/attested/reopened/accepted/amended Meeting-page states;
- approval and attestation by two distinct test users;
- generated US Letter draft, attested, accepted, and amended PDFs;
- multi-page motion/outcome and amendment pagination; and
- grayscale readability and absence of restricted source/private cues.

Run the full Rails, system, RuboCop, Brakeman, Bundler Audit, and generated-document checks
before each minutes slice is considered complete.

## Implementation Sequence

1. Land this design and reconcile roadmap/capability language.
2. Add `MeetingMinutes`, structured sections/items/outcomes/attendance, Meeting constraints,
   and thorough model tests.
3. Add transcript paste/text upload with explicit retention, provider disclosure, and
   restricted access.
4. Implement agenda seeding and the complete manual editor as the safe working foundation.
5. Add the OpenAI Responses API provider, versioned prompt, strict structured output,
   draft-run provenance, and source-bound suggestion staging.
6. Complete the historical Meeting + agenda + transcript AI-first drafting and correction
   case, including provider failure/manual fallback.
7. Add immutable revisions, append-only lifecycle events, and the record/action/version-
   bound confirmation boundary.
8. Add Commander approval, distinct-person Adjutant attestation, member visibility, and
   transparent reopen behavior.
9. Add later same-body acceptance, correction amendments, and database-layer immutability.
10. Add the member document, shared print shell integration, and generated PDF verification.
11. Add draft API/handbook parity; add official-action API behavior only through confirmed
    pending actions with agent provenance.

## Deferred Decisions That Do Not Block Slice 2

- general member/guest attendance beyond the officer roll call;
- structured quorum calculations;
- vote-by-person and secret-ballot support;
- audio/video ingestion or automated transcription;
- multiple transcript/source files per Meeting;
- configurable transcript retention windows beyond the two explicit initial policies;
- document email distribution and receipt tracking;
- public records; and
- generalized amendment, evidence, or document-management infrastructure outside minutes.

Revisit these only when a real Post workflow establishes the need. None justifies weakening
the first implementation's structure, source separation, human authority, or immutability.

## Source Notes

- [The American Legion 2026 Officer's Guide and Manual of Ceremonies](https://www.legion.org/getmedia/9886852f-7570-4d04-85e8-2832116fdb63/27ia0226-post-officers-guide.pdf),
  especially records and minutes on page 23, the Adjutant role on page 29, and the
  suggested order of business on page 128.
- [The American Legion Post Adjutant's Guide](https://www.legion.org/getmedia/32a81555-9d40-460f-b236-01717f9d42ab/89ia0125-post-adjutants-guide.pdf),
  for the permanent-record and continuity context of the Adjutant's work.
- [OpenAI Responses API](https://developers.openai.com/api/reference/cli/resources/responses/methods/create),
  for stateless text input, versioned prompts, Structured Outputs, and `store` behavior.
- [GPT-5.6 Sol](https://developers.openai.com/api/docs/models/gpt-5.6-sol), for the initial
  flagship minutes-drafting model, reasoning levels, context window, and Structured
  Outputs support.
- [OpenAI API data controls](https://developers.openai.com/api/docs/guides/your-data),
  for training, application-state, abuse-monitoring, and approved retention-control
  distinctions.
- `docs/AMERICAN_LEGION_CONTEXT.md`, for the distinction among national guidance,
  Department/Post governing documents, local practice, and explicit application policy.
- `docs/ROLES.md`, for person, office, capability, agent, and fresh-human-intent
  boundaries.
- `docs/ENDEAVOR_GOVERNANCE.md`, for the separation between official Meeting records and
  durable Endeavor identity.
