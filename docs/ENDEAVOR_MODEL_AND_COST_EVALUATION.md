# Endeavor model, reasoning and cost evaluation

October 2, 2026. Evaluation was performed locally; this report records comparison
evidence and estimates rather than a measured monthly production bill. Release
verification is separate from the evaluation.

## Selected profile

| Stage | Model | Reasoning |
| --- | --- | --- |
| Complete-source discovery | GPT-6 Astra | high |
| Complete-source discovery verification | GPT-6 Astra | high |
| Dated accounts and overview | GPT-6.1 Sol | high |
| Account and overview verification | GPT-6.1 Sol | high |

The main efficiency change is durable reuse: a new meeting does not extract old minutes
again, unchanged dated accounts remain byte-identical, and interrupted work resumes from
completed stages. Unmatched new meetings need no new prose. Catalog changes audit prior
matching rather than automatically rewriting it. The implementation retains separate
complete-source checks for each Endeavor; shared generation remains unqualified.

Discovery stays on the existing Astra/high profile because the Sol comparison is too
small to establish equal completeness across all identities and ambiguous cases. Luna
was considered from current documentation but has not been evaluated or selected for
this runtime. Minutes drafting uses its existing separate configuration.

## Current documentation and billing

Official OpenAI documentation was checked on October 2:
[Sol](https://developers.openai.com/api/docs/models/gpt-6.1-sol),
[Astra](https://developers.openai.com/api/docs/models/gpt-6-astra),
[Luna](https://developers.openai.com/api/docs/models/gpt-6-luna),
[model selection](https://developers.openai.com/api/docs/guides/model-selection),
[reasoning](https://developers.openai.com/api/docs/guides/reasoning), and
[prompt caching](https://developers.openai.com/api/docs/guides/prompt-caching).

Standard short-context prices per million tokens:

| Model | Ordinary input | Cached input | Cache writes | Output, including reasoning |
| --- | ---: | ---: | ---: | ---: |
| Astra | $10 | $1 | $12.50 | $50 |
| Sol | $2 | $0.10 | $2.50 | $10 |
| Luna | $0.10 | $0.01 | $0.125 | $0.50 |

The $12.50 figure is Astra's cache-write rate, not a monthly forecast. At identical
ordinary-input/output/cache-write counts Sol is 80% cheaper; task savings depend on
actual tokens, reasoning, failures and repairs. Cache writes are an input category, not
an additional ordinary-input charge. Reasoning is already included in output usage.

Sol supports low, medium, high, xhigh and max; medium is its API default. The application
explicitly selects high for Sol writing. Raising effort can change quality, latency and
output cost; using an identical effort label on Astra and Sol does not prove equivalent
work. Existing all-Astra overrides retain the original medium writing default. Explicit
stage effort overrides take precedence, and attempts record both model and effort.

## Comparison scope and isolation

The comparison used a read-only local snapshot of two member-visible immutable minutes
revisions, July 7 and September 1, with 35 items each. Restricted transcripts were not
replayed. Candidate outputs were written to private files and were never applied to
history editions, official minutes, or development/production records.

The existing Astra outputs were comparison artifacts, not ground truth. Material dates,
amounts, dispositions, qualifications and source associations were checked against the
original passages. Structural checks require complete item/outcome coverage, valid
source/fact IDs and every required dated fact. A separate verification request reads
the candidate and original evidence. Verifier acceptance alone is insufficient evidence
of completeness.

### Initial Sol comparison

The first comparison kept the original high discovery/high verification/medium writing
efforts. Two cases used the original prompt and normalization, followed by four complete
cases using the revised heading/financial-context policy. It used 41 calls, including
repairs and an unfinished fifth revised case, at an estimated $1.6827835 from actual
reported usage. The declared benchmark allowance stopped the unfinished case before
another call; it was not counted as a passing case.

| Revised case | Extracted facts across two meetings | Material source checks |
| --- | ---: | --- |
| Election | 28 | Separate defeated/adopted alternatives, vote totals, appointments, and a request versus evidence of compliance. |
| Car Show | 23 | Account/CD balances and interest, maturity/rollover/term, donor qualifiers, volunteers, and conflicting heading/planning dates. |
| Newsletter | 11 | Recommendation versus decision, unfilled responsibility, lost prior material and approximate distribution count. |
| Ethnic Fest | 12 | Event date in both headings, separate planning date, expected spaces and unconfirmed electricity. |

Car Show composition needed one repair in each original/revised profile after a headline
dropped the word "major" from the donor qualifier. The independent verifier blocked that
overstatement. The initial original-policy Sol extraction also omitted CD context while
passing verification. The latest stored Astra edition had the same omission, although an
earlier Astra edition retained it. This is evidence for improving the source contract
and explicit quality repair, not for claiming either model always finds every fact.

A separate four-call writing probe used an older 20-fact Astra reference. It cost
$0.1836515 and did not qualify: its facts omitted the heading-date discrepancy required
by the new policy. Repair improved qualifiers and future-action wording but could not
produce a supported missing fact. This incompatible reference was excluded from the
controlled effort comparison. The benchmark records retain both failed attempts.

### Controlled writing-effort comparison

Both profiles received the same complete 23-fact Car Show input, original source units,
prompt and strict schema. Summary verification used Sol/high in both. Neither profile
needed a repair; structural checks and source inspection found all 23 facts preserved,
including the original date discrepancy and financial context.

| Writer effort | Writer reasoning tokens | Writing + verification cost | Combined latency |
| --- | ---: | ---: | ---: |
| medium | 62 | $0.087472 | 48.42 seconds |
| high | 823 | $0.093477 | 61.37 seconds |

High added $0.006005, approximately 6.9%, for that accepted writing/checking pass. The
writer itself used 2,330 total output tokens at medium and 3,143 at high; reasoning is
included in those counts. High is selected as a conservative writing setting at this
small cost. This single comparison does not establish that high universally improves
accuracy, nor qualify xhigh/max or lower-effort discovery.

### Final high-effort writing checks

The selected Sol/high writing and Sol/high verification profile is additionally checked
on Election, Newsletter, Ethnic Fest, Members Website and SnowFest. Current complete facts
are used for the first three. The last two use source-checked legacy facts with current
source units; SnowFest's existing July 25 fact also cites its matching heading. These
are writing tests, not new measurements of Astra or Sol discovery recall.

| Case | Required facts | Writing attempts | Accepted writing/checking cost |
| --- | ---: | ---: | ---: |
| Election | 28 | 2 | $0.219674 |
| Car Show, controlled high profile above | 23 | 1 | $0.093477 |
| Newsletter | 11 | 1 | $0.0652245 |
| Ethnic Fest | 12 | 1 | $0.0616795 |
| Members Website | 7 | 1 | $0.051587 |
| SnowFest | 12 | 1 | $0.069432 |

All 93 reference facts survived in the dated accounts. Source inspection confirmed the
material qualifiers: planned versus actual participation, a recommendation versus an
adopted decision, future website capabilities, unconfirmed services, and the later
SnowFest correction/review. Election needed one repair after the first overview led with
older material and a decision title omitted the failed proposal's disposition. The
verifier blocked that candidate; the repaired output retained the exact votes and
separate adopted/defeated alternatives. High effort did not remove the need for checking.

The final five additional cases used 12 calls and $0.467597. Across all comparisons,
including failed probes and unfinished work, **61 calls cost an estimated $2.514981**
from reported usage. No unknown-cost reservations remained. The final declared ceiling
was $3.25. This is development evaluation usage, not ordinary monthly operating cost.
Six examples and one controlled effort comparison provide limited qualification for
the selected writing profile; they cannot establish general accuracy or discovery recall.

## Expected recurring cost

The local September 6 initial six successful history runs contained two source meetings
each. Their Astra discovery/verification calls, including a discovery repair, cost about
$4.56 at current standard rates. One comparable new meeting averages about $0.38 per
Endeavor. Across eight current Endeavors that suggests about $3.04 for discovery/checking.
Repricing those historical writing/checking token counts at Sol rates adds about $0.76
if all eight histories change, including the writing repairs in that sample.

That gives an illustrative **about $4 per new meeting for history**, or **about $5 including
one minutes draft** near the latest local $0.87 drafting estimate. One such meeting/draft
monthly suggests about $5; two suggest about $10. These are extrapolations from local
usage, not a production forecast or guarantee: the new prompts, high Sol effort, actual
affected histories and repair rates can change the result. The controlled high writer's
9.35-cent pass is consistent with this scale but does not validate the whole estimate.

Routine reconciliation and page reads make no paid calls. New identities, catalog
audits, corrected sources, explicit refreshes and the one-time legacy quality repair
add justified work. Report those separately from ordinary meeting updates and model
benchmarks. The deployment's actual usage must establish the monthly cost; the shared
four-call design envelope is not the implemented target-specific pipeline's cost.

## Regression verification

The implementation checks archive reuse, complete negative coverage, byte-identical old
accounts, selected-meeting refresh, budget recovery before/after verification, preserved
manual authority, catalog conflict handling, immutable derived evidence, heading citations,
legacy provenance/adoption, chronology and source/permission changes before publication.
Raising verifier effort audits lower-effort cached facts rather than accepting them as
equivalent. Reuse is reported separately from paid attempts in HTML and API.

- `bin/rails test`: 1,105 tests, 8,181 assertions, no failures/errors/skips. System tests
  are separate.
- Before release, `bin/rails test:system`: 45 tests, 546 assertions, no failures/errors/skips.
- Focused RuboCop: 21 changed Ruby files, no offenses.
- `bin/rails zeitwerk:check`: passed.
- `bundle exec brakeman --no-pager`: installed Brakeman 8.0.6, zero errors/warnings.
  The `bin/brakeman` wrapper's latest-version gate requires 8.1.0 and did not pass;
  no scanner package was installed or changed for this task.
- Migration: applied successfully to the test database. A separate transactional
  down/up smoke check verified direct SQL update/delete rejection, then rolled back all
  schema/data changes. Rails' Ruby schema dump does not include those SQL triggers, so
  schema-loaded tests alone do not validate the database guard.
- Synthetic rendered management page: desktop 1440px and narrow 390px, no horizontal
  overflow, readable type, labelled controls and visible keyboard focus. The static
  preview omitted unrelated asset serving; the unchanged logo was not visually verified.
- Local documentation link targets and `git diff --check`: passed.

During evaluation, automated mutations and browser fixtures used test data only. No
development/production records or official minutes were changed; evaluation did not
perform deployment, commit or push operations.
