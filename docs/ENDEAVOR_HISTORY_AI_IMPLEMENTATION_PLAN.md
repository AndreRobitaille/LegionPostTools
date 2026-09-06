# Endeavor history and AI implementation plan


**Implementation note:** the local implementation and its exact operational boundaries are
documented in [Endeavor AI history](ENDEAVOR_HISTORY_AI.md). This document preserves the
planning rationale; current implemented behavior supersedes proposed storage/staging details.

**Status:** implementation reference, September 6, 2026. The current behavior and
completed live evaluation and remaining activation work are recorded in the implementation guide.

Design: [Endeavor history and AI-assisted member updates](ENDEAVOR_HISTORY_AI_DESIGN.md).
User-selected operation is automatic discovery, summarization, and publication, with an
admin tool to rerun work and provide clarifying guidance. No routine human approval queue.

The steps below are implementation-sized units, not instructions to commit or deploy
without authorization. Preserve existing worktree edits. Do not migrate/reset development
data, execute historical backfills, or make paid AI calls while doing offline implementation.

## 1. Establish immutable source references and visibility

Affected seams:

- `app/models/meeting_minutes.rb`: snapshot `endeavor_id` and source agenda identity in
  newly approved revision items; preserve existing payload compatibility.
- New `app/services/endeavor_history/source_document.rb` and `source_selector.rb`:
  organization-scoped member revisions, stable body units, outcomes, source manifests.
- `app/views/meeting_minutes/_revision.html.erb`: stable source-item anchors.
- `app/helpers/endeavors_helper.rb`: replace the narrow `attested?` branch with the
  actual member revision/visibility contract and current authority labels.

Implement a deterministic, versioned HTML-to-text normalizer that preserves block
boundaries and entity decoding; keep all original HTML in the immutable revision. Include
every nonempty recorded item and all outcomes regardless of procedural-looking titles.
No database repair or rewrite of historical revisions.

Verify: existing payloads and SHA-256 digests unchanged; new frozen links do not change
when a live draft link is edited; repeated headings remain distinct by item key; selected
revision is correct in all lifecycle states. Test HTML paragraphs, lists, entities,
oversized text, malicious markup, and outcome-only items.

## 2. Add derived history records and governance exception

Add the five small domain records described in the design: history runs, source links,
editions, events, and versioned guidance. Add indexes, restrictive foreign keys,
organization validations, immutable-content protections, and concurrency controls.
Record automatic actors as system actions tied to runs, never as an officer signature.

Implement `EndeavorHistory::ActivateEvidence` and `PublishEdition` services with source,
guidance, link-version, verification, and withdrawal-state checks under locks. Retries
and replacements retain prior content and provenance. Only verified source changes
activate a replacement set; a failed rescan never deletes previously valid associations.

Update `docs/ENDEAVOR_GOVERNANCE.md` to permit automatic *derived evidence associations*
to human-defined Endeavors for this workflow. Keep `MinutesItem#endeavor_id`, creation,
merging, splitting, and official records under their existing human authority. Update
`docs/ROLES.md` for `manage_agendas` history administration and system publication policy.

Verify: duplicate/concurrent activation, cross-organization references, nonexistent JSON
item/unit references, immutable event/edition content, rollback on failed activation,
explicit withdrawal persisting across later background jobs, and old run rejection.

## 3. Implement discovery and automatic source verification

Add `EndeavorHistory::DiscoveryPrompt`, schemas, `Discover`, `VerifyDiscovery`, and a
provider adapter under a dedicated namespace. Follow Legion's existing injected client,
structured output, source digest, usage, and safe-error patterns. Do not modify the
minutes drafting prompt or import TwoRiversReporter's general AI/retrieval architecture.

Discovery inputs include all selected revision items/outcomes and the existing Endeavor
catalog, including completed items. Primary frozen links are anchors, not a filter that
excludes other reports. Guidance carries a separate non-evidence label and version.

Return per-item coverage, candidates, source units, relevance reasons, facts, and outcome
relevance decisions. Verify against the full original input for false associations,
missed passages, conditions, and outcomes. Use structured verifier findings and one bounded
repair cycle; material unresolved findings prevent affected publication. Surface incomplete
meeting coverage even if an ambiguous passage has no selected Endeavor.

