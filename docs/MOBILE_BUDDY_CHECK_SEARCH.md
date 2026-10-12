# Native Buddy Check member search

October 12, 2026. Backend correction for
`GET /api/mobile/v1/buddy-checks/people`; see the current
[mobile API contract](MOBILE_BUDDY_CHECK_API_HANDOFF.md) and
[access design](MOBILE_BUDDY_CHECK_DESIGN.md).

## Intended behavior and implementation

Normalize leading, trailing and repeated whitespace before enforcing the existing
2–80 character query limit. Match case-insensitively: every query word must occur
literally within either `first_name` or `last_name`, in any order. This supports
partial and complete names across both fields, including names with multiple words.
SQL LIKE metacharacters (`%`, `_` and backslash) remain escaped literals.

Use ordinary matches whenever any exist in the permitted population, independently
of pagination. Only when none exist, allow **one edit in one query word for the
entire phrase**: one inserted, deleted or substituted letter, or one adjacent pair
of transposed letters. That query word must contain at least four letters and only
letters; compare it to a whole name word of at least four letters (splitting names
at punctuation as well as whitespace). All other query words must still match
literally as substrings. Short words, punctuation, multiple misspellings, phonetic
similarity and misspelled partial words have no fuzzy expansion. This is a bounded
spelling aid, not identification or permission to contact someone.

A small Ruby service filters names from the existing `BuddyChecks::Access#people`
scope. The fallback reads only IDs and names in server-side batches, returning an
access-scoped relation to the existing ID-cursor paginator. It adds no database
extension, dependency, schema, client roster download or response field. Ordinary
search runs in SQL; fallback scans the permitted names on each request and may cost
more for a large Post. It does not promise snapshot stability if names or access
change between pages.

Preserve current directory/own active Buddy Check assignment access and immediate
removed/deceased/account denial. Each request reevaluates access. Responses remain
`{items: [{id, first_name, last_name}], next_cursor}` with 1–50 items (default 25),
ascending IDs, `no-store`, and no contact details or membership facts. Search creates
no contact, assignment, follow-up, receipt or roster change. The existing native
search UI needs no visual changes.

## Synthetic verification plan

Use a separate integration test file and synthetic names only. Establish that the
original controller fails the full/partial phrase and whitespace regressions before
implementing. Cover each allowed typo and its limits, ordinary-match priority even
after the final cursor, exact and typo pagination, literal wildcard/regex input,
short names, no results and invalid queries/pagination. With the same mobile token,
check directory loss/restoration, own versus other/renewal assignments, closure,
revocation and expiry, removed/deceased recipients, and lost account authority.
Assert identity-only responses, unchanged persisted records and subsequent reads.
Run the focused tests, related existing mobile/access tests, focused RuboCop,
Zeitwerk loading and diff/reference checks using the test database only.

The initial implementation authorization excluded release operations. Andre then
explicitly authorized committing, pushing and deploying only this search correction
on October 12. Production member lookup/copy, outreach, official-record actions and
paid AI calls remain outside scope. Local evidence does not establish the currently
deployed revision or native-device acceptance.

## Executed verification

Local patch on `master` at baseline `0e8fbd294cae75b62f5c503106efe5b55ecee9b7`.
Rails test environment and actual PostgreSQL database `legion_post_tools_test` were
confirmed; requests used wholly synthetic names and mobile bearer credentials.

- Original-controller regression run:
  `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/controllers/api/mobile/buddy_check_people_search_test.rb -n '/partial_and_complete|leading_trailing/'`
  — **2 tests, 12 assertions, 2 expected failures, 0 errors**, seed 42274.
  Both detectors expected an identity and received an empty list. The runner warns
  that `-n` is deprecated in favor of `-i`, but executed both selected tests.
- Final related run:
  `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/controllers/api/mobile test/controllers/mobile_authentication_test.rb test/services/buddy_checks test/models/person_test.rb`
  — **78 tests, 914 assertions, 0 failures, 0 errors, 0 skips**, seed 49102.
  Includes all 18 new search tests, existing mobile authentication, operations,
  evidence, suggestions, and Person coverage. Assertions check both search paths,
  exact response projection, stable cursors, subsequent authority changes, read-only
  persisted state, and a later preparation-card request.
- `bin/rubocop --cache false app/services/buddy_checks/people_search.rb app/controllers/api/mobile/v1/buddy_checks_controller.rb test/controllers/api/mobile/buddy_check_people_search_test.rb`
  — **3 files inspected, no offenses**.
- `RAILS_ENV=test bin/rails zeitwerk:check` — **passed**.
- `GEM_SPEC_CACHE=/tmp/buddy-search-gem-specs bin/brakeman --no-pager` —
  **0 errors, 0 security warnings**.
- Diff whitespace and both local document references passed. SHA-256 comparison
  confirmed all eight pre-existing changed/untracked files remained byte-for-byte
  unchanged. Only the controller, new search service, new search test file and this
  document belong to this correction.

At the end of initial implementation, full application/system suites and native-device
or production checks had not run, and the patch was uncommitted, unpushed and not
deployed. No dependency or schema changed. The subsequently authorized release uses
a temporary clean checkout to preserve unrelated edits; its test and deployment
results are reported separately from this initial implementation evidence.
