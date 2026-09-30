# Discussion topics and Endeavor confirmation API

This is the private API equivalent of **Add discussion topic**, **Create Endeavor
from this discussion**, **Link existing / Change link**, and AI proposal
**Review and create / Edit proposal / Link existing / Dismiss**. The current,
permission-filtered `GET /api` handbook is the operational authority; this document
describes the local contract. See [discussion topics](AGENDA_DISCUSSION_TOPICS.md)
and [minutes confirmation](MINUTES_ENDEAVOR_CONFIRMATION.md) for product design.

## Authentication and authority

Use a personal agent bearer token with `Authorization: Bearer <token>`, or a signed-in
browser session. Bearer writes require a unique `Idempotency-Key` for each intended
mutation; exact retries reuse the same key and identical JSON. Changed input with a
used key returns `409`. Session writes require `X-CSRF-Token` from `GET /api`.
Do not print credentials or restricted transcript evidence in logs.

An agent acts with its human owner's current grants. Agenda topics require
`manage_agendas`. Minutes linking, changing links, and AI review require
`manage_minutes`; creating an Endeavor from minutes also requires `manage_agendas`.
The handbook advertises creation only when both grants are present, with
`all_capabilities` describing that requirement. An agent must obtain the human's
explicit identity decision before creating or linking continuing Post work. Neither
AI generation nor a read request creates or links an Endeavor. These operations do
not adopt a motion, approve minutes, attest, accept, or publish an agenda.

## Put a discussion on an agenda

Fetch `GET /api/dated_agendas/:id`. Select an exact section id from `sections`,
confirm `status` is `draft`, and use:

```http
POST /api/dated_agendas/:dated_agenda_id/items
```

```json
{
  "dated_agenda_section_id": 28,
  "title": "Explore a community breakfast",
  "behavior_type": "business_item",
  "body": "<p>Discuss interest, possible dates, and volunteer capacity.</p>",
  "commander_notes": "<p>Ask whether members want to explore the idea.</p>",
  "show_wording_on_agenda": true,
  "show_wording_in_minutes": true
}
```

The title, section id, and `behavior_type` are required. Optional wording and notes
accept sanitized HTML; use `<p>` and `<ul><li>` for structure. Omit `endeavor_id`
for an early discussion. The response is `201` with `dated_agenda_item`, including
its id, section, position, and `lock_version`. The item appends to the selected
section; no Endeavor, catalogue entry, or template identity is created. Commander
notes remain private and do not seed minutes.

Editing/removal use `PATCH`/`DELETE /api/dated_agendas/:dated_agenda_id/items/:id`.
Editing requires the current item version to detect another officer's changes.
Do not round-trip plain-text reads into rich-text `body` or `commander_notes` when
changing unrelated fields. Moving uses `dated_agenda_section_id`; reordering uses
`POST /api/dated_agendas/:dated_agenda_id/sections/:section_id/items/reorder` with
`dated_agenda_item_ids` containing every current active item in that section exactly
once. Approval/publication locks agenda edits; reopening is a separate deliberate act.

Create working minutes with `POST /api/meetings/:meeting_id/minutes` once, then fetch
`GET /api/meetings/:meeting_id/minutes`. The meeting must be in the past and the caller
must have `manage_minutes`. Seeding preserves item/section lineage and an
independent `agenda_wording` snapshot. Planned discussion is not evidence of adoption.

## Manual creation, reuse, or changing a link during minutes review

Read the exact minutes item from `minutes.sections[].items[]` and list
`GET /api/endeavors` before creating. Show the human the existing names and summaries;
similar names are not automatic proof of identity. The web form's starting text is
the item `title` and recorded `body`, falling back to `agenda_wording` when body is
blank. Ask the human to confirm the resulting title/description or an existing id.

```http
POST /api/meetings/:meeting_id/minutes/items/:item_id/endeavor
```

Create and link in one atomic request:

```json
{
  "endeavor_action": "create",
  "title": "Community breakfast",
  "body": "Plan the agreed recurring breakfast and recruit volunteers.",
  "lock_version": 0
}
```

The required title and optional plain description (`body`) become the Endeavor's
title and summary. The new Endeavor is active, with standard importance, and records
the human owner as creator. Do not separately `POST /api/endeavors` first; atomic
confirmation prevents orphaned creation if the minutes changed. Case/whitespace
normalized exact-title duplicates are rejected with guidance to reuse an existing
record. An item with a confirmed link cannot create another Endeavor through this flow.

Link existing or change the manual link:

```json
{
  "endeavor_action": "link",
  "endeavor_id": 5,
  "lock_version": 0
}
```

Both modes require the current **minutes item's** `lock_version`, not an Endeavor,
minutes parent, or AI run version. Creation returns `201`, linking `200`:

```json
{
  "item": { "id": 7, "endeavor_id": 5, "lock_version": 1 },
  "endeavor": { "id": 5, "title": "Community breakfast", "summary": "Plan the agreed recurring breakfast and recruit volunteers.", "status": "active" }
}
```

