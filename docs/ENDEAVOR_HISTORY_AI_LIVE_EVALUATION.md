# Endeavor history live Astra evaluation — September 6, 2026

The user authorized live testing against the local development minutes. Generation was
enabled only inside the evaluation runner, with the normal pipeline and provider. The
installation-wide background processing switch remained disabled. Successful editions
were published automatically into the local app, as designed. Production was untouched.

## Scope and settings

Three cases exercise different relevance and preservation problems: Car & Bike Show 2026,
Post Officer Election 2026, and Newsletter. Each run scans all 35 items in each of the two
member-visible revisions, including unlinked reports. These are July 7 official minutes
and September 1 attested minutes. The historical approval payloads contain no frozen
Endeavor IDs, so discovery must find the contextual associations itself.

- Model: `gpt-6-astra`, confirmed in live responses.
- Discovery and both verification stages: high reasoning.
- Summary: medium reasoning.
- Prompt: `endeavor-astra-1`; normalization: `1`.
- Prompt digest: `8c27d6bd64876ac150780ccbef4242e326a03193b39003cc4e1f77ed7890c901`.
- No administrator guidance, manual content editing, or official-record actions.

Source revision fingerprints:

| Revision | SHA-256 |
| --- | --- |
| 1 | `c6053dcd6c793cd12c427e2e5f82176f2f32d027c099756197f7c544bbac6434` |
| 2 | `1153d0d33263bc0ec0a24841f35734630d698fb17f1ddf9eefed228dffcafc96` |

## Results

The completed run records preserve the candidate output, independent verifier findings,
source manifest, request/response identifiers, and usage. Local run and edition IDs are
installation-specific and are not identifiers to reuse elsewhere.

| Endeavor | Run / edition | Calls | Total tokens | Overview words | Preserved facts / source items |
| --- | --- | --- | --- | --- | --- |
| Car & Bike Show 2026 | 1 / 1 | 6 | 60,541 | 80 | 18 / 7 |
| Post Officer Election 2026 | 2 / 2 | 6 | 65,725 | 90 | 26 / 5 |
| Newsletter | 3 / 3 | 6 | 50,664 | 81 | 9 / 2 |

### Car & Bike Show

Source comparison found the car-show account balances, July donor outreach, kitchen and
volunteer planning, September donor counts, class sponsorships, publicity, county-fair
promotion, and Honor Guard flag-raising times preserved. The adopted Finance motion
retained the 10-month CD renewal, September 30 date, and half-show-profit allocation.

The July item heading names July 5 despite discussion of planning after July 13. The
meeting summary explicitly retains this unresolved discrepancy rather than silently
correcting it. Ethnic Fest's unconfirmed electrical service does not appear in the Car
Show member payload. Summary citations resolve to current source items.

The two meeting summaries are 84 and 144 words, with an 80-word overview. Original
passages remain expandable and the relevant motion renders directly from its source.

### Officer election

The two-year proposal remains defeated, with 12 votes for and 16 against. The adopted
one-year term retains its reason: returning to odd-year elections and subsequent two-year
terms. Nominees, candidate statement themes, the bylaw dispute and future review,
observer/ballot checks, election totals, acceptance, oath, guest-exclusion motion, and
Adjutant appointment survive in the dated history. A later newsletter report is associated
only for its explicit election-related departure; the summary does not invent a motive.

The July meeting account is 398 words because it preserves 25 facts and several distinct
procedural decisions. The overview is 90 words. This illustrates the intended compromise:
a short overview with a longer complete meeting account when the source warrants it.

### Newsletter

The overview preserves the July conditional distribution plan and distinguishes it from
the September report: the preparer had left, the draft was unrecoverable, restarting
required continuing coordination, and no volunteer was identified. The later hold stays
a Commander recommendation, not an invented membership decision. The approximate
79-member email reach and email-address/junk-folder advice survive in the meeting account.
The overview is 81 words.

## Assessment and operational outcome

All three runs succeeded with six calls each: discovery and verification for each meeting,
then summary and final verification. All nine verifier responses passed with no issues;
there were no repair calls, manual edits, or clarifying-guidance interventions. Total
reported usage was 176,930 tokens (including reasoning). This is usage, not a dollar-cost
estimate. Run durations were approximately 3:08, 3:22, and 2:12 respectively; the first two
overlapped. The existing default model, reasoning levels, and prompts required no changes.

A source-by-source comparison against a checklist prepared during the run found no
substantive omissions, unsupported claims, or incorrect associations in these three
cases. This is a qualitative assessment on two short meeting records, not a statistically
measured recall score or proof for larger/ambiguous corpora. Long-input limits, overlapping
annual identities, automated repair behavior, and future prompt/model changes still need
appropriate regression coverage; offline failure tests remain relevant.

All 70 source items were accounted for per Endeavor. The member presentation resolves
citations to the current revisions, and relevant decisions retain their original source
wording, dispositions, and vote details. Before/after comparisons of revision IDs, stored
hashes, payload hashes, and update timestamps found no source-revision changes.

The three editions remain available for local inspection through their Endeavor pages
and **AI history** admin screens. Automatic background generation is still disabled;
no production processing, commit, or deployment occurred. The three other Endeavors
(Ethnic Fest, Members Website, SnowFest) were not generated in this bounded evaluation.

## Reading-design refresh: prompt version 2

The same three Endeavors were refreshed locally with `endeavor-astra-2`, adding verified
meeting headlines, neutral decision titles, and latest-recorded-position-first overviews.
The model and reasoning levels remained unchanged. Each run again accounted for all 70
source items across the two revisions; all published claims resolve to source citations.

| Endeavor | Run / edition | Calls | Reported tokens | Result |
| --- | --- | --- | --- | --- |
| Car & Bike Show 2026 | 4 / 5 | 8 | 86,237 | Passed after automatic summary repair |
| Post Officer Election 2026 | 5 / 4 | 6 | 67,312 | Passed first attempt |
| Newsletter | 6 / 6 | 6 | 51,072 | Passed first attempt |

The Car Show verifier rejected “Donor outreach nearly complete” because omitting “major”
broadened the source statement while other raffle contacts remained. The automatic repair
changed the headline to “Major-donor outreach nearly complete; planning meeting date still
unset.” Reverification passed and publication required no manual intervention. The rejected
candidate remains in the run history. This is one observed successful repair, not a general
accuracy guarantee.

The refresh used 20 calls and 204,621 reported tokens, including reasoning. Combined with
the initial evaluation, reported usage was 381,551 tokens. Source revision IDs, stored and
payload hashes, and update timestamps remained unchanged. Background processing remains
disabled; only these local editions were refreshed.

Browser checks at 1440px and 390px covered the refreshed examples, descriptive source
sub-bullets, decision cards, exact-source reader, dismissal/focus/scroll behavior, full
minutes navigation and return, and ordinary-member versus manager controls. The complete
test suite passed with 874 tests and 5,515 assertions; Brakeman reported no warnings.
