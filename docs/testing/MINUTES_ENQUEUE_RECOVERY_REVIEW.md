# Durable rejected minutes enqueue recovery

Bounded #128/#84 design, source2b9bf51, October11,2026. Actual locked Active Job8.1.4
returns a job or false after enqueue callbacks/EnqueueError. Existing worker polling
already guards false; initial HTML draft creation, Jobs retry and API create/retry call
successfully_enqueued? directly. Reproduce the four actual synthetic request paths before
application edits with a narrowly installed real before_enqueue abort, restored in ensure.
No fake successful queue/provider and no paid processing.

The expected transition is prepared pending run -> failed queue_error with completion
time when enqueue rejects. Preserve original source/raw metadata and manual minutes/
revision payload/events/rows; retry also retains the complete prior attempt and links
only its new attempt. Read saved results before response/status expectations. HTML uses
the current truthful failure/manual workspace alert; JSON returns safe persisted failed
run and unprocessable status. Later fresh request after callback restoration enqueues
a distinct pending linked attempt without altering either failed attempt. Preserve all
existing successful request, active-retry, worker poll and source/provenance assertions.

If reproduced, guard the false result in the three existing request enqueue locations.
Keep existing failed-run helpers, messages, statuses, authority and queue policy. Do not
add exception suppression or broaden rescuing; actual adapter exceptions beyond its
existing Active Job contract remain failures. The original routed error plus stored
pending/error evidence demonstrates the regression. Later real browser rejection,
truthful failed page/manual escape and restored retry exercise the same real controls
and later reads. Visual direction retains1919 paper/navy panels and existing body16/
secondary14/labels13 at desktop1400/phone390, with no UI/copy redesign.

Final focused checks/diff review before commits; committed full ordinary then full
system serially, applicable lint/security, exact-candidate/main CI before normal merge.
No production, real member-data copy, dependency upgrade, paid AI or automatic minutes
application. Retention#79/date#93 and true external background acceptance remain open.


The first new graph helper incorrectly used a nonexistent minutes.outcomes association:
4/0/4 errors seed32109, setup-only evidence. Use actual outcomes scoped by saved item IDs.
Corrected real requests reproduce4/0/4 errors seed57679,1.27s at false.successfully_enqueued?.
A narrow temporary diagnostic rethrows that same NoMethodError after inspecting persisted
rows:4/0/4 seed7811,1.32s, all four new runs actually pending, nil category/completion,
zero suggestions, complete source/minutes graph and all earlier run attributes unchanged.
An initial diagnostic invocation without the explicit bundle/test environment fails to boot
before any DB work; only the corrected explicit test invocation is credited. Exact support
restoration SHA25601ade301782f864b821e656f5c547934887924549970294a13ab3c2466fa24ce.
No diagnostic rescue remains. Apply the same job && guard as the existing worker in
the three request enqueue locations; preserve existing failure helpers/messages/authority.


The first guarded focus39/418/2 failures seed50369 rejects assert_equal(nil, value)
under Minitest's enforced assertion contract; retain the same nil expectation with
assert_nil, and keep full retry identity assertions for nonnil originals. Corrected
request/job focus39/453 seed8253,3.82s passes; eight changed Ruby files lint clean.
Every old request/job assertion remains. Reused existing worker polling guard is unchanged.

Real browser2/72 seed53472,6.43s passes. Actual magic-link/request rejection/failed
page, manual escape with saved nonempty report, actual confirm-and-retry rejection/
unchanged earlier attempts, restored actual retry enqueue/queued view, permission-loss
status fetch/protected navigation denial and own Profile preserve the complete source/
minutes graph. No jobs/provider are performed. Four1400/390 failure/queued captures
inspected: error body16px, wrapping controls/no overflow and honest manual escape.
The queued view has existing11px status/support and13px body instructions; #130
records that separate readability repair before editing typography. No whole queued
font-floor or real Solid Queue/provider completion claim belongs to this guard repair.
Final main integration, committed serial full suites/security/exact/main CI pending.

## Whole existing delegated draft request source

Read all nine original ApiMinutesDraftApiTest cases and helpers at2b9bf51, retaining:
actual pending preparation/job enqueue/later safe GET; explicit Endeavor create decision
and extra agenda authority; stale/foreign existing-link refusal and human-confirmed link;
optional normalized source excerpt/no-store, simulated purged-state absence and grant loss;
actual bearer edited proposal preserves payload/narrative/reviewer/time and exact receipt
replay, then a separate dismissed proposal remains unapplied; narrative plus roster-backed
motion result application; one attendance entry/used state/counter; linked retry/discard/
restore without deletion; safe Jobs summary and source absence. Basic requests use the
allowed signed-in cookie channel; two evidence/review cases use an actual bearer. The
new enqueue refusals reuse that existing channel and independent authority proof stays
in #78/#81. A case named complete attendance has one entry; direct source-state mutation
is not actual scheduled deletion, and source privacy absence is not a whole publisher
projection proof. Keep each distinct assertion/component; no consolidation is established.

Exact original cases (reviewed source2b9bf51):

- [agent can request a durable background drafting run](https://github.com/AndreRobitaille/LegionPostTools/blob/2b9bf51cd032c6961ed0c7c4baae1e3e4b36d904/test/controllers/api/minutes_draft_api_test.rb#L22)
- [Endeavor proposal API requires explicit identity choice and creation authority](https://github.com/AndreRobitaille/LegionPostTools/blob/2b9bf51cd032c6961ed0c7c4baae1e3e4b36d904/test/controllers/api/minutes_draft_api_test.rb#L39)
- [Endeavor proposal API permits confirmed existing links but rejects stale or foreign identities](https://github.com/AndreRobitaille/LegionPostTools/blob/2b9bf51cd032c6961ed0c7c4baae1e3e4b36d904/test/controllers/api/minutes_draft_api_test.rb#L69)
- [AI proposal evidence is explicit normalized restricted and absent after purge](https://github.com/AndreRobitaille/LegionPostTools/blob/2b9bf51cd032c6961ed0c7c4baae1e3e4b36d904/test/controllers/api/minutes_draft_api_test.rb#L92)
- [bearer AI corrections and dismissal preserve original evidence and review provenance](https://github.com/AndreRobitaille/LegionPostTools/blob/2b9bf51cd032c6961ed0c7c4baae1e3e4b36d904/test/controllers/api/minutes_draft_api_test.rb#L120)
- [agent explicitly reviews narrative and roster-verified outcome suggestions](https://github.com/AndreRobitaille/LegionPostTools/blob/2b9bf51cd032c6961ed0c7c4baae1e3e4b36d904/test/controllers/api/minutes_draft_api_test.rb#L163)
- [agent reviews the complete suggested attendance sheet](https://github.com/AndreRobitaille/LegionPostTools/blob/2b9bf51cd032c6961ed0c7c4baae1e3e4b36d904/test/controllers/api/minutes_draft_api_test.rb#L217)
- [failed runs retry as linked attempts and discard or restore without deletion](https://github.com/AndreRobitaille/LegionPostTools/blob/2b9bf51cd032c6961ed0c7c4baae1e3e4b36d904/test/controllers/api/minutes_draft_api_test.rb#L245)
- [jobs API exposes safe queue and run summaries](https://github.com/AndreRobitaille/LegionPostTools/blob/2b9bf51cd032c6961ed0c7c4baae1e3e4b36d904/test/controllers/api/minutes_draft_api_test.rb#L268)
