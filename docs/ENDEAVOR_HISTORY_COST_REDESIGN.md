# Endeavor history with incremental meeting processing

Status: incremental processing implemented and verified locally, October 2, 2026;
releases use the repository's guarded deployment workflow. Shared multi-Endeavor generation remains an unqualified
optimization. This document records the requested
architecture reassessment. It does not describe shipped changes or authorize paid
evaluation, production data changes, or deployment. Current behavior remains documented
in [Endeavor AI history](ENDEAVOR_HISTORY_AI.md).

## Product and cost requirements

An Endeavor is a human-defined continuity record for American Legion Post work. Its
member history needs a useful short overview, dated meeting accounts, complete recorded
decisions, and access to the original evidence. It should cost a few dollars a month at
Post 165's present workload. Preserve automatic updates and source verification without
requiring officers to manually classify every incidental mention.

The user's clarification is that this is an efficiency requirement, not a request to
enforce a particular monthly budget. Prioritize eliminating duplicate processing and
measuring the resulting usage. A spending cap does not make repeated work efficient.

Make recurring work proportional to new or corrected evidence. Unchanged historical
meetings, unrelated Endeavors, member page reads, and routine reconciliation require no
paid processing. Preserve human control over identity, lifecycle, and official records.
Do not turn one-meeting discussions into Endeavors to simplify matching.

## Evidence from the original implementation

Read-only inspection of the local database on October 2 found eight Endeavors, four active
and four completed, and two source revisions with 35 items each. Their complete stored
revision JSON is approximately 21 KB and 23 KB. These figures describe the local snapshot,
not a newly verified production inventory or the provider's billing export.

The September 26-27 history runs used exactly the same source revisions and AI
configuration as September 6. For the first existing Endeavor, the only changed manifest
field was the organization-wide catalog. Adding two identities caused the existing
histories to be regenerated. Three runs exhausted the daily token reservation budget and
started fresh the following day, repeating already completed stages.

The original code explained the amplification:

- `Sources#manifest` includes every Endeavor's name and summary in every fingerprint.
- `Processing#call` discovers every source revision separately for one target Endeavor.
- `Schemas.discovery` and the prompt require relevance explanations for every item,
  including empty procedural items, and separate outcome explanations.
- `Processing#call` rewrites all meeting summaries alongside the overview on each run.
- Successful discovery is stored in run steps but is not reused by a later attempt.
- The 500,000-token daily allowance is neither a monthly allowance nor a dollar ceiling.

For one batch per meeting, the original workload was approximately
`Endeavors * (2 * historical meetings + 2)` calls, before repairs. Eight Endeavors and
two meetings would mean about 48 calls; sparse unmatched histories may skip synthesis.
The 15-minute reconciliation itself is local work and deduplicates unchanged manifests.

## Selected design: retain meeting evidence and process changes

Retain verified evidence in append-only derived records. The first implementation keeps
target-specific source checks; the proposed shared path below would process a new
member-visible meeting revision against the existing human-defined Endeavors together.
Compose Endeavor histories from those records and reuse unchanged meeting accounts.
This stays in Rails/PostgreSQL/Solid Queue; it needs no retrieval service or shared
mutable graph.

The optimized small-meeting path targets four provider calls in total. Shared extraction
and batched writing change the model's task, so they require the quality acceptance
checks below before replacing the current target-by-target prompts:

1. Extract relevant facts and proposed evidence associations for all eligible Endeavors
   from the complete new meeting revision.
2. Independently verify extraction against that complete source and the supplied identities.
3. In one bounded batch, draft that meeting's accounts and short overview updates only
   for Endeavors whose verified evidence changed.
4. Independently verify those accounts and overview changes against the relevant original
   passages and verified facts. Publish each complete valid Endeavor edition atomically.

