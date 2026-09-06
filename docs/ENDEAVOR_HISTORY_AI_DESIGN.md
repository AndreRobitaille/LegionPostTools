# Endeavor history and AI-assisted member updates


**Implementation note:** the local implementation and its exact operational boundaries are
documented in [Endeavor AI history](ENDEAVOR_HISTORY_AI.md). This document preserves the
planning rationale; current implemented behavior supersedes proposed storage/staging details.

**Status:** design rationale for the local implementation, September 6, 2026.
A bounded [live evaluation](ENDEAVOR_HISTORY_AI_LIVE_EVALUATION.md) has passed locally.
Production historical association writes and release have not been performed. This design supersedes the exploration's suggestion to defer AI.

## Product decision

Deliver one feature with three member-facing layers:

1. A short **At a glance** overview of the Endeavor across meetings.
2. Dated **History** entries with focused summaries of what happened at each meeting.
3. The relevant original passages and complete recorded outcomes, available beneath
   each summary and linked to the full member-visible minutes.

AI discovery must consider the entire member-visible minutes revision, not only items
already linked to the Endeavor. A report can contain substantive information about more
than one Endeavor. AI establishes evidence associations automatically after validation. Human authority
continues to govern creation, merging, splitting, and redefinition of Endeavors.

The first version includes AI discovery, per-meeting summaries, and a cross-meeting
overview. Building the source foundation before generation is an engineering dependency,
not a separate release waiting for additional meeting data.

## Evidence from the available data

Read-only inspection of the local development database found two member-visible records:
July 7 (membership-approved) and September 1 (attested), with 35 items each. Recorded
bodies plus outcome text contain approximately 1,245 and 1,460 words respectively,
excluding agenda wording, attendance, and motion attribution/vote metadata. This is a
local snapshot, not a complete or current production inventory.

The examples establish requirements; their private source text is not copied into fixtures.

| Example | Required behavior |
| --- | --- |
| Car & Bike Show | Find donor outreach in the July Adjutant report and flag-raising arrangements in September's Honor Guard report. Preserve September's Finance motion allocating half the show's profit to the CD, despite no direct Endeavor link on that report. |
| Newsletter | Explain the progression from an election-related hold to an unrecoverable draft and lack of a coordinator. Attribute the recommendation to continue holding; do not invent a membership vote or cancellation. |
| Ethnic Fest | Preserve the scheduled planning meeting, volunteer shortage, and unconfirmed electrical service. Do not turn an expectation into a confirmed arrangement. |
| Officer election | Include the separate term-length votes: a two-year proposal lost and a one-year term was adopted. Candidate speeches need less prominence than results, without deleting their source text. |

The July Car Show item title also contains a date that does not agree with September's
event wording. Preserve the historical title, distinguish meeting date from event date,
and flag the discrepancy rather than silently correcting or synthesizing a date.

## Lessons from TwoRiversReporter Topics

Reviewed local documentation and code in `/home/andre/Development/TwoRiversReporter`.
These are reference patterns, not a dependency or a claim about that app's production state.

| Reference | Useful lesson | Legion adaptation |
| --- | --- | --- |
| `docs/plans/2026-02-21-topic-briefing-architecture-design.md`; `app/jobs/topics/generate_topic_briefing_job.rb` | A per-meeting summary and cross-meeting briefing serve different reading needs; generation follows source changes. | Keep both layers; upcoming agenda appearances render without AI. |
| `app/services/topics/summary_context_builder.rb`; `recent_item_details_builder.rb` | Agenda titles alone produced vague briefings until substantive item details reached the prompt. | Feed exact immutable recorded bodies and outcomes; trace content through every stage. Use item keys, not normalized titles, for identity. |
| `lib/prompt_template_data.rb`, `analyze_topic_briefing` | Explicitly request one factual entry per distinct event; otherwise chronology can collapse into a few headline events. | Preserve an evidence-backed fact list separately from concise prose. Output length is not permission to drop required facts. |
| `app/jobs/summarize_meeting_job.rb#validate_analysis_json` | Validate citations against a supplied set. The reference implementation drops invalid claims. | Reject an incomplete/invalid candidate for publication and expose the problem; silently dropping claims could conceal loss. Valid IDs alone do not establish that a claim is supported. |
| `docs/topics/TOPIC_GOVERNANCE.md` | Durable identity, evidence, and uncertainty matter. | Keep human-defined Endeavor identity and a neutral member-service voice. Do not import civic editorial analysis or automatic importance/lifecycle inference. |
| `app/services/topics/meeting_reanalysis_service.rb` | Reanalysis affects links, summaries, and downstream briefings. | Append new candidates/editions and compare changes. Never delete existing valid associations before re-extraction succeeds. |

