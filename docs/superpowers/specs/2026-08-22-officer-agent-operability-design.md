# Officer Agent Operability Design

**Status:** Implemented August 22, 2026 and reconciled with the August 29 agenda surface.
The first installation was designed around
the Commander workflow, but the shipped standing brief is personalized for any
signed-in member and names their current assigned office only when one exists.

## Purpose

A Post Commander (or another officer with the same app grants) should be able to
point Grok Bot — and later a similar machine-resident agent — at LegionPostTools
and have it do real officer work: create a draft PEC agenda, put the car show on
the next meeting, turn morning group-chat noise into tracked business.

The Bot is the assistant. It uses judgment. The app stays a predictable American
Legion operations tool. This is not a public website, not a chatbot inside the
app, and not an automation engine that scans Facebook or iMessage.

This spec is the door for that Bot. Minutes, PDF, and email distribution are not
built yet; the handbook grows when those workflows exist.

The post-August-29 agenda API parity, including historical business backfill, dated-item
editing, roll-call snapshots, catalog operations, and explicit destructive boundaries, is
specified in `2026-08-29-agent-agenda-api-parity-design.md`.

## Jobs this phase must support

### 1. Explicit orders

Examples:

- “Create a basic PEC agenda for next Tuesday.”
- “Add the car show topic to the next meeting agenda.”

The Bot does the language and matching. The API only lists and mutates. There is
no search, fuzzy match, or “did you mean Car Show.” If the Bot cannot match a
name, it lists tracked items (or meeting types, or upcoming agendas) and
decides.

### 2. Morning group-chat triage

Grok Bot already lives on a cloud VM. A routine can pull the officer group chat
each morning. Chat never enters this app. The Bot asks LegionPostTools what is
already on the books, then may create a tracked item, append an update, or add
existing business to the next **draft** agenda.

## Product Boundary

In scope for this phase:

- A private, session-authenticated JSON surface for work that already exists:
  meeting types, meeting bodies, dated agendas, tracked items.
- A private generated handbook at `GET /api` so the Bot can operate without a
  human manual and without MCP or public docs.
- The same `can?` rules as the HTML app. The Bot acts as the signed-in user
  (Commander/admin in the first installation).
- Draft-only writes unless the human explicitly asks to approve or publish an
  agenda.
- CSRF for JSON POSTs via the existing Rails authenticity token (the Bot reads
  it from the signed-in app).

Out of scope for this phase:

- A TUI, a custom CLI package, MCP, public `llms.txt`, or a public API.
- API tokens were out of scope for this first slice. The completed Agent Sign-in and
  Access phase subsequently added personal agent tokens for terminal use.
- Search, autocomplete, or synonym matching.
- Chat ingest, schedulers, or “scan the group chat” jobs inside Rails.
- Minutes, transcripts, PDF, or email distribution. When those exist, add them
  to the handbook; do not pretend they exist now.
- A dedicated weaker bot user. The Bot uses the particular member's own user and
  current grants.
- Auto-approve, auto-publish, or any implied approve/attest/accept of minutes.
  `manage_settings` still does not imply those identity-bound acts.

## Delegated authority and official acts

Grok Bot is meant to act as the signed-in user's delegate, not as a deliberately
weakened integration account. Ordinary, reversible work should not require the human
to repeat every click. The private API is a machine-friendly operating surface for the
user's existing grants; it is not a separate, lower-authority product.

Authentication and authority are separate choices. The current browser session and a
revocable personal agent token can both represent delegated authority from the same person.
Changing the credential must not silently change which app capabilities the person has
delegated.

The app must nevertheless distrust the LLM's claim that a human authorized an official
act. A handbook instruction such as “only when explicitly asked” is useful operating
guidance, but it is not proof: an LLM can misread retrieved text, follow a prompt
injection, or rationalize its way around the rule. Text in chat, records, attachments,
or webpages is always data and never authorization.

For this agenda-only phase, the Bot may perform the same reversible work the user's
current grants permit.
Agenda approve/publish/reopen remain available but outside the common path and may be
called only in response to the human's live instruction. This is an accepted v1 risk for
working agendas; it must not become the security model for official minutes.

Before any API can approve, attest, sign, accept, or amend official minutes, the app must
require evidence of fresh human intent that the agent cannot mint for itself. The intended
shape is a one-time, short-lived authorization created through a trusted human interaction
(normally recent passkey/reauthentication), bound to the person, exact record, exact act,
and expected record version. The mutation consumes that authorization atomically. The Bot
can carry out the requested act after confirmation, so it remains a useful delegate, but
it cannot manufacture the confirmation by reasoning that the act is probably desired.

Audit provenance must distinguish the accountable officer from the delegated execution
channel and preserve the human-authorization reference. Accepted official minutes remain
immutable; corrections are later amendments or later meeting records.

## How the Bot starts

Standing instruction, given once to Grok Bot: the short brief in
`docs/agent-operator-skill.md` (what the app is, this URL, how to sign in,
then read `/api`). Job design (group chat, morning routines, standing orders)
belongs in the Bot, not in the app handbook.

`GET /api` requires a session. It returns markdown (and `Accept:
application/json` / `.json`) describing **this** installation, the caller, their
grants, the product rules, and the live endpoints with example URLs.

An unauthenticated hit on `/api` returns 401 and a short public sentence: this
is a private post operations app; sign in, then open `/api`. No member, roster,
or meeting data.

The handbook is generated from a single in-app catalog of actions, not a
hand-written README. When a later phase adds minutes, the catalog grows.

