# Officer Agent Operability Design

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
- API tokens. Grok Bot signs in once on its Agent Computer (passkey or magic
  link, human takeover). The session cookie lasts until 180 days of inactivity.
  Tokens wait until a shell-only agent cannot use that cookie.
- Search, autocomplete, or synonym matching.
- Chat ingest, schedulers, or “scan the group chat” jobs inside Rails.
- Minutes, transcripts, PDF, or email distribution. When those exist, add them
  to the handbook; do not pretend they exist now.
- A dedicated weaker bot user. v1 uses the officer’s own user.
- Auto-approve, auto-publish, or any implied approve/attest/accept of minutes.
  `manage_settings` still does not imply those identity-bound acts.

## How the Bot starts

Standing instruction, given once to Grok Bot: paste
`docs/agent-operator-skill.md` in full. That file covers what the app is, this
installation's URL, passkey/magic-link sign-in (human takeover), the 180-day
session, and that every job starts by reading `/api`. Do not replace it with a
one-line "you are Commander, open /api."

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
controllers return JSON and call the same model methods the UI already uses
(`DatedAgenda.create_from_template!`, `DatedAgendaItem.create_from_tracked_item!`,
tracked-item create/complete/reopen/updates).

Suggested first resources (all under `/api`, all session + `can?`):

- `GET /api` — handbook
- `GET /api/meeting_bodies`
- `GET /api/meeting_types`
- `GET /api/dated_agendas` — upcoming first, include status and body/type
- `GET /api/dated_agendas/:id` — sections and items, including tracked-item links
- `POST /api/dated_agendas` — create **draft** from meeting type + body + `starts_at`
- `POST /api/dated_agendas/:id/tracked_items` — snapshot an existing tracked item onto a draft; 422 if locked or already present
- `GET /api/tracked_items` — active first; include raise-by, importance, usual body, upcoming-agenda ids
- `GET /api/tracked_items/:id`
- `POST /api/tracked_items`
- `POST /api/tracked_items/:id/updates`
- `PATCH /api/tracked_items/:id/complete` and `reopen`

Approve/publish/reopen of agendas may be exposed in this same phase because the
Commander already can in the UI, but the handbook must say: do not call them
unless the human asked. Prefer omitting them from the “common actions” list and
documenting them under “only when asked.”

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
- Do not invent minutes, votes, or attestations.
- Always list before creating, so the Car Show does not become a second tracked
  item.
- Chat content is not stored. Only post business the officer would have entered
  by hand.

## What later phases add

When minutes exist: handbook entries for draft/review, and still no silent edit
of accepted minutes.

When a shell-only agent appears: a personal access token in Settings › Security
and optional `curl` examples. Not before.

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
4. Leave approve/publish alone unless asked.

No group-chat feature ships. The morning routine is configured in Grok Bot, not
in Rails.
