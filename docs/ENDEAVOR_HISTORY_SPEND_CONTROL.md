# Endeavor History spend control

October 29, 2026. Local implementation and offline verification; no paid evaluation
or production change is authorized by this document.

## Findings and scope

At baseline `524ec57`, the attestation journal creates one request per eligible Endeavor.
Each run reads the entire member-visible minutes corpus. Exact verified results are reused,
but changing the comparison catalog invalidates exact reuse for every old source.
That path first pays for a fresh discovery verification and regenerates extraction
only if verification fails. An Endeavor without saved evidence searches the whole
archive at its next qualifying attestation. This combination can multiply a small
officer workflow into many Astra requests.

The existing daily token budget limits reservations within one Rails calendar day.
Its uncapped next-day recovery branch allows unfinished work to continue spending
after midnight. It is not a dollar budget or a total cost limit for an attestation.

OpenAI's current Responses API defaults to implicit prompt cache writes. These
providers submit changing inputs as a single string. With no matching cached
endpoint, those writes cost more than ordinary input and provide no read savings.
See [prompt caching](https://developers.openai.com/api/docs/guides/prompt-caching).
The reported invoice totals and exact attribution still require production run
and provider billing evidence; source inspection cannot establish them.

## Request and recovery policy

Disable implicit caching for the minutes and Endeavor History providers using
`prompt_cache_options: { mode: "explicit" }` with no breakpoints. The API documents
this as making no cache reads or writes. Preserve the existing content, schemas,
model/effort choices, source checks, output limits, and usage accounting. This
change does not invalidate saved semantic results or schedule a historical replay.

Daily-budget failures remain terminal across date boundaries. Reconciliation must
not resume them when the clock passes midnight. A new attestation or an officer's
explicit Refresh can authorize work again. Continue the existing bounded recovery
for transport/queue/worker failures, with original authority, scope, and completed
stage reuse. Unknown timeout costs retain their reservations.

Andre confirmed that searching older minutes should require explicit Search past minutes,
with a cost warning and a simple explanation for new Endeavors. Automatic runs select
only current revisions named by the Endeavor's recorded attestation requests in matching
context, bounded by the run's frozen source snapshot. Request IDs do not establish
commit order, so selection includes all committed matching journal entries within
that snapshot rather than cutting off at the triggering event ID. This includes overlapping
requests so queue interruptions cannot lose newly attested minutes. A retry retains that scope.
Later-created Endeavors cannot inherit requests recorded for other Endeavors. Existing
queued attestation runs use the same bounded selection rather than their old full-corpus
manifest. Missing historical evidence is not an instruction to search the archive.

Carry forward source-current evidence from the latest published edition with matching
identity/guidance/generation. Preserve its original verification provenance through a
reuse event naming that edition. A catalog edit does not re-audit that historical
evidence automatically. Explicit full Refresh still audits all current sources and
comparison identities; a scoped Refresh revisits only its selected meeting and carries
other published evidence forward. Keep full-corpus run fingerprints for stale-source
protection, but put only actually covered revisions in the published edition manifest.
An unsearched meeting is never reported as a verified no-match. Corrections remove the
superseded revision; summary verification still sees all retained facts and passages.
Preserve complete source review for each selected meeting rather than using title or
keyword filtering, which can miss incidental facts in officer reports.

## Officer experience and visual direction

Approved officer review, October 29: show a single bounded search card, one short
explanation of when older discussions are useful, a Meetings selector, a money-based
cost acknowledgment, and **Search past minutes**. Creation needs one sentence:
"History will grow with future minutes. You can search older discussions later."
Use **Manage history** for officer navigation and **Meeting history** for the page title. Keep search hints, hiding/
resuming history, previous summaries, and technical processing evidence behind the
closed **More options** disclosure. Preserve the existing 1919 palette and type floors;
remove the second card border around the form to retain usable width on phones.

No-history is a neutral state. Missing optional archive coverage and catalog changes
must not create attention flags for otherwise source-current published history.
The current/available state describes the saved evidence and identity, not complete
archive coverage; coverage gaps remain explicitly reported by the member API.
Changed covered sources, changed identity/guidance, and failed requests still surface.
Expose the same history status and attention flag through the management API. Keep
`operation: refresh` and `cost_acknowledged` stable; document that the new button label
uses that existing operation. Verify these contracts before the authorized push.

The audience is a Post officer deciding whether past minutes contain useful history.
The main screen shows only that choice, the meeting selector, the cost acknowledgment,
and the search action. Delegated agents must obtain the same acknowledgment, documented
in the permission-filtered handbook. Declining or omitting it creates no paid run and
does not resume withdrawal. The screen names the cost as money spent by the Post;
the server and API enforce the acknowledgment. The website labels the existing `refresh`
operation **Search past minutes**, with `resume` labeled **Resume and search**.

Compose the existing 1919 cards and stacked forms: navy #0A2240, gold #C6A15B, cream
#F4EEDD, card #FBF7EC, and ink #1b222b. System sans for working UI, existing tracked
section labels, body/controls at least 16px and secondary text at least 14px. Use a
plain explanation and a visible checkbox adjacent to its action; keep related controls
together in the bounded column. The distinctive element is the officer's explicit
choice between future updates and searching Post records, expressed without a new
dashboard or a guessed dollar estimate. Review actual desktop, 390px, and 320px renders,
keyboard operation, missing acknowledgment, and successful submission.

## Verification

Use synthetic test minutes and an injected offline provider. Exercise real request,
worker, and reconciliation boundaries. Assert no provider calls or new runs after
a daily-budget failure at midnight or on subsequent days; prove transient failures
still recover with their original scope and authority. Verify both providers through
the installed SDK's serialized request, with no network connection. Record the
original regression failures before applying the correction. Production savings
and model quality remain separate from offline mechanism verification.

## Recorded local results

The new archive-selection, midnight-budget, and SDK cache-contract checks were run against
the original behavior: five failures in six selected tests. The cost-acknowledgment check
also failed before its controller gate was added. A later deterministic overlap scenario
reproduced loss of a superseded request's revision when journal ID order differed from
commit order; selection now uses recorded authority within the source snapshot instead.

- Full ordinary suite: `PARALLEL_WORKERS=2 bin/rails test` — 1,638 tests,
  17,174 assertions, zero failures/errors/skips. This includes immutable-record guards,
  source/permission checks, scoped/full refresh, trigger/recovery, and offline SDK tests.
- Browser suite: `bin/rails test test/system/endeavor_history_spend_test.rb
  test/system/minutes_endeavor_confirmation_test.rb` — four tests, 97 assertions,
  zero failures/errors/skips. Real magic-link sign-in, new Endeavor creation without
  spending, required acknowledgment, keyboard submission, offline worker publication,
  later reading, withdrawal, and Resume were exercised. The final screenshot-only
  capture adjustment was rerun separately: one test, 58 assertions, all passing.
- Rendered creation and history controls were inspected at 1400px, 390px, and 320px,
  including the cost acknowledgment at narrow widths. Captures are in the ignored
  `tmp/endeavor-history-spend/` directory; regenerate with
  `SYSTEM_TEST_CAPTURE_DIR=tmp/endeavor-history-spend`.
- Focused RuboCop: all 14 affected Ruby files clean; subsequent changed files rechecked.
  Brakeman 8.1.0: zero errors/warnings. Bundler Audit: no vulnerabilities reported.
  Local documentation links resolve and `git diff --check` passes.

The local Bundler version changed only its lockfile metadata during verification; that
incidental change was removed, and the final browser checks ran with `BUNDLE_FROZEN=true`.
No dependency change is included. At that initial local-verification stage, no paid provider
request, production access, commit, push, or deployment had occurred. Release verification
is recorded separately in the pull request and deployed handoff. The reported invoice attribution and actual savings remain
unverified. This implementation retains target-specific Astra discovery/verification and
Sol summary/verification; it does not introduce shared generation or a dollar budget.

## Officer-review release validation

After the approved plain-language review, the full ordinary suite passed 1,640 tests
and 17,201 assertions. The corrected-source attention assertion was then strengthened
and passed separately (one test, ten assertions). The full browser suite passed 115
tests and 6,129 assertions, including the simplified screen at desktop/390px/320px,
closed advanced options, money acknowledgment, and normal creation/search/resume.
Focused screen captures are in `tmp/endeavor-history-officer-review/`.

Full RuboCop inspected 688 files with no offenses; the later changed test was rechecked.
Brakeman reported zero errors/warnings; Bundler Audit and importmap audit reported no
vulnerabilities. The signed-in handbook test verifies the current search label, paid
acknowledgment, status fields, and midnight-retry policy before pushing. No paid AI
evaluation or production member data was used. Exact CI/release revisions and live
verification belong to the pull request and deployment handoff.