Define explicit request/output limits. Implement complete manifests for source/catalog
batching; exercise the same logic with tiny synthetic limits. No first-N truncation,
title-only matching, or deleting existing associations as a prerequisite to rerunning.

Verify: all source IDs accounted for; each citation resolves; unknown Endeavor IDs and
cross-organization IDs rejected; no-match/ambiguous states distinct from empty/failed
output; guidance cannot supply a motion or override visibility; source prompt injection
does not become application authority. Validate provider failure/refusal/partial output.

## 4. Implement meeting summaries, overview, and automatic publication

Add `BuildSummaryContext`, `SummaryPrompt`, `GenerateSummary`, and `VerifySummary`.
Use all active evidence and required facts, ordered by meeting date. Preserve complete
outcomes through deterministic rendering. Generate one Endeavor's changed meeting
summaries and overview in a structured response, then verify citations, entailment,
qualifiers, and required fact coverage before publication. No second AI rendering pass.

Long inputs use per-meeting fact bundles; all required facts remain in the full history.
Enforce explicit coverage at every aggregation stage or stop with a size-limit failure.
Keep old valid editions on transient failure, subject to current source eligibility.
Prevent out-of-order work from replacing a newer edition. Publication is automatic on
successful verification; it does not require a reviewer field or human approval token.

Verify: required facts missing from prose still appear in supporting facts/decisions;
missing from both fails; invalid citations fail rather than silently drop claims;
rejected proposals stay rejected; source changes during generation prevent publication;
valid system-triggered results publish without any human review action.

## 5. Add event-driven orchestration and admin recovery

Add focused jobs for discovery/verification and affected-Endeavor synthesis/verification.
Run after member-visible attestation commits. A rollback must enqueue nothing. Queue
reconciliation recovers missed events using exact fingerprints and checkpoints, without
repeatedly paying for successful unchanged inputs. A new Endeavor needs a scoped scan
of prior member-visible records, including those with no existing association.

Integrate with `Admin::JobsController`, corresponding API Jobs response, and run/status
views. Keep access scoped by capability: a `manage_agendas` user may see Endeavor history
runs but must not gain transcript-run access through the existing mixed Jobs screen.
Review shared navigation and API field visibility when extending those surfaces.

Add Endeavor management pages and endpoints for:

- Inspection of coverage, source links, editions, verification findings, and usage.
- Full-meeting rerun and all-meetings-for-one-Endeavor refresh, with a scope preview.
- Versioned clarifying guidance and reset, with explicit rerun scope.
- Failed-attempt retry, withdrawal, and resume/recovery.

Use `manage_agendas`, optimistic locking/versioned inputs, CSRF, and existing API
idempotency/delegated-execution patterns. Recheck a manual requester's authority before
queued work proceeds. Automatic runs use the enabled organization policy and system
provenance. Guidance is not an evidence source. Normal successful runs need no intervention.

Verify: duplicate enqueue, queue failure, worker crash/lease recovery, bounded retries,
budget pause, restart, repeated reconciliation, capability revocation, withdrawal
persistence, scoped refresh finding a previously unlinked report, and guidance changes
making old candidates stale. No paid calls on ordinary GET requests or authority-label-only
changes. Jobs must not expose another run type's private source data.

## 6. Build the member experience and matching read API

Use the frontend-design skill and the design's visual direction. Add a shared
`EndeavorHistory::Presenter`/query for published overview, coverage, future appearances,
meeting summaries, exact source excerpts/outcomes, and attributed officer updates.

Update `EndeavorsController`, `app/views/endeavors/show.html.erb`, shared partials/styles,
and `Api::EndeavorsController`. Keep the title/purpose summary; add At a glance, Coming up,
and History. Show exact relevant decisions below narrative text; use accessible source
disclosures and source-item links. Paginate complete meeting groups using a stable cursor
and deterministic ties; never split one meeting across pages.

Filter unpublished agenda entries and metadata in HTML and API. Render source authority
from the currently eligible revision; suppression of an invalid edition must occur on
reads, independently of background cleanup. Use authenticated, organization-scoped
source routes and deliberate API fields. Add management API handbook documentation for
new actions as well as member history fields; no official-minutes mutation is added.

