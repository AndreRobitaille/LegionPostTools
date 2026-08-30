# Architecture

This document summarizes current architecture and durable product decisions.

## Stack

- Ruby on Rails 8.1.
- PostgreSQL.
- Hotwire/Turbo with importmap.
- Tailwind CSS.
- Action Text is installed and present for planned rich text workflows.
- Active Storage is installed and present for planned file and artifact workflows.
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
- `PermissionGrant` controls application capabilities separately from official Legion office.

People can hold multiple positions at once. Position assignments must be historical so old records can show who held an office at that time.

## Roster-backed administration

National American Legion roster CSV imports populate read-only roster fields on people, keyed by Member ID. Roster data is dated and refreshed by later imports rather than edited locally. Login accounts remain separate: a person may or may not have a user, roster email remains separate from login email, and app permissions are granted to users rather than imported roster rows. Post positions and committee-lead-style roles are assigned to people with effective dates so officer history is preserved.

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
- `DatedAgendaItem#endeavor_id` is optional. A future structured minutes item may copy that
  identity deliberately when seeded, while preserving its own independent wording.
- Document-wording visibility and Commander-only cues follow the same catalog-to-template-to-dated
  snapshot boundary. Member documents never render Commander cues.
- Officer roll call is structured dated-agenda data. It snapshots assignments active on the
  meeting date so later officer changes cannot rewrite a historical working document; recorded
  attendance belongs to the minutes lifecycle.

## Official Records

Accepted official minutes must be immutable. No administrator override should silently edit accepted minutes.

Corrections should appear as later amendments or later meeting records linked back to the original record.

## AI Boundary

AI may draft minutes, summarize transcripts, suggest possible Endeavors, and help place discussion under the right agenda item. Humans confirm Endeavor identity.

AI output is never official. Humans review, approve, attest, distribute, and accept official records.

The signed-in user may also assign an agent (Grok Bot, later others) to operate
the existing app on their behalf. The generated standing brief identifies that
particular member and their current assigned office, if any. The agent uses a private
JSON surface and a generated handbook at `/api`. It is still not the authority on official records.
Group chat, email, and other outside channels stay in the agent’s own tools;
this app only stores post business.

The private API mirrors agenda data operations needed for delegated work: reusable catalog
maintenance, dated-agenda changes, standalone one-meeting rows, exact same-section item
ordering, Endeavor continuity, and meeting-scoped officer-list snapshots. Standalone
rows do not require catalog or Endeavor records; cross-section moves append and a separate
complete-order action establishes final document order. The API does not turn print
presentation into JSON or let today's officer directory silently overwrite a historical
roll call. Deletion, removal, snapshot reset, approval, publication, and reopen remain
explicit **only when asked** actions in the live handbook.

Provider-specific AI integration should stay behind replaceable service boundaries. OpenAI is expected first, but the domain should not depend directly on one provider.

See `docs/superpowers/specs/2026-08-22-officer-agent-operability-design.md` and
`docs/superpowers/specs/2026-08-29-agent-agenda-api-parity-design.md`.

## Deferred Architecture

Do not build these prematurely:

- Multi-tenant SaaS.
- Public API. The existing session-or-bearer JSON API remains private to signed-in users.
- MCP or a custom CLI until a client cannot use the private JSON handbook.
- Full accounting.
- Broad project management.
- Generic nonprofit feature set.
- Deep Legion Family legal relationship modeling.
