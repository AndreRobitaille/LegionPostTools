# Endeavor AI history

The [October 2 cost redesign](ENDEAVOR_HISTORY_COST_REDESIGN.md) implements incremental
reuse, retained verified evidence, scoped refreshes and resumable work locally. It keeps
target-specific extraction and independent verification; shared multi-Endeavor generation
remains an unqualified optimization. The [model and reasoning evaluation](ENDEAVOR_MODEL_AND_COST_EVALUATION.md)
records the limited live comparison and the selected profile.

Implemented locally September 6, 2026. A [live Astra evaluation](ENDEAVOR_HISTORY_AI_LIVE_EVALUATION.md)
passed on three Endeavors across the two available local minutes records. The October 2
incremental implementation and model comparison are described in the linked reports. The [design](ENDEAVOR_HISTORY_AI_DESIGN.md) and
[implementation plan](ENDEAVOR_HISTORY_AI_IMPLEMENTATION_PLAN.md) record the rationale.

## Member experience

The Endeavor detail shows an At a glance overview, upcoming published agendas, and dated
history. Meeting entries contain AI summaries when available, complete relevant outcomes,
original source passages, and links to the full minutes. Officer updates remain separately
attributed. The [reading design](ENDEAVOR_HISTORY_READING_DESIGN.md) keeps the overview
visible and meeting/officer updates collapsed. Opened meeting accounts separate recorded
decisions from discussion, with original evidence in its own disclosure. Descriptive source links appear as
sub-bullets and open a focused reader, with Close, Escape, desktop backdrop dismissal,
and focus/scroll restoration. Links also work as standalone source pages without JavaScript.
The reader serves only current related member-visible units, with no-store responses;
unavailable, unrelated, draft, and foreign-organization sources return a plain 404.
Page navigation replaces the metadata rail; officer tools remain capability-gated. Summaries
supplement the record and never alter minutes or Endeavor status.

Sources use the same member-visible revision selector as the minutes page. Draft or
approved-but-unattested text never enters this pipeline. Reopened minutes continue to
use their last attested revision. A corrected attested revision invalidates affected
summaries immediately on read; unrelated meeting history remains available. Membership
approval changes authority labels without requiring an AI call. New meetings can leave
an older overview visible with its coverage date and a newer-minutes notice.

## Automatic processing

One durable run refreshes one Endeavor across all member-visible minutes, including
unlinked reports and completed Endeavors. Discovery runs in whole-item batches and uses
the other Endeavor names/descriptions to distinguish similarly named work. Every source
item and outcome must be accounted for. A separate AI pass checks the complete source for
missed material, false matches, and unsupported facts. Summaries are generated from the
verified facts and original passages, then verified before automatic publication.

Each stage has at most one repair cycle. Unknown citations, missing required facts,
ambiguous matches, incomplete responses, budget limits, or failed verification prevent
publication. Original decisions render deterministically. No routine human review queue
exists. These checks reduce error; neither a valid JSON response nor an AI verifier proves
perfect semantic completeness. Offline tests verify mechanics, not live model quality.

Runs store source/configuration fingerprints, responses, automated findings, usage and
reserved tokens. Editions, source links, guidance, and events are append-only. Reruns
publish a replacement edition atomically; failures retain the prior valid edition.

Each Endeavor still has its own run and complete-source checks. Append-only verified results
are reusable independently of publication, including complete negative coverage. New meetings
do not re-extract the archive. Old dated accounts remain unchanged; composition writes only
affected accounts and checks an overview using all retained facts and original passages.
An unmatched new meeting does not need new prose. Catalog changes audit previous matching
before reusing it, and regenerate only where that check fails. New identities search all
eligible revisions. Ordinary new work uses two extraction/check calls per target/revision
and two writing/check calls per changed history, before any repair.

A meeting-specific manual refresh revisits that revision and the overview, retaining other
unchanged accounts. A full manual refresh remains an explicit paid operation. Automatic
recovery preserves a failed manual refresh's scope and authority and reuses completed stages.
Generation completed before interruption resumes at verification, never direct publication.
Reuse events do not invent paid token usage; failed timeout reservations remain recorded.
Model/version metadata changes alone do not trigger paid archive replay. Substantive policy
changes require a declared scoped recheck. Legacy adoption requires the exact original complete
coverage and accepting verifier; it preserves original policy and does not invent title facts.

