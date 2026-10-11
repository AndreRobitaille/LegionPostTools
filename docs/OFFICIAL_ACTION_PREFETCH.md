# Stable confirmation during ordinary navigation

Design for #89/#84, October 10, 2026. Existing identity-bound minutes confirmation
requires an exact pending request, matching user/session, one-use proof and unchanged
record version/digest. Preserve those rules and the established 1919 screens.

Final serial system verification observed a parallel heading-form response completing
after a confirmation page. The following request had the same authenticated Session
but no cookie-stored pending ID. The bundled Turbo client prefetches hovered links.
Reproduce with a real hover and an isolated delayed speculative form response before
calling this a confirmed cause; record the result rather than retrying until green.

If confirmed, disable Turbo link prefetch in the private application layout. Clicked
navigation and form submissions keep their current behavior. This removes speculative
requests that may write an older Rails session cookie over a new confirmation context;
it trades prefetch speed for continuity without changing authentication or authority.
The visual direction remains existing readable forms, status feedback and navigation.
No new controls, styles, permissions or record lifecycle are introduced.

Use a synthetic real-browser attestation with the normal email code controls. Delay only
the test's heading prefetch response; restore its callback in teardown, release any
waiting response on failure, and assert completed revision/attestation/one-use provenance.
Retain stale-record, wrong-session, passkey and sign-out component/browser tests. Run full
ordinary/system suites serially and require exact-SHA CI before merging.

This scoped change does not claim to solve every manual parallel-tab CookieStore race.
Server-side confirmation/session architecture would require separate design. No production
operation, real member data or paid provider call is part of this work.
