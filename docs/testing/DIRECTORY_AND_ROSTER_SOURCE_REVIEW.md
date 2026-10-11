# Directory, account display and roster source review

Bounded #84 review began at `8a603bb7b1a3105296bee14b66cf607cdcae015a`; integrated
source now15ce51b, October11,2026. Source evidence below is historical where explicitly
noted; independently verified completed slices have separate linked designs.
Expected behavior comes from `docs/ROLES.md`, `docs/STANDARD_MEMBER_EXPERIENCE.md`,
`docs/USER_MANAGEMENT_GUIDE.md` and `docs/LOOPS_ROSTER_SYNC.md`. Those documents govern
member phonebook access, separate membership/login authority, National roster provenance,
roster-controlled sign-in, deliberate manual disables and the external-sync opt-out boundary.

This records whole-file source/assertion review, not a new test execution, provider
confirmation or production inspection. Existing ordinary/system CI executes these files;
exact run results remain in the overnight ledger. Retain every case/assertion. No
redundancy or safe deletion has been demonstrated, so no consolidation is proposed.
The direct integration sign-in helper creates a session; real-browser sign-in evidence
belongs to the separate system paths. #93 still owns the unresolved Post-date choice.

## Member and account variants

| Exact file | Distinct retained assertions, real action and limitation |
| --- | --- |
| `test/controllers/people_controller_test.rb` (11) | Actual directory GET, own/admin/member columns, private search/sort/filter restrictions, distinct members/officers and roster/local filtering. Rendered visibility protects more than status. Technical manage_settings fixtures are not proof of configured Commander duties; #78 has that matrix. |
| `test/controllers/people_show_test.rb` (12) | `member sees contact, service, and roles but no record or controls`, local-contact preference, current/past membership duty, private-login exclusion, literal versus implied checkboxes and manual/automatic duty panels. Show content differs from index/bulk JSON and must stay. Request helper is not sign-in proof. |
| `test/controllers/api/people_api_test.rb` (10) | Real bulk/details/summary requests, private-value absence/no-store, current assignment versus past role, renewal year/PUFL/paid-ahead definitions, pagination/filter and removed/expired identities. Separate JSON projections cannot be replaced by HTML selector assertions. |
| `test/models/person_test.rb` (16) | Name/service normalization, directory contact preference, National sentinels, local/removed/expired/deceased visibility and roster identity/components. Independent fixed values protect representations before UI rendering. Date-dependent role labels remain #93. |
| `test/controllers/profiles_controller_test.rb` (6) | Own identity/directory link/agent access/passkey entry and foreign credential exclusion with real authenticated GET. Current-user scoping differs from directory records and administrator screens. |
| `test/helpers/navigation_helper_test.rb` (7) | Exact destinations, active classes/ARIA/current section and officer/admin visibility. Component contracts remain beside real menu interaction; classes alone do not prove cookies/sign-out. |
| `test/controllers/roster_email_reviews_controller_test.rb` (5) | Valid decisions preserve/change login address and prompting; invalid alert and unauthenticated redirect remain. Saved refusal graph and explicit review metadata are under linked #108 before test edits. Current else branch is safe source, not a demonstrated defect. |
| `test/models/user_test.rb` (30) | Person uniqueness; mismatch/keep/remind components; actual saved manual/roster access states/reasons; last enabled administrator; current/future/inclusive/ended/inactive assignments; explicit manual independence and no implied official acts. These lower-level invariants stay beside routed #78 tests. Predicate-only email expectations are complemented by #108. |
| `test/system/dashboard_activities_test.rb` (1) | Real sign-in, desktop/phone meeting-first DOM geometry, three eligible activities, keyboard focus and actual event destination. It creates agendas directly for display setup, not an officer approval ceremony; event selection has separate service tests. |

## Shared display components

| Exact file | Retained evidence and boundary |
| --- | --- |
| `test/helpers/legion_format_helper_test.rb` (11) | Fixed Legion date/time/parts; nil/invalid input, strict bounds, shorthand/AM-PM and summer/winter installation offsets. Explicit expected dates/times are independent; controller/browser date entry remains separate. |
| `test/helpers/status_display_helper_test.rb` (10) | Independent membership and agenda labels/classes/dots, blank/muted/case handling and escaped script text. Similar labels guard different state vocabularies. No proof of an entire rendered record or accessibility tree. |
| `test/views/member_row_test.rb` (2) | Actual rendered officer edge/name/role/status versus ordinary no-role/no-membership row. Source accepts optional action/subline slots; current tests do not establish every slot or responsive geometry. |
| `test/views/date_field_test.rb` (2) | Rendered submitted name/formatted or empty value, controller wrapper/native date picker/button. It does not execute calendar JavaScript; keep beside real date controls elsewhere. |
| `test/views/section_header_test.rb` (1) | Label/rule HTML contract; optional meta/action slots are not independently asserted. Keep the small component contract; no whole-screen claim. |
| `test/views/section_panel_test.rb` (2) | Real yielded body, label and provenance present/absent. A fragment helper parses actual output; no mocked renderer. |
| `test/views/stat_tile_test.rb` (1) | Independent fixed count/label/variant on rendered HTML. Data calculation belongs to service/controller tests, not this component. |

## Roster and offline email audience variants