The explicit `title-and-financial-context-1` policy upgrade checks eligibility locally.
Legacy related dated headings and relevant financial decisions involving CD/maturity/rollover
context require new extraction for those revisions. Other compatible evidence is adopted
without paid generation. This one-time scoped quality repair is separate from ordinary model
changes and reconciliation. Later updates cannot fall back from repaired evidence to an
older legacy extraction.

Whole-item discovery batches account for the complete input. Inputs that still exceed
limits (one huge item, very large catalog, or complete summary context) stop explicitly
with `input_limit`; nothing is silently truncated. Multi-level synthesis for corpora beyond
that limit is a later scaling extension, not claimed as implemented.

## Model configuration and prompts

The defaults keep `gpt-6-astra` for discovery and complete-source verification and use
`gpt-6.1-sol` for composition and summary verification. All four default stages use high
reasoning. Sol medium and high writing both passed a controlled complete-facts comparison;
high cost about 0.6 cents more for that writing/checking pass. The sample does not prove
high universally improves accuracy. The original all-Astra
settings passed the initial three-case live evaluation;
that small sample does not establish general accuracy. The adapter uses Responses, strict JSON Schema, no tools,
no sampling parameters, disabled truncation, and `store: false`.

Prompt version `endeavor-incremental-3` explicitly requests unattended completion, structured
uncertainty, concise member-facing prose, full source coverage, and preservation of
qualifiers. The overview leads with the latest recorded position; each meeting has a cited
headline and each relevant outcome has a short source-checked title (100 characters
maximum). These additions are verified before publication. Older editions remain
readable with ordinary meeting headings until refreshed. Records and clarifying guidance are untrusted data, not instructions or new
facts. The pipeline does not load repository skills or reuse civic/editorial Topics prompts.
Normalization version 2 adds separately citable titles while preserving body/outcome IDs.
Related headings containing event dates must have a title-unit citation in discovery.

The [October 2 evaluation](ENDEAVOR_MODEL_AND_COST_EVALUATION.md) records the current
official model/pricing/effort references, six high-effort writing checks, development
comparison cost, local recurring-cost estimate and final regression results.

