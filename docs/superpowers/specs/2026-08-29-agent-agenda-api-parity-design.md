# Agent Agenda API Parity Design

**Status:** Approved for implementation August 29, 2026.

## Purpose

The officer-agent API must keep pace with the agenda work available to the signed-in
officer. This is especially important for historical reconstruction: an officer should be
able to give a delegated Bot the source business for a past meeting and have it create or
reuse Tracked Items, place them in the correct historical sections, and verify the dated
agenda without re-entering every item in the browser.

The Bot remains an agent of the signed-in person and receives no separate authority.
These endpoints use the existing `manage_agendas` capability, organization scoping,
session CSRF or bearer-token idempotency, draft locks, and official-record rules.

## August 28-29 audit

There were no August 28 commits on `main`. The seven August 29 commits have these API
consequences:

| Change | Agent consequence |
|---|---|
| Dated agenda deletion | Add an explicit destructive API action, listed only when asked. |
| Commander copy and officer roll call | Keep private wording controls, Commander cues, and the dated roll-call snapshot in agenda detail; add machine-editable roll-call identifiers and replacement/refresh actions. |
| Catalog ordering | Expose the current kept catalog and one complete-order mutation. Dragging and arrow controls remain browser interaction details. |
| Protected item removal | Expose dated-item removal and soft catalog removal as explicit destructive actions; never guess a DELETE route from the HTML UI. |
| Section-aligned agenda defaults | Teach the Bot that New Business and Unfinished Business are real sections, may be empty, and must be targeted by `dated_agenda_section_id`. They are not placeholder items. |
| Printed agenda presentation | No JSON mutation is needed. Agenda detail already supplies the structured content; member and Commander print layouts remain browser documents. |
| Dated officer-list editing | Expose complete replacement of the meeting-scoped snapshot and a separate reset to assigned officers as of the meeting date. Never substitute today's `/api/officers` list for a historical snapshot. |

## API additions

All routes are private and require `manage_agendas`.

### Agenda catalog

- `GET /api/agenda_item_catalog_entries` lists kept entries in category and position order,
  including document wording controls and Commander cues.
- `POST /api/agenda_item_catalog_entries` creates a reusable catalog item.
- `PATCH /api/agenda_item_catalog_entries/:id` edits a kept item.
- `POST /api/agenda_item_catalog_entries/reorder` accepts the complete ordered id list for
  every category. The existing model transaction validates completeness and uniqueness.
- `DELETE /api/agenda_item_catalog_entries/:id` performs the existing soft removal and is
  documented only when asked. Existing templates and dated snapshots remain unchanged.

### Dated agendas and items

- `DELETE /api/dated_agendas/:id` mirrors whole-record deletion and is documented only
  when asked. It may remove a draft, approved, or published agenda; linked Tracked Items
  remain.
- `PATCH /api/dated_agendas/:dated_agenda_id/items/:id` edits a draft snapshot's title,
  summary, document wording, Commander cues, display flags, item kind, section, or
  `tracked_item_id`.
- Changing `dated_agenda_section_id` appends the item to that section. Linking an existing
  active Tracked Item happens in place and therefore preserves the historical row's
  section, position, and wording without creating a duplicate.
- `DELETE /api/dated_agendas/:dated_agenda_id/items/:id` removes only a draft snapshot item
  and is documented only when asked.

### Dated roll call

- `GET /api/position_titles` lists active office ids and names needed to build a roll call.
- Agenda detail returns roll-call entry id, position-title id, person id, office snapshot,
  person-name snapshot, position, and vacancy state.
- `PATCH /api/dated_agendas/:dated_agenda_id/items/:agenda_item_id/roll_call` replaces the
  complete roll-call snapshot with an ordered array of `{position_title_id, person_id}`;
  a null person means `Vacant`.
- `POST .../roll_call/refresh` discards agenda-local edits and rebuilds from assignments
  active on the meeting date. It is documented only when asked.

The replacement endpoint accepts only active offices belonging to the installation and
directory-visible people, while retaining already-snapshotted people as selectable. It
uses the same model operation and draft lock as the browser editor.

## July 7 historical-business workflow

The Bot receives the officer's source list or source document. It must not invent business
from an empty section.

1. List dated agendas and select the exact July 7 start date, then fetch agenda detail.
2. Confirm the agenda is a draft. Reopen a locked agenda only on a live human instruction.
3. Read the ids of the existing `Unfinished Business` and `New Business` sections.
4. List Tracked Items before creating anything.
5. For each distinct matter:
   - reuse a matching active tracker when one exists;
   - otherwise create one using the supplied title, summary/details, body, importance, and
     deadline without inventing decisions or outcomes;
   - if a standalone dated item already represents the matter, link it in place with the
     dated-item PATCH;
   - otherwise add the tracker snapshot to the correct section using
     `dated_agenda_section_id`.
6. Preserve historical classification: a matter introduced as New Business on July 7
   remains in that July 7 section even if it is unfinished today. Current tracker status
   does not rewrite the past agenda's classification.
7. Re-fetch both the agenda and Tracked Items, and report created, reused, linked, and
   skipped matters. Do not approve or publish unless explicitly asked.

The newly synced local production copy demonstrates the required mixed case: the July 7
agenda has an already-linked Car & Bike Show item plus a standalone Buddy Checks item.
Linking Buddy Checks in place is the required no-duplicate behavior.

## Safety and error behavior

- List before create; match exact ids from live payloads.
- All writes to agenda items and roll call require a draft agenda and return 422 when
  locked or invalid.
- Bearer writes require a unique `Idempotency-Key`; exact retries reuse the same key.
- Deletion, catalog removal, roll-call refresh, agenda reopen, approval, and publication
  are listed under `only_when_asked` in the generated handbook.
- JSON errors use the existing 401/403/404/422 envelope. Cross-installation ids return 404.
- No endpoint accepts minutes, attendance outcomes, votes, attestations, or acceptance.

## Documentation strategy

`docs/agent-operator-skill.md` remains deliberately short and continues to route the Bot
to the generated signed-in `GET /api` handbook. The handbook is the live source for
endpoint examples, the historical-backfill workflow, current grants, and intentional
boundaries. The earlier officer-agent design links here for the post-August-29 surface.

## Verification

- Controller tests cover authorization, organization scoping, draft locks, in-place
  tracker linking, no-duplicate validation, destructive actions, catalog ordering/removal,
  and roll-call vacancies/replacement/refresh.
- Handbook tests prove every cataloged action maps to a real API route and that the guided
  workflow appears only for callers with `manage_agendas`.
- Focused tests run before the ordinary Rails suite; lint and security checks follow.
