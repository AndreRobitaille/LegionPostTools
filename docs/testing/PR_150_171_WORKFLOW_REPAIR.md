# Calendar and Buddy Checks CI repair

Investigation and intended verification, October 31, 2026. Scope: PRs #150 and #171.

## Expected workflows

Calendar members can print an ordinary five- or six-week month on one landscape
Letter page, followed by the detailed portrait schedule. Preserve complete event
titles, the quarter-inch printable inset on every page, and the existing readable
type sizes. Unusually crowded days may continue. Desktop and phone selections and
filters survive printing. Governing behavior: `docs/CALENDAR.md`.

Visual direction follows The 1919 calendar: system sans, black text on white paper,
light rules, a shared Post/month/section baseline, and the existing date hierarchy.
Adjust layout only where reproduction shows it necessary; do not shrink text or
clip event content to meet a page count. Review rendered PDFs and desktop/phone views.

A current Buddy Checks coordinator can record private care follow-up, preserve a
member's no-contact preference, and append a completed review. Both reviews remain
saved and attributable on a later visit. Ending coordinator authority removes access
on the next request. Personal calling and county reporting must not expose care notes.
Governing behavior: `docs/BUDDY_CHECKS_WORKSPACE.md`.

## Investigation and verification

- Reproduce with the submitted PR changes and PR #171's exact dependency versions.
- Trace the calendar's server-rendered PDF, font metrics, table sizing, and pagination.
- Check whether the Buddy Checks assertion observes the submitted form or saved page;
  distinguish a test synchronization failure from a failed application mutation.
- Preserve useful existing tests; strengthen visible, persisted, and later-read checks.
- Run affected component/browser workflows, relevant denial and stale/retry boundaries,
  and focused lint. Broaden after evidence identifies shared test-harness impact.
- Use synthetic test records only. Record local evidence separately from GitHub CI.

## Findings and corrections

Baseline: master `7d6a039e`, PR #150 `4fb53ecf`, and PR #171 `b0d9eaa9`.
The submitted dependency set is Lexxy 1.0.2, Rack 3.2.8, rack-test 2.3.0, and
io-console 0.9.5. No dependency was broadened beyond that PR.

### Calendar (#150)

The submitted code passes locally with Liberation Sans and Ubuntu, but the same
five-week fixture reproduces CI's extra landscape page with DejaVu Sans 2.37.
The wider glyphs and cell padding force additional title wrapping, expanding the
table beyond the landscape page. Noto Sans independently reproduces heading ink
above the quarter-inch inset, despite the explicit system-font stack in #150.

Reduce print cell padding from 4pt to 3pt, making room for wider glyphs without
changing font sizes or hiding titles. Add 2pt above the print heading for ascenders.
Retain #150's matching screen/PDF sans stack and its navigation assertions. Its
Chrome compatibility adapter translates only the detached-document visibility
error into the stale-element error Capybara already handles; unrelated errors
and clicks are unchanged. Save the five-week PDF before page-count assertions so
an enabled capture directory retains the failing document.

