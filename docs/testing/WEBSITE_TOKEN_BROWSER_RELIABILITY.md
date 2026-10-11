# Website-token native navigation and browser review

Bounded #105 under #84, source `b852211`, October 10, 2026. Two distinct candidate
CI runs fail the unchanged website-token browser journey with Chrome154.0.8037.97
inspector error `Node with given id does not belong to the document`: CI38107402806
and CI38110781740. The earlier rerun passed; recurrence needs explicit review rather
than indefinite reruns or broad exception suppression. Main CI38110689517 passed.

The second failure is during Selenium element-text query on the expected 201 token-
creation page. Its failure screenshot shows that page, the copy control and synthetic
token, before screenshot masking. This locates the failure before the later list/back/
revocation proof; it does not establish a failed application mutation. Candidate #103
changed retry prose/tests only. The local Chromium152 full system suite passes.
The official Chrome-for-Testing manifest does not contain the exact CI154 version;
do not substitute an unverified download or upgrade locked dependencies.

The creation form deliberately disables Turbo to protect one-time native token delivery.
Its POST changes the browser URL from `/admin/website_access_tokens/new` to
`/admin/website_access_tokens`. Proposed smallest synchronization is an explicit current-
path assertion after the real submit and before DOM queries. This asserts the meaningful
native navigation outcome and waits without retaining an old element reference. It is
an inference about a document-transition race, not proof of a Chrome defect. Preserve
every existing heading, visible button, token shape, one-time back exclusion, revocation
authentication and desktop/narrow overflow assertion. No sleeps, retries, driver rescue,
direct-HTTP substitution or application/permission change.

Rename the journey honestly: it currently proves a visible copy control, not actual
clipboard contents. Actual clipboard success/fallback remains a separate coverage gap;
the old control assertion stays. Run the unchanged neighboring personal/website token
request tests, the actual browser journey with captured desktop/narrow pages, and final
committed full ordinary/system suites serially, lint/security and exact-SHA CI. A passing
run bounds the repaired interaction but does not prove absence of every driver race.
Keep the retry-guidance PR draft until a verified base and all its own required checks
pass. Verify actual main after any merge. Synthetic records only; no production/paid AI.


Focused unchanged token request/model neighbors: 20 / 181 / 0 (3.54s).
Website/personal browser journeys with the new path assertion: 2 / 37 / 0 (6.78s).
Created/list screenshots inspected at 1400/390px: readable wrapping, usable controls,
no horizontal overflow; narrow content below the fold remains scrollable. All old
creation/reveal/back/revocation and overflow assertions remain. A controlled redirect
back to the new form after issuance fails the added path assertion before later DOM
queries: 1 / 8 / one failure (4.84s). Exact controller SHA-256 restored:
`f2b4689aebf49b88b8d55b42323912e5861943dc14407eb66481a80c255dfcdc`.
No experimental application change remains. Changed test lint clean. Restored clean
browser/full-candidate and exact CI verification still required. The native-path fault
proves the added outcome assertion detects incorrect navigation; it does not reproduce
or establish the exact Chrome154 inspector cause.

Restored real browser pair: 2 / 37 / 0 (6.21s). Exact controller bytes remain unchanged.
