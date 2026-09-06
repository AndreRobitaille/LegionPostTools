# Endeavor reasoning comparison

Compare the current production profile (high discovery and verification, medium summary)
with all-medium and all-low Astra profiles across all six current Endeavors. Preserve the
published histories the user considers accurate. Use a read-only snapshot of the exact
member-visible source revisions, prompts, guidance, catalog, and accepted production
editions. Evaluation writes private local artifacts only; it never requests a history run
or publishes to the application database.

Reuse the production discovery, schema validation, independent verification, and bounded
repair methods. Measure complete pipeline usage including repairs, failures, and elapsed
time. Record input/output/cached/reasoning usage where supplied; distinguish uncached-rate
estimates from billed charges. Compare substantive facts and caveats, not sentence count
or identical prose. Structural citation coverage is necessary but not a recall metric.

Inspect all candidates against original sources and the production baseline. Pay particular
attention to election motions/votes, donor qualifiers, July Car Show date discrepancy,
newsletter recommendation versus adopted decision, Ethnic Fest event/planning dates and
unconfirmed electricity, website current versus possible functionality, and SnowFest
planned versus actual participation plus the later minutes-correction discussion. Use a
separate fixed-high audit with profiles hidden; resolve its findings against source text.
The production baseline is a reference, not authority overriding the minutes.

Timing audit: new/corrected attestation should queue history after commit; draft changes,
Commander approval, and unchanged-revision membership approval should not incur AI calls.
Agendas are live published links, not AI evidence. Reconciliation must deduplicate unchanged
inputs and recover a missed callback. Corrections must hide only superseded generated
content while keeping the last attested source visible until replacement attestation.

## Results — September 6, 2026

The production baseline was reused; no published editions or model settings were changed.
All candidates used `gpt-6-astra`, prompt `endeavor-astra-2`, digest
`becb6aeefd7ddde923c66559d6aaf8e9eb8c28616535514553cc7a5f7cf70706`, and the same two
member-visible source revisions (70 minutes items) per Endeavor. The profiles differ only
in reasoning effort. All-medium/all-low apply that effort to discovery, discovery
verification, summary generation, and summary verification, including repairs.

| Profile | Calls | Input tokens | Output tokens | Total tokens | Uncached standard-rate estimate |
| --- | ---: | ---: | ---: | ---: | ---: |
| Production: high / high / medium / high | 44 | 361,700 | 75,540 | 437,240 | $7.39 |
| All-medium | 40 | 311,432 | 46,316 | 357,748 | $5.43 |
| All-low (boundary test) | 44 | 345,080 | 44,665 | 389,745 | $5.68 |

Medium used about 27% less estimated cost than the baseline in this sample. Low was
slightly more expensive than medium because it needed more repairs. Differences include
stochastic generation length and repair behavior, not just reasoning tokens. The new
candidates recorded 2,193 reasoning tokens for medium and 582 for low; the old baseline
provider did not record the reasoning-token breakdown.

