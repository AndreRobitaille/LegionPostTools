# Architecture

This document summarizes current architecture and durable product decisions.

## Stack

- Ruby on Rails 8.1.
- PostgreSQL.
- Hotwire/Turbo with importmap.
- Tailwind CSS.
- Action Text stores rich content inside structured agenda, Endeavor, and minutes records.
- Active Storage supports roster-import source files and constrained transcript text files.
- Solid Queue for background jobs.
- Docker and Kamal for deployment.

## Installation Model

LegionPostTools is currently configured for one organization at a time. It is not a SaaS or multi-tenant platform today.

The schema leaves room for future configurable organizations or units so an American Legion Family deployment could eventually share one installation. Do not deeply model every legal relationship between Post, Auxiliary, Sons, and Riders yet.

## Runtime / Data Topology

Production uses a primary PostgreSQL database plus database-backed cache and queue storage. Rails defaults are used for Solid Queue and Solid Cache, and background jobs run against the database-backed Rails infrastructure.

## Identity Model

- `Person` is the real human being.
- `User` is login access for a person.
- `PositionTitle` defines configurable offices or roles.
- `PositionAssignment` records that a person held a position for a date range.
- `PositionCapabilityGrant` lets a configured office supply narrow application capabilities
  while a dated assignment is current.
- `PermissionGrant` records manual per-user capabilities for duties that do not arise from
  a current office.

People can hold multiple positions at once. Position assignments must be historical so old records can show who held an office at that time.

## Roster-backed administration

National American Legion roster CSV imports populate read-only roster fields on people,
keyed by Member ID. Roster data is dated and refreshed by later imports rather than edited
locally. Login accounts remain separate: a person may or may not have a user, and roster
email remains separate from login email. Effective capabilities may come from explicit
user grants or configured current position assignments, never from imported roster rows.
Post positions and committee-lead-style roles are assigned to people with effective dates
so officer history is preserved.

Administrators can synchronize current Active and Grace roster members to the Post's Loops audience after reviewing exclusions for missing, invalid, or shared roster email addresses. The Loops upsert sends roster identity fields but never sends subscription state, user group, or mailing-list choices, preserving existing opt-outs and audience organization. See `docs/LOOPS_ROSTER_SYNC.md`.

## Authentication

Authentication is passwordless.

- Passkeys are preferred.
- The fallback login email contains both a one-click link and a browser-bound
  eight-digit code; either one consumes the same single-use challenge.
- Passwords are intentionally not supported.

The flow is complete end-to-end (registration, sign-in, and passkey management). See
`docs/superpowers/specs/2026-07-11-authentication-flow-design.md`.

- Each user has a stable, opaque, base64url `webauthn_id` used as the WebAuthn user handle —
  never the sequential primary key (which is PII/enumerable and not valid base64url).
- Passkeys require a secure context (HTTPS or `localhost`); they are feature-detected and
  disabled otherwise, always leaving the link-or-code email fallback available.
- Email delivery is swappable behind the `MailDelivery` seam (`MAIL_PROVIDER`); the WebAuthn
  relying-party origin/id are environment-configured (`WEBAUTHN_*`).
- Personal agent tokens are named, expiring, revocable bearer credentials. Only a digest
  is stored, creation requires recent human authentication, and API authorization always
  re-evaluates the owner's current grants.

Disabled users must not be able to create new sessions through magic links, passkeys, or existing session cookies.

## Setup

The first-run setup wizard creates the first organization, first person/user, management permissions, meeting bodies, and the American Legion Post preset.

Setup completion is persisted through `Installation`. Once setup is complete, anonymous setup must not reopen even if all admins are later disabled or permission grants are changed.

## Meeting Architecture Direction

Meeting records are the core product direction.

- `MeetingBody` represents recurring groups such as Post Executive Committee or Membership Meeting.
- Agenda templates and dated agendas contain structured sections, with agenda items scoped and ordered inside each section.
- Agenda items are structured records, not one large freeform document.
- Rich text belongs inside structured records for notes, bullets, ceremony text, and printable context.
- `Endeavor` is the durable identity for coherent Post work such as a Car Show, Buddy
  Checks effort, election, or ceremony. Its officer updates are append-only, and meeting
  appearances form a continuity record across meetings.
- Adding an Endeavor to a dated agenda creates an independent agenda-item snapshot. Later
  Endeavor edits cannot silently rewrite an approved or published agenda.
