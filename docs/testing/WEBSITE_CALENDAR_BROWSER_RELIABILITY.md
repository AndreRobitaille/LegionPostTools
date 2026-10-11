# Native website calendar review navigation

Bounded #105/#84 extension, source55e091f, October11,2026. PR#118 changes only two
ordinary personal-token tests plus documentation; its exact candidate CI38115989210
passes ordinary1289/11583 then browser69/1259. Actual-main CI38116220723 passes the
same ordinary count, then browser69/1243 has one Chrome154.0.8037.97/Selenium4.51.0
Node with given id does not belong to the document inspector error in the unchanged
WebsiteCalendarSystemTest. No retries or broad exception suppression. #102 remains
open pending successful subsequent main verification; independent code merges are held.

The downloaded exact failure screenshot shows the desktop defaults form and populated
preview with the expected synthetic supper and1 shown/0 hidden, before activation or
phone resize. The displayed? stack does not identify a unique test assertion; it locates
an element query around native preview rendering. It does not establish a lost app
mutation or a new personal-token regression. The symptom predates PR#118 under#105.
Precise Chrome cause remains unverified; local Chromium152 differs from CI154.

Current actual form deliberately disables Turbo. Review defaults POST renders the preview
at /admin/website_calendar/preview, distinct from the preceding defaults GET. Apply the
same minimal native-navigation assertion used for the earlier token flow: assert the
actual preview path immediately after the real click, before DOM queries. This records
a meaningful navigation outcome and waits without querying an old document element.
Preserve every existing creation/saved event/default activation/hidden listing/meeting
attendance/no-agenda and desktop/narrow assertion. No application/UI/provider/dependency
change, sleeps, retry loop, exception rescue or direct HTTP substitution.

A narrow test-only preview redirect back to the initial defaults page must fail the new
path assertion before later content checks. Restore exact controller bytes in finally
and verify clean real browser behavior. This fault proves incorrect navigation detection;
it does not reproduce the inspector's internal cause. Review existing publication and
calendar-policy request components separately, retain their distinct token/conflict/
visibility/privacy evidence, and run final committed ordinary/system suites serially,
lint/security, exact-candidate and actual-main CI before normal merge. Synthetic test
records only; no production, member-data copy, paid AI or deployment.

Whole component review retains all six WebsiteCalendarControllerTest cases: HTML/API
publishing authority, actual signed HTML activation, delegated preview/replay/audit and
conflict, authenticated public-feed ETag/privacy/removal, meeting schedule authority
without document creation, and session CSRF. The nine WebsiteCalendarTest cases retain
explicit type/override versus attendance/legacy visibility, public schedule allowlist,
immediate changes/removal audit, approved-document independence, all-day overlap,
tampering/source changes/current authority, expiration/reuse, legacy migration versus
stories, and actual cross-Post records/signed previews. No assertion removal or safe
consolidation is established. Controller denial cases do not all snapshot every related
row; the CSRF token is deliberately invalid, so that case alone is not proof that a valid
activation is refused without CSRF. Those limits remain separate from this navigation fix.

Focused components: 15 runs / 97 assertions, seed59451,2.91s, no failures/errors/skips.
Real focused browser: 1 / 21, seed54187,4.63s; actual preview desktop1400 and phone390,
event editing and meeting-creation phone screenshots inspected. Existing content and
saved listing/attendance/no-agenda assertions remain. Wrong native redirect fails at
the new path check: 1 / 4 / 1 failure, seed25561,5.08s, no errors/skips. Finally restores
controller SHA256 f91f243e6e6eb0f33f56f6bec8cdb5f783e501b60a7186f57f7102210ea375f5.
Clean restored browser: 1 / 21, seed43119,4.34s, no failures/errors/skips. Focused lint
inspects one file without offenses; relative documentation links resolve and diff check
passes. Fresh review confirms only one added test assertion and unchanged controller.
Final committed suites/security and exact-candidate/actual-main CI remain required.