Verify desktop and 390px layouts with synthetic test accounts/data, long names/passages,
keyboard disclosures/focus, text floors, overflow, empty history, completed Endeavors,
partial/stale coverage, and unavailable sources. Members should understand AI-generated
status and source authority without knowing about jobs or model settings.

## 7. Evaluation and release evidence

### Offline acceptance corpus

Build synthetic fixtures modeled on the inspected records; do not copy sensitive member
content into tracked tests. Keep expected source IDs, fact IDs, and outcomes explicit.

| Case | Must preserve / reject |
| --- | --- |
| Car Show across reports | Donors and volunteer needs, Honor Guard timing, and profit-allocation motion found across separately titled items. |
| Mixed Finance report | Include relevant allocation and amount/condition; exclude unrelated account balances. Account for every outcome exclusion. |
| Election term votes | Defeated two-year proposal, adopted one-year term, vote details; retain both in order. |
| Newsletter progression | Earlier hold, missing draft, absent coordinator, recommendation to continue holding; no invented motion or completion. |
| Ethnic Fest | Expected spaces, unconfirmed electricity, meeting time/location, volunteer need; qualifiers survive. |
| Similar annual events | Distinguish two human-defined Endeavors; guidance clarifies identity without creating historical facts. |
| Procedural heading with substance | A minutes-approval or officer report still yields relevant substantive evidence. |
| Old title/date conflict | Preserve source discrepancy; no silent historical correction or guessed date. |
| Closed Endeavor / no agenda link | Completed and minutes-only history remains discoverable. |
| Corrections and concurrency | Last attested revision during reopen; replacement at re-attestation; outdated in-flight run cannot publish. |
| Long history | An old consequential decision remains in facts/history even when newer material dominates overview. Every chunk accounted for. |
| Bad outputs | Invalid citations, unsupported claim, lost negation, missing input item, partial JSON, guidance injection, and silent truncation prevent publication. |

Deterministic tests validate mechanics, not real model quality. A provider-backed evaluation
must measure discovery recall/precision against a curated passage list, required-fact
retention, source support, correct outcomes/qualifiers, readability, latency, and actual
usage. Target 100% retention of the curated consequential decisions and required facts,
zero unsupported published claims in the acceptance corpus, and no false associations
in its ambiguous-identity cases. These are release criteria, not universal guarantees.

When separately authorized, evaluate the two available local revisions in an isolated run
with writes/publication disabled, then compare candidate evidence and editions against
the curated expectations. Report raw results, repair rate, unresolved cases, and spend.
Do not adopt a model merely because it passes request serialization or shares a name
with another app's default. The subsequent [live evaluation](ENDEAVOR_HISTORY_AI_LIVE_EVALUATION.md)
exercised normal automatic publication locally; production remained untouched.

### Proportionate code checks

Run focused Minitest coverage for new services/models/jobs/controllers and existing
Endeavor/minutes/API/Jobs regressions, plus focused RuboCop. Because this feature crosses
authorization, publication, and immutable records, run the full Rails suite, Brakeman,
dependency audit, and member/admin browser QA before release. Use the test database;
never reset the development database for these checks. Record exact results and blockers.

### Activation and rollback

Keep processing/publication behind a feature activation switch during implementation.
Before any authorized backfill, produce a read-only inventory of eligible revisions,
existing primary links, all Endeavors, expected batches/calls, and source digests. Process
bounded batches with checkpoints; preserve before/after evidence for source records.
Backfill derives links/editions and must not alter minutes payloads, hashes, statuses,
timestamps, or approval provenance. Re-running unchanged scope deduplicates successfully.

At activation, enable automatic new-revision processing and reconciliation. Disable
generation/publication or withdraw an edition to recover; the source history and full
minutes stay available. No rollback should require deleting source records or generated
audit history. Use the repository release entry point for a separately authorized release.

## Completion definition

The feature is complete when new member-visible minutes produce correctly linked,
verified, cited Endeavor updates automatically; members can inspect exact relevant
decisions and sources; an authorized manager can correct guidance and rerun without
editing official records; and corrections/permission changes cannot leave invalid content
visible. Subcommittees, assignments, tasks, volunteering, and Kanban remain future work.