If no substantive evidence changes, skip calls 3 and 4. Removed facts, corrected
associations, and newly discovered conflicts count as changes even when no new positive
facts are added. Repairs are limited to one
additional candidate/verifier pair for the failed stage. Retain the existing input,
call, and daily token safeguards. Larger inputs use explicit whole-item batches;
four calls is a normal-path target, not permission to truncate sources, reduce reasoning,
or skip a focused verification when a combined pass cannot establish sufficient coverage.
Retain target-specific processing for difficult or ambiguous cases.

Existing annual identities and completed Endeavors remain eligible for matching. A
meeting report can concern multiple Endeavors. Preserve the frozen primary links as
identity anchors while still checking unlinked reports, corrections, and financial
motions. AI evidence association does not create or redefine an Endeavor.

### Durable evidence and reuse

Store immutable verified meeting results separately from published history editions.
Each result identifies the organization, exact revision/digest, normalization and prompt
versions, target identities and guidance used, source-unit IDs, facts, coverage, and
provider attempt identifiers. Use database uniqueness and job claiming to prevent two
workers from paying for the same stage concurrently.

Coverage records account for every supplied item/target and outcome/target combination,
including explicit empty and no-match results. Compress this representation without
discarding the negative assessments. An item can concern several Endeavors; a shared
extraction must not assign it exclusively to the first plausible identity.

Remove repeated explanations only after verifying that the compact format preserves
coverage. Do not infer irrelevance from an empty body. Normalize item headings into
independently citable immutable source units, retaining their text, revision, and item
key. The original adapter exposed headings as metadata but permitted citations only to
body/outcome units. A revised normalization version needs an explicit compatibility
adapter; never change the meaning of old source IDs. Deterministic empty coverage applies
only when the source actually has no heading, body, or outcome content. A procedural-looking
heading is not permission to skip AI review. Every item remains visible in the verifier's
complete source.

The independent verifier still receives the complete source, including unmatched items.
Reducing repetitive output must not silently reduce what it checks. Ambiguity, missing
facts, unsupported citations, and changed motion dispositions block publication.

Overview updates consider the complete retained verified fact inventory for that Endeavor,
including facts omitted from its previous short overview. Include the current original
passages supporting those facts. For this small archive, that is more defensible than
introducing a heuristic that selects old evidence. It avoids repeated full-minute
discovery while preserving earlier unresolved matters, defeated alternatives, conditions,
and contradictory reports. Prior prose may orient writing but is never factual authority.

The overview may remain selective; each dated account must preserve its complete facts.
Input limits stop explicitly rather than silently selecting only recent highlights or
truncating sources. Any later evidence-selection strategy requires its own completeness
evaluation. Its cost savings cannot be assumed here.

### Changes and processing scope

| Trigger | Paid processing scope |
| --- | --- |
| New attested minutes | The new revision once for the catalog; new accounts and overview updates only for affected Endeavors. |
| Corrected re-attestation | The replacement revision; replace its derived evidence and update affected overviews. Retain other meetings. |
| Membership acceptance of an unchanged revision | None; update authority labels from the existing record. |
| Draft edits, Commander approval, agenda changes, tasks, or officer updates | None; retain the existing source eligibility boundary. |
| New Endeavor | Search current source revisions for that identity in bounded batches; no blanket regeneration of existing identities. |
| Existing Endeavor title/summary or identity guidance changes | Reassess that identity and demonstrated matching conflicts, using retained sources. A shared catalog change alone does not force every history to regenerate. |
| Withdrawal/resume | Honor withdrawal immediately; resume reuses current verified work and processes missing or invalidated results. |
| Reconciliation or member page read | Local comparison only; enqueue missing stages, never unconditional paid refreshes. |
| Explicit selected-meeting refresh | Reprocess the selected revision and affected summaries, reusing all other meetings. |
| Explicit full-history rebuild | A separate scoped operation with a source count, estimated usage, and an explicit reason to bypass reusable results. |

A new or clarified identity can reveal that an old match was ambiguous. Detect conflicting
source associations and reassess those matches before updating affected histories. Do not
treat positive matching evidence as permanent truth. Negative coverage is tied to the
identities actually examined; a new identity needs its own historical search.

