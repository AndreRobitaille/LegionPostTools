# Agent Minutes and Recent-Workflow API Parity Design

**Status:** Implemented August 31, 2026; approval/attestation parity extended by
`docs/MINUTES_APPROVAL_AND_ATTESTATION.md` later that day.

## Purpose

The private officer-agent API last received complete workflow parity when first-class
Meetings shipped. Since then the application added roster-controlled login access,
structured draft minutes, restricted transcripts, OpenAI-assisted drafting and human
review, durable background runs, a Jobs ledger, and a print-ready draft-minutes PDF.

This change brought the private API and generated `/api` handbook up to the then-proven
draft HTML workflow. The later approval/attestation slice added direct, idempotent bearer
actions using the same person's explicit capabilities and lifecycle provenance. AI output
does not become authoritative; the agent remains the person's delegate.

## Safety boundary

- `manage_minutes` may create and edit working draft minutes, add a transcript, request an
  AI drafting run, review suggestions, and manage failed drafting runs.
- `view_internal_records` may read minutes and transcript sources but may not mutate them.
- `manage_settings` keeps its existing implied technical-support access, including
  `manage_minutes`, but never gains identity-bound approval, attestation, or acceptance.
- Transcript content is returned only by an explicit transcript request with
  `include_content=true`. It is never embedded in Meeting, minutes, Jobs, or handbook
  payloads and remains filtered from logs and idempotency fingerprints.
- Minutes mutations require `status=draft`, preserve optimistic locking, stay scoped to
  the installation and exact Meeting, and use existing bearer idempotency/provenance.
- AI suggestions remain proposals. An API caller must explicitly use, edit, or discard
  each proposal; no generation response directly rewrites working minutes.
- Approval and attestation are now exact **Only when asked** bearer actions with explicit
  capabilities, current content/revision digests, idempotency, and agent-token provenance.
  Reopen, acceptance, amendments, and transcript purge remain unavailable.

## Meeting and account parity

Meeting list/show becomes available to callers with `manage_agendas`, `manage_minutes`, or
`view_internal_records`, matching the administration workspace. Meeting create/update/
delete remains `manage_agendas`. Meeting payloads summarize optional agenda, transcript,
and minutes state without transcript content or draft body text.

Roster imports already apply eligible login access automatically and therefore require no
new API endpoint. The existing administrator-only manual account controls do require
parity:

- show account state for one exact Person;
- create or enable sign-in with a supplied login email;
- explicitly disable sign-in; and
- return a roster-backed account to roster control.

Account detail distinguishes `manual_capabilities`, current
`position_capability_sources`, and `effective_capabilities`. The legacy `capabilities`
field remains a compatibility alias for manual grants.

These actions require `manage_settings`. Disabling sign-in and changing control mode are
listed only under **Only when asked**, retain the last-enabled-administrator protection,
and never alter imported roster fields.

## Minutes resources

All paths are private and nested under an exact Meeting so a caller cannot confuse records
from different occurrences.

### Transcript

- `GET /api/meetings/:meeting_id/transcript` returns restricted metadata. Content appears
  only with `include_content=true` and `manage_minutes` or `view_internal_records`.
- `POST /api/meetings/:meeting_id/transcript` accepts one UTF-8 `transcript_content` value
  plus an explicit retention policy. JSON parity intentionally supports pasted text; the
  HTML form remains the path for a browser file upload.

There is no update or purge endpoint in this slice.

### Working minutes

- `GET /api/meetings/:meeting_id/minutes` returns the complete structured working record:
  heading, attendance, sections, items, snapshotted agenda wording, narrative, outcomes,
  source ids, Endeavor links, positions, and lock versions.
- `POST /api/meetings/:meeting_id/minutes` uses the same idempotent Meeting-boundary seeding
  operation as HTML.
- `PATCH /api/meetings/:meeting_id/minutes` edits only the draft heading and venue.
- `GET /api/meetings/:meeting_id/minutes/print` renders the same lifecycle-aware PDF as the
  browser workspace. Draft output uses mutable working rows; approved and attested output
  uses the immutable approved revision. Rendering never changes lifecycle state.
- Minutes detail exposes this endpoint as `pdf_path`. The legacy `draft_pdf_path` remains
  as a compatibility alias while delegated clients migrate.

### Structured editing

- Create, update, and remove draft sections; a section with items and the final remaining
  section cannot be removed.
- Create, update, move, and remove draft items. `body` is minutes narrative;
  `agenda_wording` is a read-only source snapshot and cannot be overwritten through the
  item API.
- Create, update, and remove structured outcomes with roster-backed mover/seconder ids,
  explicit unidentified flags, and the persisted disposition codes. API payloads also
  supply plain-language labels such as **Passed** and **Did not pass**.
- Update attendance statuses in one transaction using exact row ids and lock versions.
- Reorder sections, items within one exact section, and outcomes within one exact item by
  submitting every current id exactly once. Partial or cross-parent orders are rejected.

Destructive draft row removal is reversible only by re-entry and is therefore listed only
under **Only when asked**. Reorder is ordinary draft work.

## AI drafting and review

- List and show durable draft runs, including model/provenance metadata, status, token
  counts, review counts, retry/discard state, and suggestions after a successful run.
- Request a run only when minutes are draft and an available transcript exists. Enqueue
  failure becomes a durable failed run just as in HTML.
- Review one suggestion through explicit `use`, `edit`, or `discard` actions using the same
  review service as HTML. Outcome edits accept the same roster-identity fields.
- Save the run's suggested attendance sheet through the same review service as HTML.
- Retry a failed run by creating a linked new run; never mutate the failed attempt.
- Discard a failed run from attention or restore it while preserving history.

The generated handbook must emphasize that requesting AI drafting sends the restricted
transcript to the configured OpenAI API under the documented retention disclosure. An
agent should request it only on the person's direct instruction.

## Jobs ledger

`GET /api/jobs` mirrors the Jobs page without exposing Solid Queue internals or exception
text. It returns queue availability/heartbeat summary, counts needing attention, recent
minutes runs visible to a minutes manager, and Loops roster-sync summaries only for a
settings administrator. Retry/discard/restore remain the minutes-run actions above.

## Handbook and documentation contract

The generated handbook is the canonical live API manual. In the same change:

- replace all statements that minutes or transcripts are not built;
- describe draft minutes, transcript, attendance, outcomes, AI proposals, and Jobs in the
  domain glossary and field guidance;
- add a guided transcript-to-reviewed-draft workflow;
- classify transcript upload, AI run request, account control, and destructive draft-row
  changes under their proper authority boundary;
- document approval and attestation under **Only when asked**, while keeping reopen,
  acceptance, and amendments explicitly unavailable;
- update the operator design, architecture, roadmap, README, Meeting foundation, minutes
  lifecycle, user-management guide, deployment notes, and documentation maps to match the
  implementation; and
- prove every catalog action resolves to a real API route.

## Verification

- Controller tests cover session and bearer writes, idempotency, permissions,
  organization/Meeting scoping, draft locks, optimistic conflicts, exact reorder rules,
  transcript-content opt-in, AI review, failed-run recovery, PDF output, account safety,
  and handbook route reality.
- Existing agenda API tests remain unchanged in behavior.
- Full Rails, system, RuboCop, Brakeman, and Bundler Audit checks pass before handoff.