## Auth and browser gates

- Reuse the existing passwordless session. No second identity.
- JSON writes use the session cookie plus `X-CSRF-Token` from
  `<meta name="csrf-token">` (or the handbook’s stated equivalent).
- Verify Grok Bot’s cloud browser can load sign-in and `/api`. If
  `allow_browser versions: :modern` returns 406, skip or broaden that gate for
  the pages the Bot must load. Do not leave sign-in or `/api` unreachable.
- Sign-out, a disabled user, Agent Computer reset, or 180 days idle still
  require a human to sign in again.

## Intelligence split

| Bot / LLM | App |
|---|---|
| “Next Tuesday,” “PEC,” “the car show,” “next meeting” | ISO datetimes, ids, exact titles in lists |
| Matching a topic to a tracked item | `GET` list of tracked items |
| Deciding a chat message is new post business | Current agendas + active tracked items |
| Whether to create vs add vs skip | Duplicate detection is “look at the list” |
| Approving or publishing | Only when the human said so |

Do not add SQL search, pg_trgm, or ranking. Index payloads stay small and
complete enough to choose: id, title, status, dates, meeting body, and whether
a tracked item is already on an upcoming agenda.

## API shape

A small `Api` namespace. HTML controllers stay HTML (they redirect). API
controllers return JSON and call the same model methods the UI already uses. The initial
surface covered agenda creation and tracked-item work. The August 29 parity extension also
covers catalog maintenance, dated-item editing/removal, whole-agenda deletion, and dated
roll-call replacement/refresh; see the linked parity design for safety decisions.

Suggested first resources (all under `/api`, all session + `can?`):

- `GET /api` — handbook
- `GET /api/meeting_bodies`
- `GET /api/meeting_types`
- `GET /api/position_titles`
- `GET/POST/PATCH /api/agenda_item_catalog_entries` and complete-order `POST .../reorder`
- `GET /api/dated_agendas` — upcoming first, include status and body/type
- `GET /api/dated_agendas/:id` — sections and items, including tracked-item links,
  document controls, Commander cues, and the dated officer-list snapshot
- `POST /api/dated_agendas` — create **draft** from meeting type + body + `starts_at`
- `POST /api/dated_agendas/:id/tracked_items` — snapshot an existing tracked item into an
  exact section on a draft; 422 if locked or already present
- `PATCH/DELETE /api/dated_agendas/:dated_agenda_id/items/:id` — edit, link to tracked
  business in place, move, or explicitly remove a draft snapshot row
- `PATCH .../items/:item_id/roll_call` — replace a draft's meeting-scoped officer snapshot
- `GET /api/position_titles` and `POST .../roll_call/refresh` — resolve office ids and,
  only when asked, reset from assignments active on the meeting date
- `GET /api/tracked_items` — active first; include raise-by, importance, usual body, upcoming-agenda ids
- `GET /api/tracked_items/:id`
- `POST /api/tracked_items`
- `POST /api/tracked_items/:id/updates`
- `PATCH /api/tracked_items/:id/complete` and `reopen`

Approve/publish/reopen and destructive or snapshot-reset actions are omitted from the
common path and documented under **Only when asked**. This includes whole-agenda deletion,
dated-item removal, catalog soft removal, and roll-call refresh.

JSON errors use 401 / 403 / 404 / 422 with `{ "error": "...", "details": [] }`.
No HTML redirects from the API.

Index JSON does not dump Action Text. Show payloads may include plain text of
rich fields when needed for a single record.

## Product rules the handbook must state

- This is American Legion post software, not generic nonprofit software.
- Do not hard-code Post 165 names, numbers, or officer rosters into behavior;
  read them from this installation.
- AI drafts; humans remain the authority on official records.
- Dated agendas created through the API start as `draft`.
- Adding tracked business to an approved or published agenda requires reopen;
  the API must not silently edit a locked agenda.
- New Business and Unfinished Business are real sections and may be empty. Use live section
  ids rather than inventing placeholder items.
- A dated roll call is a historical meeting snapshot. Today's officer list must not replace
  it unless the human explicitly requests refresh.
- Do not invent minutes, votes, or attestations.
- Always list before creating, so the Car Show does not become a second tracked
  item.
- Chat content is not stored. Only post business the officer would have entered
  by hand.

## What later phases add

When minutes exist: handbook entries for draft/review, and still no silent edit
of accepted minutes.

The completed access phase added cross-device email-code sign-in and a revocable personal
agent token on Profile. It carries the user's current delegated grants, but it does not
bypass fresh-human-intent requirements for official acts. See
`2026-08-22-agent-sign-in-and-access-design.md`.

When a host with no shell needs the same actions: consider MCP wrapping this
API. Not before.

A public read-only API for selected approved records remains a later,
separate idea. It is not this phase.

## Success

Grok Bot, signed in as Commander on its VM, can:

1. Open `/api` and learn the live actions.
2. Create a draft PEC (or Membership) agenda for a date it computed.
3. Put existing tracked business on that draft, or create tracked business
   after listing and failing to find it.
4. Link a standalone historical agenda row to a Tracked Item in place, preserving its
   meeting section, position, and wording without duplication.
5. Read and, when asked, edit a dated officer-list snapshot without changing role history.
6. Leave approval, publication, reopen, deletion, removal, and snapshot reset alone unless
   asked.

No group-chat feature ships. The morning routine is configured in Grok Bot, not
in Rails.