Do not port Topics' vector retrieval, general knowledge sources, auto-creation/triage,
image generation, separate AI rendering call, or in-place briefing overwrite. Legion
already has structured source records and a small corpus. Server-render structured output
directly. Reuse the *patterns* of durable jobs, versioned prompts, citations, and validation.

## Scope and authority

- Sources: selected member-visible minutes revisions within one organization. Published
  agendas supply planned appearances, not evidence of completed discussion or decisions.
- Officer updates remain attributed history entries; exclude them from initial AI inputs.
  This keeps meeting evidence and between-meeting reports distinguishable.
- Never include transcripts, draft minutes, internal notes, roster data, or generated
  minutes suggestions. No browsing/tools or outside knowledge are needed for generation.
- No automatic Endeavor creation, merge/split, completion, assignment, or official act.
- Proposed management capability: `manage_agendas`, matching existing Endeavor management.
  This includes users receiving that capability through app administration, not only
  titled officers. Use current `can?` checks in HTML, API, jobs, and publication actions.
  The capability does not grant private minutes access or official approval authority.
- **User-selected policy:** automatic discovery, evidence association, summarization, and
  publication. No routine source confirmation or summary approval step. Admin tools handle
  reruns, corrections, and clarifying guidance when needed.
- This explicitly revises the prior human-confirmation requirement for *derived evidence
  associations to existing Endeavors in this workflow*. It does not authorize AI to change
  the primary identity in a minutes item, create an Endeavor, merge/split one, or alter
  official records. Update the governance document with this narrow distinction when
  implementing it; do not broaden the exception to unrelated identity operations.

## Member page and admin tools

Retain Endeavor title, human-written purpose summary, active/completed state, and context.
The existing purpose summary is not overwritten by generated text.

```text
CAR & BIKE SHOW                          Still tracking
Human-written purpose of this Endeavor

AT A GLANCE
[Brief overview of recorded progress]
Based on minutes through [date] · AI-generated overview · View sources

COMING UP
[Date] · [Meeting body]                  View published agenda

HISTORY
[Date] · [Meeting body] · Awaiting membership approval
[Focused meeting summary with source links]
Recorded decisions
  [Exact relevant motion, disposition, and vote details]
Read source passages [expand]            View full minutes

[Earlier meeting / attributed officer update]
```

Overview target: roughly 80–150 words when warranted, shorter for sparse evidence. Meeting
summaries target 40–100 words, with additional fact bullets when needed. These are layout
targets, not hard deletion limits. Exact decisions remain visible beneath summaries.
Source passages open in place; full source items are available for surrounding context.
Use **Reported next steps** only for source-supported commitments; do not imply current
tasks or assignments after the recorded meeting date.

History groups all validated passages by meeting, retaining source item order. It includes
minutes-only business and deduplicates agenda/minutes appearances. Past agenda-only entries
say **Listed on the agenda**, never “Discussed.” Future published appearances appear
earliest first, including real future appearances for completed Endeavors.

Empty/failure states remain useful: a validated direct source entry can appear without AI
prose; no substantive record says **No discussion or outcome recorded for this item**;
unmatched history says **No linked minutes entry available**. Generation errors belong in
the management workspace, not member-facing technical notices.

### Automatic workflow and admin recovery