- `DatedAgendaItem#endeavor_id` is optional. A structured minutes item may copy that
  identity deliberately when seeded, while preserving its own independent wording.
- Document-wording visibility and private Commander cues follow the same
  catalog-to-template-to-dated snapshot boundary. Member documents never render those
  cues; only a current configured Commander or Adjutant may open the combined notes PDF.
- Officer roll call is structured dated-agenda data. It snapshots assignments active on the
  meeting date so later officer changes cannot rewrite a historical working document; recorded
  attendance belongs to the minutes lifecycle.
- `MeetingMinutes` is the one structured working record for a Meeting. Its independently
  ordered sections, items, outcomes, attendance rows, heading snapshots, agenda lineage,
  and direct Endeavor links remain relational rather than collapsing into one document.
- `MeetingTranscript` is restricted source evidence owned by the Meeting. Content is kept
  out of member views, print, routine serializers, logs, and Jobs responses.
- `MinutesDraftRun` is the durable authority for each background OpenAI attempt. Suggestions
  are source-linked review records; using, editing, or discarding them never turns AI output
  into an official record. Retry creates a linked attempt and discard preserves history.
- The minutes PDF follows the record lifecycle. Draft output is an officer-only proof from
  mutable working rows; approved and attested output renders the immutable approved
  revision with a truthful authority label. Agenda wording and Recorded minutes remain
  visually distinct, motions remain structured, and direct Endeavor navigation metadata
  does not print.

## Official Records

Membership-approved official minutes must be immutable. No administrator override should
silently edit them.

Corrections adopted during original membership approval belong directly in the corrected
minutes revision. Corrections discovered after membership approval appear as later
amendments or later meeting records linked back to the original record.

Approved minutes revisions are immutable structured artifacts. Attestation exposes one
exact revision to members while it awaits later same-body membership approval; reopening
preserves that superseded revision rather than rewriting what members previously saw.
Membership approval records the procedure that actually occurred and does not require
every Post to use a motion. See `docs/MINUTES_LIFECYCLE.md`.

## AI Boundary

AI may draft minutes, summarize transcripts, suggest possible Endeavors, and help place discussion under the right agenda item. Humans confirm Endeavor identity.

AI output is never official. Humans remain responsible for review, approval, attestation,
distribution, and membership-approval recording. A delegated agent may execute an exact act the human
explicitly requests within that person's current capability; the audit record identifies
the agent-token execution.

The signed-in user may also assign an agent (Grok Bot, later others) to operate
the existing app on their behalf. The generated standing brief identifies that
particular member and their current assigned office, if any. The agent uses a private
JSON surface and a generated handbook at `/api`. It is still not the authority on official records.
Group chat, email, and other outside channels stay in the agent’s own tools;
this app only stores post business.

The private API is the machine-friendly operating surface for a bot or agent acting for
the authenticated person. It mirrors ordinary officer/admin work that exists in the app:
account access controls; Meeting and agenda operations; Endeavor continuity; restricted
transcript attachment/read; structured draft-minutes editing; roster-backed motion and
attendance review; durable AI runs; Jobs status; and lifecycle-aware minutes-PDF retrieval.
It uses the same
current capabilities as HTML, session CSRF or bearer idempotency, organization scoping,
optimistic locks, and agent-execution provenance. It does not turn print presentation into
JSON or let today's officer directory silently overwrite a historical snapshot.

AI transmission/retry, account-control changes, deletion, removal, snapshot reset, agenda
approval/publication, minutes approval/attestation, and reopen are explicit **Only when
asked** actions in the live handbook. Minutes approval and attestation use the same human
capabilities in HTML and bearer-token API calls. Bearer writes remain idempotent and record
delegated-agent provenance. Acceptance, amendments, and minutes reopen remain unimplemented.

Provider-specific AI integration should stay behind replaceable service boundaries. OpenAI is expected first, but the domain should not depend directly on one provider.

See `docs/superpowers/specs/2026-08-22-officer-agent-operability-design.md` and
`docs/superpowers/specs/2026-08-29-agent-agenda-api-parity-design.md`, and
`docs/superpowers/specs/2026-08-31-agent-minutes-api-parity-design.md`.

## Deferred Architecture

Do not build these prematurely:

- Multi-tenant SaaS.
- Public API. The existing session-or-bearer JSON API remains private to signed-in users.
- MCP or a custom CLI until a client cannot use the private JSON handbook.
- Full accounting.
- Broad project management.
- Generic nonprofit feature set.
- Deep Legion Family legal relationship modeling.