| Exact file | Distinct retained evidence and boundary |
| --- | --- |
| `test/services/roster_imports/csv_parser_test.rb` (7) | Literal fixture fields/member ID, UTF-8 and binary BOM separately, missing/duplicate IDs with preserved valid rows, fatal headers and malformed CSV. Hardcoded fixture expectations complement generated CSV scenarios whose headers come from the application. |
| `test/services/roster_imports/importer_test.rb` | Real person/account/import writes and second import; complete identities beyond ten, deceased reversal versus deliberate disable, contact-value exclusion from summary, unchanged login address, roster enable/disable/unsupported/removal/return, last admin and unique/shared/missing/invalid email cases. Large-removal preview preserves people/accounts and attachment; confirmed stored import applies. Save-error seam is restored in ensure and asserts transaction rollback. Similar model cases cannot replace service transaction/source behavior. |
| `test/models/roster_import_test.rb` (7) | Independent latest-successful/history/staleness selection, safe old/empty summary projections, truthful deceased warnings and actual pending-CSV attachment requirement. Boundary exactly thirty days is not separately frozen here; retain existing cases rather than alter policy. |
| `test/system/roster_import_results_test.rb` (original 1; current 2) | Real sign-in and actual result page/warnings/names/record links/layout at 1400/390px after a direct synthetic service import. Does not exercise browser upload or large-removal confirmation. Request/service variants remain necessary. |
| `test/services/loops/roster_audience_test.rb` (3) | Real member selection/normalized and skipped emails; explicit stable member identity and omitted subscribed/userGroup/mailingLists fields. Protects opt-out-preserving payload shape, not live provider behavior. |
| `test/services/loops/client_test.rb` (3) | Offline fake HTTP receives actual PUT/authentication/body, Retry-After delay/retry count and explicit provider error status/message. Distinct from audience shape; live TLS/provider semantics are not inferred. |
| `test/services/loops/roster_synchronizer_test.rb` (original 5; current 6) | Offline fake records payload, real completed/partial/terminal/configuration and superseded-source states. Missing provider-call assertion on superseded refusal and the single-contact continuation name are linked #109 gaps, not established application bugs. Current start! returns before client use. |
| `test/controllers/admin/loops_roster_syncs_controller_test.rb` (7) | Actual settings denial/preview/stale warning, saved source/requester/count plus enqueue, missing configuration, existing-active no-enqueue and rendered partial failure. Restores synthetic ENV in ensure. Additional zero-audience/no-import create boundaries are not separately asserted here. |

Keep limited evidence explicit. No test edits, injected faults, provider network calls,
real member data, deployment or production mutation belong to this documentation slice.
The full roster controller was subsequently read: current pending-row locking, required
checkbox/attached source, completed/failed/missing-attachment/superseded/repeated refusal,
future-versus-past language, truthful historical names, private ordinary-member denial and
pending discard with no person removal all remain distinct. Serial request status checks
alone do not prove a concurrent supersession race; preserve that limit. Blank/malformed
file parameters differ from actual empty-file input (#111). Its runtime candidate was
disproved; PR#114 merged the meaningful empty-attachment refusal/recovery proofs without
application changes, including real upload/browser navigation. See EMPTY_ROSTER_INPUT.md. Job/model source shows the email job delegates to the service and the
one-active-run constraint is database-owned; no dedicated job/model test file is located.
Their execution boundary is currently controller enqueue plus explicit service execution,
not a real Solid Queue dispatch. #109 owns the bounded offline call/continuation gaps. #84 stays open.


The permission replacement source led to #112: original real overlapping requests
reproduced zero enabled administrators; PR#116 repaired the shared lock boundary and
passes candidate/main CI. See LAST_ADMINISTRATOR_CONCURRENCY.md. #108/#109 completed in PR#122 after actual-main15ce51b CI38118516754 passed
all four jobs. Their finally-restored saved-state/provider-call faults and separate real
browser results are in ROSTER_EMAIL_IDENTITY_REVIEW.md/OFFLINE_ROSTER_SYNC_REVIEW.md. Local source labels are separately #115. This source review completes
neither those ongoing contracts nor #84.


`test/services/membership_report_test.rb` (4) was completely reviewed with its service:
fixed disjoint removed/deceased/lapsed/unknown/PUFL/paid-ahead/paid/due states, actual
summary totals, latest completed source versus failed/older sources, explicit staleness
and year validation. Retain every assertion; paid-ahead is intentionally not a claim of
multiyear membership. Existing source-date comparison is not the exact frozen30-day
boundary, and generated unique member IDs are fixture identity rather than expected
renewal values. No deletion/consolidation or application change is justified.


Current-source evidence: every listed unchanged test file is executed by actual-main
CI38118516754 (ordinary1290/11644 then system71/1365, no failures/errors/skips).
This is unchanged-suite execution, not a newly injected fault for each listed assertion.
PR#114 adds the second actual empty-upload/recovery browser case; PR#122 keeps every
single-rejection assertion and adds the real two-contact case. Historical whole-file
review is complemented by those separately reviewed exact diffs. Local provenance#115
and date choice#93 remain open. The whole thirty-one current Admin::RosterImports request
cases were also reviewed: preview/confirmation/source/authorization remain distinct.

Exact case names and pinned source lines for these reviewed files are indexed in
[SOURCE_REVIEW_CASES.md](SOURCE_REVIEW_CASES.md). The index is source navigation, not a
coverage or failure-detection measurement. It includes existing distinct component
contracts; no test deletion or consolidation is established.