1. When a revision becomes member-visible, queue discovery for the complete revision and
   the organization's existing Endeavors. Validate and automatically verify its proposed
   associations and facts against the full input before activating them.
2. Generate and verify meeting summaries plus an overview for each affected Endeavor.
   Publish a valid edition automatically and atomically. Failed work does not replace a
   valid edition; stale or ineligible source content is still suppressed immediately.
3. Offer **AI history** from Endeavor management, gated by `manage_agendas`. Show source
   coverage, latest runs, usage, safe failure reasons, current edition, and prior editions.
4. Provide **Rerun this meeting** and **Refresh this Endeavor** with an exact scope preview.
   The former rescans the full selected member-visible revision; the latter rescans all
   currently member-visible meetings for that Endeavor, including previously unmatched
   ones, before resynthesizing its full history. Offer retry of a failed attempt separately.
5. Let the manager add versioned **Clarifying guidance**, such as which annual event this
   Endeavor represents, known alternate wording, or why a similarly named event is unrelated.
   Show the guidance used for each run and allow replacement/reset. It is matching and
   presentation guidance, not evidence of decisions or events. New facts still require a
   minutes citation. Reject requests to invent facts, disclose private records, or bypass
   source/validation rules. Guidance is escaped data supplied under fixed system rules.
6. Provide **Report a problem / rerun with guidance** and **Withdraw generated overview**
   for managers. Preserve prior editions, guidance versions, run results, and the reason.
   Withdrawal suppresses publication until the manager explicitly resumes automatic updates
   or publishes a successful recovery run; a scheduled job must not undo it.

Ordinary members need no AI controls or workflow knowledge. Success happens automatically.
Failures use bounded automatic repair/retry and then appear in Jobs/admin tools; there is
no mandatory human review step for successful runs. The UI must not claim a person reviewed
prose merely because that person supplied guidance or requested a rerun.

### Visual direction

Apply the frontend-design skill and The 1919 system: navy `#0A2240`, gold `#C6A15B`, cream
`#F4EEDD`, paper `#FBF7EC`, ink `#1B222B`. System sans for summaries and controls; Georgia
only inside bounded original-document excerpts. Reuse shared section headers, status
words, date treatments, cards, and existing column widths. The signature element is
the dated meeting entry tying a concise account to its exact evidence and authority.

Desktop: history in the main column, secondary facts in a quiet rail. Review may place
candidate and source side by side. At 390px use one column, source immediately after its
candidate, explicit buttons, and no drag requirement. Preserve 16px body/control, 14px
secondary, 13px label floors, keyboard focus, and existing responsive breakpoints.

Design critique: the overview should orient members without burying the history; a dense
decision dashboard would compete with reading. Do not add empty coordination panels.
Rendered desktop/390px and keyboard review is required during implementation; this
planning pass has not produced or browser-tested the UI.

## Source identity and storage

Keep the existing `MinutesItem#endeavor_id` as the primary human-confirmed draft identity.
Add that ID and source agenda item ID to **new** immutable approval payloads. Do not
modify existing revision payloads, SHA-256 digests, working rows, or accepted records.

Introduce a separate many-to-many evidence association: one revision item or passage may
support several Endeavors. This is contextual linkage, not reassignment of the source
item's primary identity. It also accommodates verified links for old revision payloads.

Proposed records (final naming may follow repository conventions):

| Record | Responsibility and invariants |
| --- | --- |
| `EndeavorHistoryRun` | Stage (`discovery`, `verify_discovery`, `summary`, `verify_summary`), system trigger or requester/delegated execution, parent run, scope, exact source manifest/digest, Endeavor catalog or active-link version, prompt/schema/model settings, status, usage, attempts, safe errors, and candidate JSON. Source inputs and completed results are fixed; retries are new runs. |
| `EndeavorSourceLink` | Organization, Endeavor, revision, item `record_key`, selected body-unit IDs/outcome positions, origin (frozen primary, manual, AI-verified, legacy-verified), and source digest. Activated link content is immutable; replace/retract through explicit audited actions. |
| `EndeavorHistoryEdition` | One Endeavor's immutable versioned overview, meeting summaries, required fact lists, citations, exact active-link/source manifest, verification report, and originating run. Publication selects a validated edition without overwriting earlier ones. |
| `EndeavorHistoryEvent` | Append-only activation, rejection, retraction, guidance change, publication, withdrawal, and replacement provenance, including system/human actor, originating event, delegated execution where applicable, reason, digests, and relevant record IDs. Publication events select the displayed edition. |

