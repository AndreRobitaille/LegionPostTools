# Optional passkey invitation continuity

Bounded #117/#84 authentication/navigation slice, source55e091f, October11,2026.
STANDARD_MEMBER_EXPERIENCE keeps the invitation optional and subordinate to Post work;
MEMBER_SIGN_IN_GUIDE preserves email sign-in and later enrollment from Profile. Actual
Dashboard eligibility is no passkeys plus no current-session dismissal flag. Actual
sign-in resets the Rails session and sign-out destroys the current Session. Test that
existing contract without changing authentication, eligibility, record fields or UI.

Retain and strengthen DashboardControllerTest's existing positive dismiss DELETE/later
GET/card-absence case, keeping all old assertions and the separate anonymous refusal.
Establish a visible invitation first and a nonempty saved identity/grant/other-person
passkey/session graph. After real dismissal, verify it is unchanged before redirect
and later own Profile/return-home reads. A separate fresh authenticated request session
must show the invitation again without granting authority or enrolling a credential.
All twenty existing Dashboard setup/recovery/expiry/meeting/activity/email cases remain.

One real-browser journey must sign in through the actual magic-link controls, click
Not now, preserve identity/grants/passkeys/session records, visit own Profile and return
home with the invitation still hidden. Real sign-out must refuse later protected access;
fresh real sign-in must show the optional invitation again. Inspect desktop1400/phone390
layouts and preserve actual saved identity before/after interaction. Request sign-in
helpers are lower-level setup, not substitutes for that browser proof. No passkey
enrollment, browser credential ceremony or clipboard claim is part of dismissal.

Omit only the controller's dismissal flag under a reversible test-only fault while
keeping its redirect. Existing strengthened dismissal must fail later card absence;
restore exact bytes in finally, record SHA256 and verify clean request/browser results.
Final committed full ordinary/system suites serially, lint/security, exact-SHA candidate
and actual-main CI are required before normal merge. No test removal/consolidation,
production, real member-data copy, paid AI or deployment. This is missing contract
evidence rather than a demonstrated runtime defect.

Initial focused requests: 27 / 151, seed36101,3.13s, no failures/errors/skips. Whole
twenty Dashboard cases, one anonymous invitation refusal and six own Profile cases
stay. Request new-session setup is explicit and preserves all old session rows while
adding exactly one authenticated Session; it does not claim browser sign-in proof.
Initial browser1/31 seed29423 passes. Refine it to preserve the actual other-person
session after sign-out/fresh sign-in and scroll the fresh phone invitation into view.
Refined browser1/33 seed43145,4.15s passes, with retained identity/grants/passkeys,
same-session Profile/return-home, real sign-out/denied Profile and fresh magic-link
sign-in. Inspected visible/dismissed/fresh desktop1400 and phone390 captures; no overflow.

Omitted dismissal flag fails at the retained original card-absence assertion:1/9/1
failure seed44205,0.63s, no errors/skips. This demonstrates preserving that useful
existing detector; it is not an original runtime defect or a claim that only new
assertions catch it. Finally restores controller SHA256
86d54e2d9f25941ab875c5fa1c7fcf523f9ea328ecfc2a07d1fbffc0a147f5b7.
Clean restored requests27/151,1.80s and refined browser1/33 pass. All original assertions
stay; no safe test removal/consolidation established. Existing AuthenticationEntry's two
real bookmark/newest-email/code phone journeys and AccountMenu's eight keyboard/profile/
sign-out/official-confirmation/phone-destination journeys remain separate retained evidence.
Their whole source was reviewed; their execution remains in the full suites, not the
new focused invocation. Main integration/final committed suites/CI remain required.


Freeze the clock in the two changed cases so the legitimate fifteen-minute session
last_seen touch cannot make unchanged-session evidence depend on runner speed. Final
focused requests27/151 seed23307,2.00s and browser1/33 seed17331,4.07s pass with no
failures/errors/skips. Auto teardown restores the test clock; no app session behavior
changes. Earlier fault preserves the retained card-absence detector.