Rates use $10/million input and $50/million output for an apples-to-apples comparison;
these are not invoices. The current API also reports cache writes, billed at 1.25x input
rates. Including reported cache writes gives approximately $6.21 for medium and $6.55 for
low. Baseline cache details were not captured, so its actual cache-adjusted charge cannot
be reconstructed from the application records. The provider now records cached input,
cache writes, and reasoning tokens for future diagnosis (local change, not deployed).
See [Astra model pricing](https://developers.openai.com/api/docs/models/gpt-6-astra).

| Endeavor | Baseline calls / estimate | Medium | Low |
| --- | --- | --- | --- |
| Officer election | 8 / $1.67 | 6 / $0.92 | 8 / $1.22 |
| Car & Bike Show | 8 / $1.54 | 8 / $1.23 | 8 / $1.10 |
| Newsletter | 6 / $0.84 | 6 / $0.77 | 6 / $0.70 |
| Ethnic Fest | 8 / $1.28 | 8 / $1.02 | 8 / $0.98 |
| Members Website | 6 / $0.78 | 6 / $0.70 | 6 / $0.69 |
| SnowFest | 8 / $1.27 | 6 / $0.78 | 8 / $0.99 |

### Source fidelity

All 12 lower-effort pipelines passed their own structural and model verification. A
separate fixed-high audit then compared anonymized versions against the complete source
records; profile labels were withheld and their order rotated. That additional audit
accepted the six baselines, five medium candidates, and four low candidates.

- Low Car Show omitted the CD balance ($20,574.04), interest ($70.93), maturity date, and
  automatic rollover context attached to the decision allocating half the show profit.
  Original sources and baseline/medium claims contain those details; the low candidate
  does not. Its low verifier accepted the omission.
- Medium and low Ethnic Fest omitted the event's September 19 date from the September
  meeting account even after a discovery repair. Both preserve it in the overview and
  July account, so it is a per-meeting completeness regression rather than an invented or
  globally lost date. The date is in the item title, separate from the September 8
  volunteer-planning meeting in the paragraph. This is a useful regression case for
  source-title handling and verification, regardless of reasoning level.
- The election, Newsletter, Members Website, and SnowFest passed the additional audit
  under both lower-effort profiles. Manual inspection also checked the election request
  versus guest compliance, Newsletter recommendation, and SnowFest intended versus actual
  participation/correction chronology against the sources.

The audit is another model assessment, not independent human ground truth. Findings above
were checked against the source and candidate text. This is one run per profile on six
Endeavors sharing two records; it cannot establish population-wide recall or failure rates.

### Low for focused work

Following the user's clarification, low is not proposed for substantive summary writing.
A separate test supplied 12 short source-bound claims: six correct claims and six deliberate
errors involving donor scope, guest-request versus compliance, event versus planning dates,
unconfirmed electricity, a recommendation versus a vote, and a lost versus adopted motion.
Each model judged the same shuffled claims against their original individual source items.
Expected answers were set before calling the models and withheld from them.

Both low and medium answered 12/12 correctly in one batch each. Low took 8.3 seconds and
used 5,066 tokens (zero reported reasoning tokens); medium took 10.2 seconds and used 5,205
(116 reasoning tokens). Uncached-rate estimates were about $0.064 and $0.071, respectively.
These small examples support low for focused source checks; they do not justify replacing
whole-history completeness verification with low or adding unnecessary extra calls.

### Publication timing

New regression tests verify:

- New/corrected attestation enqueues organization reconciliation after the transition.
- Draft edits, reopening, and Commander approval do not start history generation; the last
  attested history stays readable while corrections are drafted.
- Replacement attestation immediately withholds superseded generated content.
- A later membership approval of the same revision changes authority to Official minutes
  without changing the AI input manifest or enqueueing generation.
- Periodic reconciliation recovers a missed immediate job; an unchanged completed run is
  reused without another paid job.
- Agenda reopening/republishing updates member-visible links without creating AI runs.

Attestation is the correct existing publication boundary. The 15-minute reconciler is a
fallback; it is not a scheduled paid regeneration of unchanged histories. The remaining
cost improvement is incremental reuse of verified unchanged meeting evidence, which this
comparison does not implement. Formal later amendments still need their own source adapter
and publication hook when that workflow is built; corrections today use re-attestation.

### Mixed profile and recommendation

A follow-up reran Ethnic Fest with medium discovery/summary and high verification at both
stages. It completed in eight calls and 69,150 tokens. The first high verifier flagged the
missing September 19 event date; the medium repair still omitted it from September's facts,
and the next high verification accepted the result. Direct inspection confirmed the same
per-meeting omission. Higher verification effort alone does not resolve this coverage gap.

Keep substantive summary writing at medium, which is already the production setting.
Low is promising for bounded checks against a small, explicit source, not broad extraction
or completeness verification. All-medium processing offers meaningful potential savings,
but it is not yet a demonstrated equivalent replacement for the existing pipeline. Before
changing the broader production profile, strengthen coverage of facts in source titles and
rerun this regression case. No runtime defaults, prompts, or published histories were
changed by this comparison.

### Verification and evaluation cost

The combined focused suite passed: 35 tests, 241 assertions, zero failures, errors, or
skips. Focused RuboCop passed for all five Ruby files, and `git diff --check` passed.
The new provider telemetry records reasoning tokens and cache usage; the evaluation harness
reads a fixed snapshot and writes local artifacts without modifying application records.

The complete new evaluation used 100 calls, 837,740 input tokens and 108,235 output tokens
(945,975 total), including the blind audits, focused checks, and mixed-profile follow-up.
Estimated cost is $13.79 at uncached standard rates, or $15.85 including reported cache
writes. These are usage-based estimates, not confirmed billing charges, and exclude the
previous production baseline runs. Production snapshot access used a persistent SSH
connection, which was closed afterward. These local changes have not been deployed.