Persist versioned Endeavor guidance as a small `EndeavorHistoryGuidance` record referenced
by runs (author, text, version, timestamp); it never becomes a source citation.
Verified facts live in immutable discovery results with run-scoped IDs and source unit
references; editions copy their exact selected fact manifest. No independent task or
assignment table is created from them. Track analysis coverage for every input item,
including negative matches, in run results so an Endeavor refresh can revisit omissions.

Use restrictive foreign keys, organization checks, and database constraints for identity
and deduplication. A normalized tuple/digest of revision, item key, selected units, and
Endeavor uniquely identifies evidence; event operations serialize under a lock. Validate
JSON references against the immutable revision since item keys inside JSON lack a normal
foreign key. Add a unique active-run key and immutable-content protections following the
minutes revision/event precedent. Do not build a general event-sourcing framework.

`SourceDocument` builds versioned deterministic units from revision HTML: block-aware
plain text with entities decoded and paragraphs separated, plus complete outcome objects.
Unit references include revision ID/digest, item key, field kind, and unit index. Preserve
original HTML separately through the revision; AI output never supplies trusted HTML.
Very long blocks split deterministically, with the parent block retained as context.
Store the normalization version and source manifest so offsets never depend on mutable
HTML or a later parser. Render source excerpts by resolving trusted units, not by executing
generated markup. Keep full-item context available to catch misleading partial quotations.

Older revisions: existing live primary links are hints, not certified historical identity.
Match and verify against immutable item keys and actual source wording. Missing or changed
keys remain explicit coverage gaps. New frozen primary links can be materialized without
AI identity inference when their revision becomes member-visible. Contextual links from a
corrected revision are rediscovered and verified; do not copy them by title. Preserve the
origin distinction between frozen human identity and derived contextual relevance.

## AI pipeline and preservation contract

### A. Discover passages and extract facts across a meeting

Input is the selected revision's recorded body units and all outcomes, with item/section
titles for context; agenda wording is separately marked as plans. Include the organization's
existing Endeavor IDs/titles/purpose summaries, including completed Endeavors. Date/status
may inform relevance but cannot exclude a valid historical match. No new IDs may be invented.

For each source item, return an explicit disposition (`matches`, `no_match`, or `ambiguous`)
with candidate Endeavor IDs, selected unit references, a relevance reason, and distinct
facts supported by those units. Empty procedural items can be accounted for deterministically;
no heading-based filter may skip a nonempty report, minutes-approval item, or outcome.

Facts distinguish report, proposal, decision, commitment, uncertainty, and discrepancy.
Preserve names when needed for responsibility, amounts, dates/times, vote results,
negations, conditions, dependencies, and unresolved issues. A planning request is not
a completed task; a mover is not necessarily the assignee; missing discussion is not
completion. Source statements are data, never instructions to the model.

All structured outcomes in an associated item are retained as relevance candidates. A
mixed report may have unrelated outcomes; automatic verification must account for each
inclusion/exclusion explicitly. Every relevant outcome renders deterministically and in
order, even if narrative wording omits it. Do not reduce defeated and subsequent adopted
motions to a single ambiguous “approved” label.

The input manifest accounts for every substantive item and outcome. Outputs must account
for each input item, with multiple matches/facts where warranted. Duplicated/missing items,
unknown IDs, invalid ranges, malformed arrays, refusal, or truncation fail validation.
Coverage counts detect missing structure; they cannot prove semantic completeness. Automated
verification against the full source and curated evaluation address that remaining risk;
no verifier can guarantee that every semantic omission will be detected.