Verified against [OpenAI's Astra guidance](https://developers.openai.com/api/docs/guides/latest-model?model=gpt-6-astra),
[model reference](https://developers.openai.com/api/docs/models/gpt-6-astra), and
[Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs)
on September 6, 2026. The existing transcript drafting adapter is separate and unchanged
by this feature.

| Variable | Default / purpose |
| --- | --- |
| `ENDEAVOR_HISTORY_ENABLED` | Disabled unless `1`; allows generation and automatic reconciliation. |
| `OPENAI_ENDEAVOR_MODEL` | Optional override for every stage; otherwise the defaults below. |
| `OPENAI_ENDEAVOR_DISCOVERY_MODEL` | `gpt-6-astra` |
| `OPENAI_ENDEAVOR_VERIFY_DISCOVERY_MODEL` | `gpt-6-astra` |
| `OPENAI_ENDEAVOR_SUMMARY_MODEL` | `gpt-6.1-sol` |
| `OPENAI_ENDEAVOR_VERIFY_SUMMARY_MODEL` | `gpt-6.1-sol` |
| `OPENAI_ENDEAVOR_DISCOVERY_REASONING` | `high` |
| `OPENAI_ENDEAVOR_VERIFY_DISCOVERY_REASONING` | `high` |
| `OPENAI_ENDEAVOR_SUMMARY_REASONING` | `high` for Sol; `medium` when the summary model is Astra, preserving the original baseline. |
| `OPENAI_ENDEAVOR_VERIFY_SUMMARY_REASONING` | `high` |
| `ENDEAVOR_HISTORY_MAX_INPUT_BYTES` | `180000` serialized bytes per request. |
| `ENDEAVOR_HISTORY_MAX_OUTPUT_TOKENS` | `24000` including reasoning. |
| `ENDEAVOR_HISTORY_MAX_CALLS` | `40` per run, including repairs/verifiers. |
| `ENDEAVOR_HISTORY_DAILY_TOKEN_BUDGET` | `500000` per organization/day, enforced with reservations. |

Explicit stage reasoning overrides take precedence. Model and effort are recorded per
attempt; completed-call recovery requires the exact stage configuration. Verified result
reuse requires the current verifier profile or the established Astra/high profile, so an
effort increase cannot silently accept a result checked at a lower effort.

Supported configured reasoning efforts: low, medium, high, xhigh, max. The provider uses
the existing OpenAI credential lookup. Never put keys or source transcripts in logs.
Before a call, conservatively reserve input, instruction, and schema bytes plus maximum
output tokens. Replace the
reservation with actual usage on success; an unknown-cost timeout retains its reservation.
This is a token limit, not a dollar guarantee. The provider does not transparently retry
paid requests. Daily spending should also be limited at the provider account level.

## Administration and API

Users with `manage_agendas` see **AI history** from the Endeavor detail. They can inspect
runs, source coverage, verification findings, prior editions, and usage; refresh the full
history; save/reset versioned guidance; and withdraw/resume generation. Guidance saves
invalidate old generated text until refreshed. Withdrawal persists across automatic jobs.
Resume queues a fresh run when processing is enabled and sources are available. A failed run can be retried through Refresh, preserving its
failed attempt. Successful processing publishes automatically, with system provenance.

`GET /api/endeavors/:id` includes member history and a `next_cursor`; send it as `before`
for earlier complete meeting groups. Management uses `GET`/`POST /api/endeavors/:id/history`.
POST accepts operation `refresh`, `guidance`, `withdraw`, or `resume`. The last three
require the current `lock_version`; guidance accepts up to 4,000 characters (blank resets).
Refresh optionally names `meeting_id` to revisit only that record and the overview. Other
unchanged dated accounts are retained. Omit it to explicitly revisit all records for this
Endeavor. Run responses include `reuses` with provenance; `steps` describe paid attempts.
Bearer writes use the existing idempotency header and retain delegated provenance.

Jobs includes Endeavor runs without exposing private minutes-drafting runs to users who
only manage agendas. Manual requester capability and token validity are checked again
before queued work and publication. Automatic runs record system actions under the
installation's enabled processing policy.

## Post 165 activation

The Post 165 deployment profile enables `ENDEAVOR_HISTORY_ENABLED=1` with the default
500,000-token daily organization budget. Deployment runs `db:prepare` before starting
Rails; the initial authorized backfill uses the existing bounded task and normal worker.
Other installations remain disabled unless explicitly configured.

## Activation and recovery

Run relevant tests and evaluate explicitly authorized real-data samples before enabling
production processing. The migration adds derived tables and freezes primary identity
only in future approval payloads; it never backfills or rewrites existing minutes.

`bin/rails endeavor_history:inventory` is read-only and reports current eligible revision
IDs/digests and prior run states. A bounded initial queue operation is
`LIMIT=10 AFTER_ID=0 bin/rails endeavor_history:backfill`; use its `next_after_id` to continue.
The task requires activation and may incur paid usage when workers execute.

When enabled, attestation/new-Endeavor events and a 15-minute reconciliation job ensure
all eligible Endeavors are processed, including existing history. Budget and call limits
bound paid processing; choose them deliberately before activation. Identical automatic
requests reuse prior success/failure state. Transient queue/provider/stalled failures get
at most three attempts per fingerprint with a delay; semantic failures await an admin
rerun. Daily-budget failures retry automatically on the next day. Stalled running jobs expire after 15 minutes without a heartbeat. No exactly-once
provider-cost guarantee is possible after a timeout.

Disable generation with `ENDEAVOR_HISTORY_ENABLED=0`, or withdraw a particular Endeavor's
generated history. Withdrawal also suppresses its generated member display. Source minutes,
frozen primary associations, and audit editions remain intact. Use the repository release
entry point for an authorized deployment; this feature does not grant official-record
approval or deployment authority.

## Local verification — September 6, 2026

- Full Rails suite: 868 tests, 5,460 assertions, no failures/errors/skips.
- After including prompt/schema bytes in token reservations, the focused history suite:
  18 tests, 81 assertions, no failures/errors/skips.
- Focused RuboCop: 39 files, no offenses; the final reservation edit also passes.
- Zeitwerk eager loading, Tailwind build, and documentation links/diff whitespace pass.
- Brakeman: no errors or security warnings. Cached Bundler Audit: no vulnerabilities.
- Browser checks use a separate synthetic database, with member/admin pages at 1440px
  and 390px, no horizontal overflow, and keyboard-operated source disclosures with
  visible focus. No production or development member records were changed by these checks.

Provider tests use synthetic responses. These results do not establish Astra's recall or
summary accuracy on real minutes. The subsequent authorized live evaluation and its
limited source-comparison findings are recorded separately in the linked report.