Font experiments used isolated temporary Fontconfig directories, including
[DejaVu's official 2.37 release](https://github.com/dejavu-fonts/dejavu-fonts/releases/tag/version_2_37)
and the host's Noto Sans files. No desktop font configuration was changed.
Local Chromium is 155.0.8059.84; the recorded CI inspector failure used Chrome 154.
These experiments reproduce the print failures, not Chrome 154's internal error.

### Buddy Checks (#171)

The final `assert_text "Care review complete"` can match the selected option on
the unsaved form. Its immediate database count can race the asynchronous POST.
No failed application mutation or Lexxy defect was established.

A test-only experiment withholding that one final submit reproduced CI's exact
failure: the old text assertion passed, then the count was one instead of two.
With the correction, the same fault fails at the expected history-page path.
This demonstrates the old false readiness signal and the new navigation detector;
it is not a claim that CI dropped the submit.

Wait for the history path, saved notice, and current-care status before checking
the two attributed revisions. Revisit the history to verify saved resolution,
preserved original notes, and the unchanged no-contact preference. Verify removal
from extra-care coverage, exclusion from the county count, and subsequent denial
after officer authority ends. Existing request coverage also exercises repeated
submissions, stale revisions, immutable evidence, caller/mobile privacy, and denial.

The actual browser journey passed with an additional 300ms of CDP network latency:
1 test / 40 assertions. The latency and withheld-submit harnesses are temporary
test-only experiments, not application code or permanent retries.

## Local verification

- DejaVu Sans: 13 calendar print tests / 300 assertions, no failures/errors/skips.
- Noto Sans: 13 calendar print tests / 300 assertions, no failures/errors/skips.
- Poppler checked every word on 134 pages across 30 generated PDFs from those runs;
  all text remains inside the quarter-inch inset, including continued descriptions.
- Reviewed the rendered five-week overview and portrait schedule; titles are complete,
  the final week fits, and the light rules and heading hierarchy remain legible.
- Reviewed the completed-care phone view with saved status and preserved notes.
- Focused RuboCop: 8 files, no offenses. Tailwind builds successfully.
- Brakeman 8.1.0: zero errors/warnings; gem and importmap audits: no vulnerabilities.

Final checks used the project's Ruby 4.0.7 and Bundler 4.0.22, with the exact PR #171
dependency versions. The default shell initially selected Ruby 4.0.9 / Bundler 4.0.20;
restore the PR's original Bundler metadata after installation rather than retaining
an incidental lockfile downgrade. Earlier font and latency experiments used that
initial Ruby toolchain and Chromium 155; the final suites below use the pinned tools.

Run ordinary and browser suites serially against the synthetic test database:

```sh
env -u DATABASE_URL RAILS_ENV=test mise exec ruby@4.0.7 -- bundle _4.0.22_ exec bin/rails test
env -u DATABASE_URL RAILS_ENV=test SYSTEM_TEST_CAPTURE_DIR=tmp/pr-150-171-final mise exec ruby@4.0.7 -- bundle _4.0.22_ exec bin/rails test:system
```

| Check | Tests | Assertions | Failures / errors / skips |
| --- | ---: | ---: | --- |
| Full Rails suite, seed 54646 | 1,642 | 17,208 | 0 / 0 / 0 |
| Full browser suite, seed 994 | 115 | 6,149 | 0 / 0 / 0 |

The full suites include care retries/stale forms/append-only evidence/privacy,
calendar delivery and navigation, and rich-text workflows using Lexxy 1.0.2.
Final screenshots cover the desktop calendar, 390px/320px phone calendar, and
desktop/390px care coverage and saved resolution. The controls remain legible and
reachable, filters wrap without horizontal overflow, and the PDF preserves complete
event names and a single-line heading. Reviewed the final default-font overview too.

Poppler independently checked all 65 pages in the final run's 15 calendar PDFs.
Together with the font variants, that is 199 pages across 45 PDFs with no text outside
the quarter-inch inset. `git diff --check` and repository documentation references pass.

This record describes the combined local candidate prepared before splitting the
fixes between PRs #150 and #171. Per-PR CI is verified separately against each pushed
revision before merge; the local results above do not establish that CI or production
verification. No production data, deployment, paid AI, or official-record actions
were involved.

## Additional sign-in boundary found by per-PR CI

PR #171's CI run 41249285101 passed all 1,640 ordinary tests / 17,204 assertions,
then failed the shared-agenda passkey browser test: authentication returned to `/`
instead of the agenda. Its Buddy Checks checks passed. The failure screenshot
shows a signed-in dashboard, not a rejected passkey.

`docs/MEMBERS_SITE_SHARING.md` requires the same-browser shared destination after
passkey sign-in. The test clicked Sign out and immediately visited the protected
agenda, overlapping asynchronous sign-out and destination capture. With 300ms CDP
network latency and seed 56703, the original test reproduced the exact wrong path.
Wait for the sign-in page and its passkey button, and confirm zero saved sessions,
before visiting the protected agenda. The corrected real virtual-authenticator
journey passes under the same latency and seed: 1 test / 19 assertions, including
saved credential use, one new session, the agenda destination, and refresh.

This is a test synchronization change; the application authentication and destination
policy stay intact. Per-PR CI must run on the additional pushed commit before merge.

The six focused sign-in and Buddy Checks browser workflows passed together with
156 assertions. PR #171's final head `102e49ac` then passed CI run 41250030272:
1,640 Rails tests / 17,204 assertions and 115 browser tests / 6,145 assertions,
with no failures, errors, or skips; lint and both security jobs passed too.
It merged as `dbe9480676cbd91b724f3c8d36da9f34922d0f38` before updating #150.

That CI run's first test attempt stopped during Ubuntu mirror downloads in
`apt-get update`, before checkout or application tests. After ten minutes without
advancing, it was cancelled and only the test job was rerun on the same source
revision. The fresh runner completed setup and both full test suites. The failed
shared-agenda assertion above was corrected in code before that green run.