### B. Verify discovery and activate evidence

Run a separate verification pass against the full minutes input, catalog, guidance, and
candidate extraction. It checks missed relevant passages, false matches, missing facts,
source support, mixed-topic reports, conditions, outcomes, and ambiguous identity. Return
structured findings with exact source references, not just a confidence score. Deterministic
checks remain mandatory even when the verifier says the result is valid.

Allow one bounded repair cycle for concrete findings, then verify the revised result.
Unresolved material ambiguity or incomplete coverage prevents publication for affected
Endeavors and appears in the admin tool; unaffected verified work may proceed. Track
unassigned ambiguity at meeting level so it cannot be mislabeled fully processed. Routine
`no_match` results are valid only when the complete scan and verification succeed.

### C. Generate summaries from verified evidence

For each affected Endeavor, send all active source passages, verified facts, and
outcomes across its history in meeting-date order. Supply old prose only as comparison,
never as the sole factual source. Generate changed meeting summaries and an overview
in one structured response; render through Rails without a second AI rewriting pass.

Each summary claim cites one or more supplied source references and fact IDs. Every
required fact must appear in that meeting's summary or its supporting fact/decision list.
The overview may prioritize recent progress, but cannot replace the complete meeting
history. Validate fact coverage, citation membership, numeric/date fields, and outcome
identity. No silent deletion of invalid claims and no arbitrary first-N facts truncation.
A separate automatic verification pass checks entailment and qualifiers against source
passages and the required facts before publication. Use a distinct verifier prompt and
record its findings; sharing a provider does not make errors independent. An invalid result
gets at most one repair cycle and re-verification, then fails visibly in admin tools.

### D. Handle long records without hiding loss

Do not copy Topics' three-meeting raw-context limit as a complete-history guarantee.
Initially the corpus fits direct structured inputs. Define a tested model input/output
budget; when exceeded, partition discovery by whole items/paragraphs and the Endeavor
catalog into explicit batches. Track every source-unit/catalog-batch pair so all candidates
are considered. Duplicate candidates merge by stable references, not by similar prose.

For long Endeavor histories, build per-meeting fact bundles with full source references,
then synthesize the overview from **all** verified fact bundles, preserving the complete
history independently. If even that exceeds the budget, use dated groups with explicit
fact coverage at every stage, or stop with a reviewable size-limit error. Never silently
drop older meetings or cut off the end of a document. Chunking/group synthesis is required
before processing inputs that exceed the initial direct-input limits.

## Visibility, revisions, and freshness

Use `MeetingMinutes#member_revision`/`member_visible?` consistently in history, source
routes, citations, cache reads, and AI preparation. Never use `attested?` as the sole gate.

| Change | Member behavior and processing |
| --- | --- |
| Initial draft or approval without attestation | No minutes content enters history or generation. Published agenda may remain visible. |
| Initial attestation | Frozen primary links become available; discovery starts automatically after activation. Summary remains absent until verified publication. |
| Membership approval of the same revision | Update authority label to Official minutes; no AI call needed solely for that status change. |
| Reopen / corrected approval before attestation | Continue using the last member-visible revision and label correction in progress. No working changes enter summaries. |
| Corrected revision attested | Use the replacement revision; suppress affected old meeting summaries and the dependent overview until regenerated and verified. Unaffected history remains. |
| New meeting becomes visible | Existing edition may remain with its exact coverage date and “Newer minutes are available.” Validated direct history appears immediately. Refresh only affected Endeavors after discovery. |
| Link retracted or source no longer eligible | Suppress dependent summary/overview immediately on read, even if a background invalidation job has not run. |
| Old run finishes after newer work | Preserve the run for audit; prevent it from publishing against a changed source/link manifest. |

Stable member source links must resolve only to currently eligible member revisions.
If a saved citation points to a superseded revision, explain that corrected minutes are
available and link to them; do not silently show replacement words as the cited passage.
Historical editions and withdrawn source associations remain available to authorized
managers for audit, not automatically through member deep links.

