# Website publication component assertion review

Bounded #84 source review at b965cf76, October 11, 2026. Governing PUBLIC_PUBLISHING.md
requires current explicit publisher authority, exact human-reviewed introduction consent,
approved snapshots unchanged by draft edits, sticky cancellation/restrictions and withdrawn
tombstones. Website consumers authenticate before conditional reads; cache errors never
serve stale content. Automatic calendar activation supersedes legacy event editorial
mutations; these tests intentionally retain inactive legacy-mode contracts alongside one
real automatic-policy serialization case. Do not confuse that coverage with every active
calendar-policy variant, current live publication or a real person's consent.

Read all five files /26 cases and shared WebsitePublishingSupport fixtures/helpers.
Exact names/lines/blobs pinned in [PUBLICATION_COMPONENT_SOURCE_CASES.md](PUBLICATION_COMPONENT_SOURCE_CASES.md).
Recorded b965cf76 actual-main all-four CI38122975568 passes ordinary1297/11980 then
system74/1598, no failures/errors/skips. Source reading is separate from execution and
representative faults; no app/test edit or new run belongs to this source-only slice.

| Exact file / cases | Starting state, action, saved/visible/subsequent outcome and limits |
| --- | --- |
| `test/controllers/public_publishing_test.rb` /7 | Actual Post-owned website bearer; exact authenticated empty collection/cache/Date/Age/HEAD and304, portrait/feature rotation/replacement/withdrawal/consent revocation with later feed/detail reads. Nonempty private Endeavor stays absent; reviewed schedule moves require republish while cancellation is immediate and private restriction removes conditional detail. Fixed interval boundaries include point/unknown/all-day/DST/stable ordering, invalid bounds/method/identity/outage no-store and240/241 throttle. Environment outage resets in ensure; helpers use fictional story/color-field portraits. Conditional auth revocation and every saved metadata row are not all asserted here; meaningful website-token tests remain independent. |
| `test/controllers/website_publishing_admin_test.rb` /4 | Technical settings grant cannot publish; publisher sees draft/current view, stale review conflicts, revoked grant cannot withdraw saved published story. Actual introduction publication/feature/withdraw-and-revoke persists status/selection/consent; both HTML and real bearer calendar restrictions produce cancellation/withdrawal and actor audit, deletion nulls source tombstone; calendar bearer cannot approve eligibility. Some failures assert redirect/status or published state only, not every row; direct test session/token fixtures do not prove recent-human issuance. |
| `test/models/website_publication_test.rb` /10 | Technical administrator differs from configured publisher capability; independent approved snapshot survives draft edit and exact consent renewal; stale publish cannot undo revocation/withdrawal and republish never refills homepage selection. Feature limit/rotation; sticky cancellation/pending source schedule changes; private/internal/category/delete tombstones/audit/permanent source identity; title flags and stored internal categories; actual portrait320x400/640x800 metadata stripping and invalid bytes; legacy public visibility never implicitly publishes. Some conflicts use exception-only detectors; one office starts Date.current and does not decide #93's near-midnight date context. |
| `test/models/website_publication_concurrency_test.rb` /4 | Real independent committed PG connections hold the first per-Post boundary and observe contender PID waiting on an ungranted lock before release. Both commit orders exercise automatic activation/hide, six legacy source edits/restrictions/delete, story withdrawal/consent/draft and actual HTML/bearer cancellation/private/internal/category/delete routes; exact conflict outcomes, cancelled/withdrawn/old snapshot or later not-found feed. Nontransactional synthetic cleanup and bounded thread ensure retained. Narrow harness exception capture returns errors for explicit assertions, not silent product success. No member/copy/paid/live-publish claim, and not every receipt/session/authority race is represented. |
| `test/system/website_publishing_test.rb` /1 | Actual magic-link publisher creates fictional introduction with generated color-field portrait, views two preview elements, gets consent-required error before entering exact synthetic consent, publishes at390px/no overflow, features through real form, then revokes/withdraws and reads no longer public with saved selectionnil. It does not itself read the consumer feed or compare every saved portrait/consent/history attribute or pixel dimension; those components remain. Real browser controls are distinct from model/HTTP tests. |

All tests and assertions remain. Signed conditional transport, snapshot/consent/metadata,
actual source callbacks, held-lock commit orders and real browser review each detect
separate failures. No safe consolidation/deletion or universal fault proof is established.
#81 credential authority and #60–#62 publication contracts remain coordinated without
inventing consent or changing automatic-calendar policy. No production or paid AI work.