`item` contains the full ordinary minutes-item payload; the example omits its other
fields. Neither mode changes its wording, source agenda, outcomes, section, or order.
Fetch `/api/endeavors/:id` for full continuing-work details. All confirmation modes
require draft minutes, rechecked under the parent lock.

## AI proposals: inspect, confirm, correct, reuse, or dismiss

Request paid AI generation only on the person's direct instruction, using the current
handbook's transcript/run workflow. Generation stores `endeavor_proposal` suggestions
against exact existing minutes items. Unplanned business must first be reviewed into
a minutes item; a speculative item cannot receive an Endeavor link.

Read `GET /api/meetings/:meeting_id/minutes/draft_runs/:id`. Each suggestion exposes
`kind`, `minutes_item_id`, original `payload` (`title`, `body`, `reason`, optional
existing `endeavor_id`), confidence, missing facts, source range, and review state.
Explicitly append `?include_source=true` to receive `source_excerpt`, identical to the
web's numbered evidence ribbon. This restricted text is omitted by default, served
with `Cache-Control: no-store` when requested, and null after transcript purge.
The source ranges refer to normalized source lines; they are not raw file offsets.
Run detail and excerpts require `manage_minutes` and the same meeting/minutes scope.

After evidence review and a human identity decision, use the **suggestion** route so
the confirmation records reviewer/time and resulting record provenance:

```http
PATCH /api/meetings/:meeting_id/minutes/draft_runs/:draft_run_id/suggestions/:id/use
```

Send the same explicit create or link JSON shown above, using the target item's
fresh version. An empty use request is rejected. To correct title/description or
choose a different existing identity, send the corrected confirmation JSON to:

```http
PATCH /api/meetings/:meeting_id/minutes/draft_runs/:draft_run_id/suggestions/:id/edit
```

Both routes support switching proposed creation to reuse. They return `200` with
`suggestion` and complete `minutes`. The original AI payload remains unchanged;
`review_state` becomes `used` for unchanged confirmation or `edited` for corrected
text/identity, regardless of route name. `reviewed_by`, `reviewed_at`, and
`applied_record_type: "Endeavor"` / `applied_record_id` identify the confirmed result.
Already reviewed proposals and proposals whose item gained a confirmed link are
rejected. A later manual change of a link uses the minutes-item endpoint above; the
proposal ledger continues to describe its original confirmation.

Dismiss without creating or linking:

```http
PATCH /api/meetings/:meeting_id/minutes/draft_runs/:draft_run_id/suggestions/:id/discard
```

Send no confirmation fields. The response has `suggestion.review_state: "discarded"`
and complete minutes; reviewer/time and original payload remain in the ledger.

## Errors and recovery

Errors use `{ "error": "...", "details": [] }`.

| Status | Meaning and response |
| --- | --- |
| `401` | Sign-in/token missing, expired, or revoked. |
| `403` | Required current grant missing; manual creation requires both grants. |
| `404` | Meeting/item/run/suggestion missing or outside its parent/organization; manual link target missing/foreign. |
| `409` | Manual confirmation used a stale item version, or bearer idempotency key conflicts. Fetch current state, reconsider the human decision, then submit changed input with a new key. |
| `422` | Invalid action/title/version, duplicate identity, locked minutes/agenda, or rejected AI review. AI review also uses `422` for missing creation authority, stale versions, and foreign Endeavor identity; it leaves the proposal unreviewed and creates no partial record. |

After transport failure, replay identical bearer input with its original key; do not
generate another key for the same intended creation. A replay returns the original
response, which may contain an older version: fetch detail before further edits.
After a validation failure, correct the input and use a new key. Do not silently
replace a stale human decision with the latest version. Re-fetch minutes/run detail
after review and report unresolved facts; official actions remain separate.

## Local verification

Synthetic API tests cover standalone topics through minutes seeding, atomic manual
creation/reuse/change, draft/official locks, current grants, cross-scope rejection,
duplicate/stale/repeated requests, bearer replay/delegation, original source wording,
AI correction/reuse/dismissal and provenance, and explicit/purged evidence reads.
Handbook tests verify real routes, permission filtering, and JSON/Markdown guidance.
No paid provider call or real transcript is needed to exercise these contracts.

Verified locally September 30, 2026:

- Focused API coverage: 57 tests, 760 assertions, no failures/errors/skips.
- Full application suite: 1,074 tests, 7,955 assertions, no failures/errors/skips.
- RuboCop: 10 affected Ruby files, no offenses. Brakeman: 0 errors or warnings.
  Bundler Audit: no vulnerabilities. Documentation links/code fences and diff
  whitespace checked.
- This API addition changes no web UI; the preceding feature's desktop/390px browser
  review remains applicable. These local checks performed no development/production
  migration, paid AI request, or deployment.