Publication locks the Endeavor and rechecks source visibility, selected revision digests,
active-link/fact version, guidance version, verification result, and candidate digest. One
edition publishes atomically. A stale candidate is superseded and the current work is
queued. Check manual requesters' current grants again for their queued work; automatic
runs execute the enabled organization policy and record a system actor, never impersonate
an officer. Metadata-only changes such as membership approval do not require regenerating
unchanged prose; source labels stay live.

## Jobs, triggering, and operating cost

Use Solid Queue with durable domain runs; expose them in the existing Jobs ledger and
scoped HTML/API run-status endpoints. Proposed services live under `EndeavorHistory`;
use a separate provider adapter/prompt from transcript drafting so this feature cannot
change the official-minutes drafting contract. Follow the existing injected-client,
structured-output, source digest, usage accounting, and safe-error patterns. Keep model
configuration independent; validate the choice empirically rather than copying an old
Topics model or price assumption.

Normal processing is event-driven and automatic once the feature is activated. Queue
from an after-commit attestation event, including corrected revisions. Keep a lightweight
reconciliation sweep to recover missed enqueues and queue outages, deduplicating against
successful/current runs. Newly created Endeavors trigger a scoped historical discovery
scan so older unlinked mentions can become visible. Guidance changes trigger the explicitly
requested scope and never silently rewrite official records.

Provide a separate dry-run inventory and bounded, checkpointed initial backfill; a deploy
must not launch unbounded paid history processing. Activation and real-data evaluation are
future implementation/release steps, not actions performed by this planning task. No paid
calls on member visits, agenda publication, or membership approval alone.

Fingerprint runs from stage, exact source manifest, relevant Endeavor catalog/link and guidance version,
prompt/schema/model settings. Coalesce concurrent requests using a unique active key;
retries are explicit new attempts with bounded retry policy. A worker lease/heartbeat and
recovery path must distinguish a stalled process from a completed response. Provider
timeouts may have incurred cost; do not promise exactly-once remote execution. Record
attempts/usage and avoid unlimited automatic retries.

Expected ordinary small-meeting flow: one discovery call plus one verification call,
then one synthesis and one verification call per affected Endeavor. Reuse unchanged
per-meeting facts; deduplicate shared discovery when several Endeavors refresh together.
Chunking, bounded repair, and retries add calls. Report actual usage and configure request,
output, attempt, and spend limits. Budget exhaustion pauses work in admin tools rather
than publishing a partial result. No monetary estimate is justified until an authorized
sample evaluation is run. Deterministic rendering needs no extra AI call.

## API parity and implementation boundaries

Extend member `GET /api/endeavors/:id` with overview, coverage, upcoming published
appearances, paginated history, authority labels, and resolvable citations. Apply the same
filtering to existing upcoming IDs; protect draft bodies, candidate JSON, and metadata.

Add management endpoints for discovery, run status, guidance updates, scoped regeneration,
withdrawal/resume, and run/edition inspection through the same services as HTML. Require
`manage_agendas`; use existing API idempotency and delegated-execution provenance. Write
requests carry guidance/source versions to reject stale operations. Document exact routes
and schemas in the signed-in handbook during implementation. No new official-act endpoint.

Tasks, volunteers, responsible people, subcommittees, and Kanban remain future discovery
in the original roadmap. This feature records what minutes say about commitments; it does
not create operational assignments or change official records.

## Acceptance and remaining choices

Ship the full feature only after source integrity, discovery coverage, useful summaries,
automatic publication and recovery, lifecycle invalidation, API parity, and desktop/390px checks pass.
The implementation plan specifies commit-sized work and evaluation cases.

The user selected automatic operation with an admin rerun/clarification tool. Routine
human source or prose review is not a launch requirement. Remaining implementation choices
are provider/model settings, measured budgets, and initial backfill scope, to be established
through offline fixtures and then a separately authorized real-data evaluation. The
selected capability is `manage_agendas`; no extra official-record authority is implied.
