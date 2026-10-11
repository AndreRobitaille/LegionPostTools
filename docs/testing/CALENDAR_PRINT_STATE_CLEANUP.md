# Calendar print-media failure cleanup

Bounded #137/#84 test-harness investigation, source95a38a3, October11,2026.
CalendarRefinementsTest enables actual Chromium print media and returns to screen only
following assertions. A failing assertion can skip that normal restoration; teardown
currently resizes only. CalendarPrintTest already restores screen media in teardown.
Locked Capybara3.40's Chrome reset navigates to about:blank and clears storage, without
an explicit media reset. This is a candidate to reproduce, not a known product/CI bug.

Use only synthetic records and the isolated legion_calendar_print_state_test database.
Temporarily add an ordered pair to the current class: first real magic-link/calendar
journey enables print, proves print media and deliberately fails; second checks screen
before real magic-link/calendar navigation. Expected original detector is inherited print
media or hidden screen controls in the second case. The first deliberate failure is not
an application defect. If reset isolates media, record the disproof and change no harness.

If reproduced, add only the existing screen-reset pattern to this class's teardown.
Repeat the exact controlled pair: the deliberate first failure remains; the second
screen check and actual sign-in/calendar navigation succeed. Remove all temporary tests
and ordering, preserve every existing assertion and verify exact restoration apart from
the intended teardown line. Run calendar/print browser neighbors, then final committed
full ordinary/system suites serially, lint/security and exact-candidate/actual-main CI.
No product styling, authority, timeout, retry, skip, broad rescue, production or paid AI.

Original temporary pair fails2/4/2, seed38097,2.35s: the first deliberately interrupts
normal restoration after proving actual print; the second inherits print media despite
normal failed-case teardown/session reset. The scoped teardown reset repeats2/8/1,
seed52608,2.99s: only the deliberate first failure remains, and the second proves screen
media plus real magic-link sign-in/current calendar header, filters and own event.
Remove both temporary cases and ordering. Exact original source is retained apart from
the one intended teardown restoration; no test failure/ordering or product change remains.

## Accurate retry scope (#139)

The API case claiming every current mutation family contains eight original agenda/
Endeavor actions. Rename only that declaration to describe those eight. Keep its body,
fixtures, helper and every assertion byte-for-byte; other API families have independent
components in the source review. Before claiming retained detection, temporarily send a
fresh key for each helper call and require the existing one-agenda count to fail after
actual duplicate creation. Restore exact helper code, then run the renamed case and
relevant API neighbors. This clarity change shares this small harness PR with #137;
its evidence remains distinct. No universal retry or new application fix is claimed.

The first name-retention fault used new keys on every retry. It fails the preserved
second201 assertion because Meeting uniqueness rejects a second agenda with422:
1/2/1 failure, seed32898,2.10s. That is useful retry/refusal detection, but does not
reach the planned duplicate-count detector. Narrow the same helper experiment to
append-update actions only. Expected retained detector: two real officer updates
instead of the asserted one. All other action keys/body and product code remain intact.

The narrowed append-update fault reaches the retained count detector after real requests:
1/9/1 failure, seed58226,1.21s, expected one saved update but actual two. Restore the
helper exactly; only the honest test declaration differs from original source. No
experimental fresh keys/order/forced failures or product edit remains. Clean calendar
neighbors pass18/404, seed recorded in the run log,36.51s, no failures/errors/skips.

Restored original calendar cases/neighbors pass18/404, seed60673,36.51s. Restored
renamed officer and agenda/calendar/editorial API neighbors pass82/739, seed7508,9.26s.
Both runs have zero failures/errors/skips. Focused RuboCop2 clean and diff checks pass.
Original calendar SHA2566251ef9bc08525749ece6ba3037a627034d5c8fb20bd983e5b398e7f5827248f;
intended restored SHA2564d879e184e05cd4103b18c15e0a0c5f960b6b66b4caa851282967ea8940d0636.
Officer intended restored SHA25680f3e44f781d56eff41835d41a530da86bfa427a76e8dc55751738b509463a2c;
normalizing only its test declaration matches original full file exactly.
Final committed full suites and exact-candidate/main CI remain pending after latest-main
integration. Neither controlled original failure is a production incident claim.
