# Finite bearer receipts and current authority

Design for #99 under #84/#81/#92, October 10, 2026. Current source `08a7094`
marks AgentApiExecution receipts older than 30 days eligible for recurring cleanup.
This is not an infinite deduplication contract. Current replay also checks current
authority and may filter restricted Meeting summaries in the returned copy.

The handbook's writes/retry prose omits that window and describes an original response
without the visibility qualification. Proposed change is truthful operating guidance,
not a longer retention window or permanent mutation tombstones.

Before editing guidance, strengthen the existing exact-retry request test. Keep all its
same-day no-duplicate/receipt assertions. Use a 90-day synthetic token to isolate receipt
expiry from credential expiry, controlled time, real cleanup at/beyond the strict cutoff,
and actual identical requests. Check retained business/receipt rows and subsequent action
identities. Do not claim duplicate mutation until reproduced. Existing changed-input,
processing, current-authority and concurrent-first-use variants remain.

Then state the actual 30-day receipt window in both live handbook formats and standing
instructions. After the window, delegates must read saved current state and resolve the
uncertain outcome with the human before repeating an old mutation. Preserve unique-key,
changed-input conflict and stale-lock advice; describe current visibility accurately.
The visual direction retains the existing plain JSON/Markdown handbook and standing brief;
no new controls or page layout are introduced. The personalized Agent access UI is unchanged.

Strengthen the existing handbook bearer guidance test with independent expected duration,
current-authority/visibility and old-outcome instructions in both formats. Original guidance
must fail that contract; restore any temporary source fault exactly, then prove clean
behavior. Keep runtime window tests distinct from text contracts and current-authority
tests. Final committed serial suites, lint/security and exact-SHA/actual-main CI are
required before merge. Only synthetic test records and local source; no production/paid AI.

## Original and corrected evidence

On unchanged guidance, the new handbook expectation fails on absent duration while the
real cleanup/retry scenario passes: 2 / 40 / one failure (2.42s). The actual old key
creates a second distinct Endeavor and a new receipt after real cleanup; token remains
active and the original business row survives unchanged. This is an existing finite
receipt contract plus missing operating guidance, not a claimed infinite-idempotency bug.

Add the explicit retained-after-30-days/until-cleanup positive case, preserving the
original same-day assertions and exact-boundary cleanup behavior. Revised guidance and
runtime contracts pass 2 / 58 / 0 (seed 30718, 3.35s). Current-authority filtering remains
the separately verified #92 behavior. One shared prose entry supplies both live formats;
standing text also points older uncertain outcomes to saved state and the human. No
retention, mutation, permission or personalized Agent access UI behavior changes.


Expanded unchanged authority/retry/concurrency/inventory set: 51 / 852 / 0
(seed 32818, 7.76s); integrated actual main `b852211`: 51 / 852 / 0
(seed 38320, 7.71s). Three changed Ruby files lint clean; no experimental runtime
fault remains. Whole-file execution is not whole-file assertion review. Final committed
serial suites/security/exact-SHA and actual-main CI remain required.