That historical search must inspect full current revisions, not just previously linked
passages, keyword hits, or positive facts. Its verifier checks whether the new identity
changes an existing assignment or exposes uncertainty. If conflict scope is unclear,
expand target-specific reassessment rather than declare every old match reusable.
Completed annual Endeavors remain comparison identities; separate annual records cannot
be merged or silently relabeled. Defer only the affected generated material when matching
remains unresolved; unrelated valid history can remain published.

### Resume and correction safety

Persist and validate each completed provider stage. An existing daily token-limit pause or
transient worker failure resumes missing work instead of repeating successful extraction
and verification. A lost response has uncertain cost: retain its maximum reservation,
record that uncertainty, and never describe the retry as free or exactly once.

Recheck member-visible source selection, revision digests, identity/guidance, withdrawal,
requester capability, and delegated-token validity before each paid stage and publication.
On replacement attestation, immediately suppress superseded generated passages and any
overview depending on them. Other valid meeting accounts remain readable. Until
re-attestation, reopened minutes retain their last attested revision under current policy.
Append new results and editions; never modify official minutes, past run records, or
accepted historical associations to manufacture a successful migration.

## Cost envelope and usage measurement

GPT-6.1 Sol was the first candidate for the whole pipeline. The initial implementation
keeps Astra/high for extraction/full-source checks and uses Sol/high for composition/summary
checks. The [bounded model and reasoning comparison](ENDEAVOR_MODEL_AND_COST_EVALUATION.md)
records the selected profile and its limits. Use Astra as the
comparison baseline, not a requirement that the new pipeline keep paying Astra rates.
The [September reasoning comparison](ENDEAVOR_REASONING_EVALUATION.md) evaluated effort
levels within Astra; it does not establish Sol or Luna quality. Evaluate model choice,
reasoning effort, prompt changes, and shared processing separately so regressions can
be attributed to the change that caused them.

Current official standard short-context prices, checked October 2, 2026, per million
tokens:

| Model | Input | Cached input | Cache writes | Output |
| --- | ---: | ---: | ---: | ---: |
| [GPT-6 Astra](https://developers.openai.com/api/docs/models/gpt-6-astra) | $10.00 | $1.00 | $12.50 | $50.00 |
| [GPT-6.1 Sol](https://developers.openai.com/api/docs/models/gpt-6.1-sol) | $2.00 | $0.10 | $2.50 | $10.00 |
| [GPT-6 Luna](https://developers.openai.com/api/docs/models/gpt-6-luna) | $0.10 | $0.01 | $0.125 | $0.50 |

At identical noncached input/output and cache-write counts, Sol's price is 80% lower
than Astra's and Luna's is 99% lower. Sol's cached-input rate is 90% lower. These are
rate comparisons, not guaranteed savings for a completed task. Models may consume
different reasoning/output counts, require different repairs, or miss different facts.
Compare total cost per quality-accepted update, including failed attempts and fallback.

Output includes reasoning. Count cache writes as an input category, not as a second
full input charge; see the official
[cost calculation](https://developers.openai.com/api/docs/guides/prompt-caching).

An illustrative four-call meeting update with 40,000 combined input tokens and 8,000
combined output tokens costs $0.90 with Astra if all input is cache-written. At 60,000 input and
16,000 output it costs $1.55 with Astra. With identical counts, Sol would cost $0.18
and $0.31, respectively; Luna would cost $0.009 and $0.0155. These are design envelopes,
not measured results from a
working replacement. Shared extraction output may grow with substantive facts and the
number of identities; batching alone does not prove those token targets.

For the proposed shared path, one or two ordinary meetings monthly would suggest
$0.90-$3.10 for history. Adding
one or two minutes drafts near September's latest $0.87 uncached estimate gives roughly
$1.77-$4.84 total. Repairs, backfill, and unusual record sizes may cost more; the success
criterion is justified new work, not stopping necessary updates at an arbitrary amount.
The implemented target-specific path instead has an illustrative local usage estimate
near $4 per meeting for history, about $5 including one minutes draft; see the comparison
report for the assumptions. Neither calculation is a newly measured production forecast.
Prove call counts, input scope, and reuse with offline fixtures first; real provider
benchmarks require explicit authorization and a declared spending allowance.

### Model selection and request settings

OpenAI describes [GPT-6.1 Sol](https://developers.openai.com/api/docs/models/gpt-6.1-sol)
as near-Astra performance for complex work at lower cost, and
[Luna](https://developers.openai.com/api/docs/models/gpt-6-luna) as its efficient model
for focused, high-volume tasks. This supports testing Sol for the whole pipeline and
Luna for bounded checks; it is not evidence of equivalent completeness on Legion minutes.
The official [selection guidance](https://developers.openai.com/api/docs/guides/model-selection)
also recommends comparing models on the actual task.

Both support Responses, structured outputs, and a 1,050,000-token context window with
128,000-token maximum output. Sol supports low, medium, high, xhigh, and max effort;
it does not support none/minimal. Luna additionally supports none. Our current input
cap is much smaller than either model's context capacity; a larger context is not a
reason to resume sending the whole archive on every update. Prompts over 272,000 input
tokens have higher rates, which should not be needed for this Post's history workload.

Proposed comparison candidates:

| Stage | First candidate | Additional candidate | Quality requirement |
| --- | --- | --- | --- |
| Full-source discovery | Sol, high reasoning initially | Sol, medium after the high comparison passes | Retain every relevant fact, association, outcome, title detail, and qualifier. |
| Discovery verification | Sol, high reasoning | Astra for difficult focused checks where comparison evidence justifies escalation | Inspect unmatched source items as well as positive findings; do not accept omitted facts because the writer missed them. |
| Meeting accounts and overview | Sol, high reasoning; medium compared separately | Luna, medium on short already-verified evidence only | Preserve all required dated facts and current source support; concise prose is not permission to lose details. |
| Summary verification | Sol, high reasoning | Luna for narrowly specified claim/source checks | A narrow claim check cannot establish full-source discovery completeness. |

Luna is an evaluation candidate, not the sole completeness gate for the first release.
Only add stage-specific routing if the comparison establishes a useful quality/cost
advantage; an all-Sol profile is simpler and should be tested first. Keep deterministic
ID, scope, count, and citation checks in Rails rather than paying a model to repeat them.
Escalation follows validation failures or observed task limitations; a confident valid
model response alone does not prove that escalation was unnecessary.

The original provider used the same environment-selected model for every stage. The
implemented mixed profile includes an explicit per-stage configuration
signature, recorded actual model/effort per attempt, compatible reuse rules, and tests.
Changing the default should apply the qualified profile to new work while preserving
approved reusable evidence; it must not silently force paid regeneration of all old
histories. Missing compatibility evidence requires a declared scoped recheck.

Use standard processing for the initial comparison. The model pages price Batch/Flex
at 50% of Standard and Fast at twice Standard, but those introduce separate delivery
and retry considerations. Do not add Fast processing to asynchronous history updates
without a demonstrated latency requirement. Provider prompt caching can save input
costs; durable application reuse avoids the call itself. Account access and actual
model quality require a separately authorized provider comparison; Sol was tested in
the linked report, while Luna remains untested.

Record input, output, reasoning, cached-input, and cache-write usage per actual provider
attempt, together with stage, revision, affected identities, and why processing was
needed. Record reused stages as reuse, without invented paid tokens. Include repair and
failed attempts; unknown timeout usage remains explicitly unknown. Report development
comparisons separately from normal application usage.

Measure calls per new meeting, historical revisions reread, old accounts rewritten,
completed stages repeated, and total observed tokens. Reconciliation should find missing
work with local comparisons. A growing archive must not make every new meeting reread
every historical record.

Monthly dollar caps, a new shared ledger for minutes drafting, budget administration,
and new budget-paused user flows are outside this redesign. Existing runtime safeguards
remain. Model/prompt deployment does not silently rerun the archive. Production migration
adopts compatible validated prior evidence without paid regeneration. Complete migration,
reuse, and source-integrity checks before deployment; the existing enable/withdraw controls
remain available.

## Member and officer presentation

Using the frontend-design skill and The 1919 system, preserve the readable dated-history
layout: navy #0A2240, gold #C6A15B, paper #FBF7EC, ink #1B222B, and cream #F4EEDD.
Use the existing system typeface, with Georgia for original documents. Body/controls stay
at least 16px, secondary text 14px, labels 13px. The dated account with its evidence and
authority remains the organizing feature at desktop and narrow widths.

Members retain source passages and the last valid history, with honest coverage dates.
Provider details belong in officer management. Keep the existing status presentation,
showing the last successful date and the actual scope of refresh or recovery. Distinguish
pending coverage from a completed no-match result. HTML and API must report the same
stage, scope, progress, usage, and recovery action.

## Implementation and acceptance checks

### First implementation: preserve target-specific quality checks

The first implementation retains separate extraction and independent verification for
each Endeavor. Combining eight identities changes the attention and ambiguity problem;
it is not necessary to remove repeated archive work or to use a cheaper qualified model.
The four-call shared batch described above remains a future candidate, not shipped behavior.

`EndeavorHistoryResult` stores append-only verified candidates, full inputs, verdicts,
configuration and originating run. Exact reuse includes source, identity, human guidance,
comparison context and prompt/schema policy. New meetings extract only their new revision;
old accounts remain byte-identical. Composition receives all retained facts and original
passages, writes only affected dated accounts, and checks the updated overview independently.
An unmatched new meeting needs extraction and verification but no new summary calls.

Changed catalog context causes a complete-source verification of the retained candidate;
failed matching checks trigger focused regeneration for that target/revision. Even an
unrelated catalog addition may therefore incur an audit call, but does not rewrite intact
accounts. This deliberately conservative check replaces the earlier proposed zero-call
catalog compatibility assumption. New identities still search all eligible source records.

Completed attempts resume using canonical input/configuration hashes. Unverified generation
can resume only at verification; it cannot publish by itself. Manual refresh has a durable
scope/identity retained through automatic recovery, including the original user's and token's
authority. Reuse events are separate from paid attempts in HTML and API. Unknown timeout
reservations remain on the failed attempt. Existing daily token and call safeguards remain.

Legacy adoption is limited to the known Astra-2/high verification profile and exact original
coverage, generated candidate, accepting verifier/input hash, current source digest and human
identity/guidance. Missing provenance or split batches that cannot be reconstructed are not
adopted. It preserves the original normalization policy; it does not retroactively claim title
coverage. A manager's scoped refresh upgrades that source. The explicit title/financial-context
quality policy also upgrades legacy revisions with related dated headings or relevant financial
decisions involving CD/maturity/rollover context. Compatible legacy evidence avoids paid regeneration. Model/prompt deployment alone does
not queue paid archive regeneration. New normalization adds title units without changing old
body/outcome IDs, and related dated headings require an explicit title citation.

Normal new-meeting work is two calls per Endeavor for discovery, plus two for each changed
history's composition/verification, before justified repairs. The benchmark measures this
conservative path; the illustrative four-shared-call estimates are not its observed cost.

Implement durable reusable evidence first, then the meeting job and compact
extraction/verification contracts, edition composition, usage measurement, and scoped
recovery controls. Update current documentation and the authenticated handbook together.
Retain historical records and reuse prior successful evidence only after structural,
source-currentness, and configuration checks. Adoption does not itself prove semantic
accuracy; preserve verifier results and do not invent missing telemetry.

Implemented synthetic regressions include:

- A new revision performs one target-specific extraction/verifier pair and only affected
  account writing; the archive is reused. A future shared implementation additionally
  needs the one-pair-per-revision and bounded batched-writing checks described above.
- Repeated reconciliation, acceptance, and page reads make zero provider calls.
- A new unrelated Endeavor does not regenerate existing histories; an overlapping annual
  identity causes explicit conflict handling rather than silent reassignment.
- A new meeting preserves byte-identical old accounts; a correction invalidates only
  dependent evidence and overviews. Drafts and private transcripts never enter discovery.
- Mixed officer reports, source-title dates, financial motions, defeated votes, missing
  qualifiers, and deliberate invalid citations exercise full-source verification.
- Daily token-limit interruption and worker recovery reuse successful stages. Concurrent
  requests cannot duplicate paid stages. Timeout uncertainty, repairs, manual reruns,
  and cache usage remain visible in attempt records and respect existing safeguards.
- A job loses permission or a source changes before publication: no generated update is
  published and no official record changes. Withdrawal remains effective.
- The existing HTML/API history, source reader, and officer status contracts remain
  coherent; planned status/control changes require desktop/390px and keyboard review.

Do not claim the cost target achieved until the implementation's recorded tokens and
call counts support it. An authorized bounded live comparison must also inspect source
fidelity; cheaper output is insufficient if it loses relevant meeting evidence.

## Quality review and release criteria — October 2

### What can be reused safely

Unchanged verified extraction and unchanged dated prose do not need fresh generation to
remain useful. Reuse is valid only when the source revision/digest, target identity and
guidance, relevant comparison context, normalization, prompt/schema, and verification
policy still match. Store explicit compatibility and dependency information rather than
treating a matching source digest alone as sufficient.

Adopt a legacy result only if its original candidate, verification, and provenance are
available and satisfy that policy. Missing negative coverage or verification cannot be
manufactured from a published summary. An unsuccessful stage is not a reusable success.
If a catalog change could affect a prior match, audit that dependency before reuse.
An intentional quality-policy change can require a scoped recheck; it must be visible,
not an automatic archive rebuild after every application release.

Recovery reuses a completed extraction only with the exact verification that accepted it.
Candidate generation that finished before a worker failure can resume at verification;
it cannot proceed directly to publication. Fact IDs must be unambiguous across Endeavors,
revisions, and extraction results. Copying cached output into a new edition cannot make
a foreign, superseded, or unverified fact appear current.

### Where the first proposal could have reduced quality

| Change | Risk | Required protection |
| --- | --- | --- |
| One extraction for all Endeavors | Attention to a small or less prominent identity may fall; annual identities may be confused. | Explicit per-item/per-target coverage, full source verification, catalog-order variation in evaluation, and focused fallback. |
| One verifier for the combined output | It may repeat the extractor's omissions or stop at a general valid verdict. | Per-target findings and coverage checks, known omitted-fact cases, and assessment against a source-authored reference inventory. |
| Update from only new facts and the previous overview | An older obligation that was omitted from the overview can disappear permanently. | Use all retained verified facts and their original passages for each affected Endeavor. |
| Treat body-empty items as irrelevant | Dates, qualifications, or decisions contained in the heading disappear. | Independently citable heading units and title-only regression cases. |
| Keep all old matches after a catalog edit | A new annual identity can change which prior associations are defensible. | Full-source new-identity search, explicit conflict audit, and expanded reassessment when necessary. |
| Cache old omissions indefinitely | An earlier verification mistake may persist. | Versioned quality policy, manager-scoped refresh, and deliberate regression-driven repair without routine full rebuilds. |
| Truncate batched output to meet a call/cost target | Less prominent facts or outcomes may be lost while the result looks complete. | Preserve evidence-first limits; reject incomplete output and split/focus the work. |

Use the existing Astra profile as the baseline and compare Sol with the same high
discovery/verification and medium writing efforts first. Removing duplicated work should
be evaluated separately from changing models, reducing model effort, compressing
contracts, or combining many targets. Build and
validate reuse first, then assess the changed extraction and writing tasks. This is an
implementation/testing order for the complete feature, not an additional user approval
ceremony or a requirement to release an incomplete member experience.

### Evidence that verification needs more than a valid response

The [September reasoning comparison](ENDEAVOR_REASONING_EVALUATION.md#source-fidelity)
documented omitted Car Show financial details and an Ethnic Fest event date even after
the candidate passed its own structural and AI verification. High verification effort
alone also failed to guarantee the title date survived. These are existing regression
examples, not evidence that the proposed batching has already been evaluated.

Three synthetic in-memory probes against the original code confirmed:

1. `SourceDocument` creates no citable units for a substantive title with an empty body.
   `Validate.discovery!` can accept a no-match assessment for that item.
2. A fact citing a proposed title unit is rejected because that unit does not exist in
   the original source contract.
3. `Validate.summary!` can accept the reversal of "not confirmed" to "confirmed" when
   all supplied fact IDs are cited. Structural coverage cannot establish semantic truth.

These probes used `RAILS_ENV=test`, synthetic Ruby objects, no provider client, and no
database operations. They confirm specific limitations in current safeguards; they are
not quality measurements of a replacement implementation. Fake-provider tests
exercise rejection and publication mechanics but do not demonstrate model recall.

### Comparison criteria, including a future shared path

Prepare a reference inventory from complete source records before examining generated
candidates. Include each relevant fact, supporting title/body/outcome units, target
identity, qualifications, and decision disposition. Score source support and completeness
per meeting and per Endeavor; assess the short overview separately from complete dated
accounts. The old production prose is a comparison artifact, not ground truth.

Cover the six historical examples and synthetic variations for:

- Car Show information in Adjutant, Finance, and Honor Guard reports; distinct balances,
  amounts, maturity dates, donor qualifiers, and the unresolved July date discrepancy.
- Election alternatives, separate passed/failed motions, exact vote totals, and guest
  requests versus evidence of compliance.
- Newsletter recommendations versus adopted decisions and unresolved coordination.
- Ethnic Fest's event date in its heading, a different planning-meeting date, and
  unconfirmed electrical service.
- SnowFest planned versus actual participation and the later correction discussion.
- Website current versus possible functions, sparse/unmatched histories, title-only
  evidence, shared passages, and similarly named events in different years.
- An older unresolved condition omitted from the previous overview, followed by new
  evidence that does not resolve it; a later contradictory report; and a corrected
  revision that removes an earlier fact. Test event chronology independently of
  publication time, including a historical meeting attested after a newer one.

Compare current target-specific processing with proposed shared processing on the same
fixed inputs, including repairs and failures. Vary catalog order and run more than one
generation for critical cases; a single good candidate does not establish equivalence.
Evaluate source-backed facts rather than prose similarity or word count. A separate AI
audit can flag discrepancies, but each material finding needs inspection against the
source inventory rather than acceptance because another model agrees.

First compare Sol and the existing Astra baseline with target-specific processing and
unchanged substantive prompts. Only then compare qualified Sol with shared processing
and the revised source contract. Test Luna stage substitutions independently. A reduction
in Astra reasoning is not a test of another model, and a simultaneous model/prompt/batch
change cannot identify which change caused a missed fact. Record model, effort, token
categories, failures, repairs, latency, and fallback cost for every candidate. The same
source-based release criteria below apply regardless of model price.

Release criteria are zero new incorrect identities, invented decisions, changed vote
results/amounts/dates, lost material conditions, stale-source publication, or privacy
boundary failures in the comparison set. Every required material fact must survive in
its dated account, and noncritical fact coverage must not decline relative to the
source reference. Do not average a serious failure away with stronger results elsewhere.
Any known current omission needs its own regression check; matching that omission is
not an acceptable pass. Preserve unrelated old accounts byte-for-byte.

If the combined prompt fails these checks, retain shared evidence storage and incremental
updates while using target-specific extraction or verification for the problematic cases.
Additional justified calls are acceptable. Record why fallback occurred so it cannot
quietly become an unconditional rerun of every target and historical meeting.

The design-time review did not itself establish unchanged model quality. The subsequent
[live comparison](ENDEAVOR_MODEL_AND_COST_EVALUATION.md) records current target-specific
model/effort checks; it does not qualify shared generation or Luna. Paid benchmarking
remains an explicitly authorized, fixed-scope activity, with candidate output separate
from published editions and official minutes.
