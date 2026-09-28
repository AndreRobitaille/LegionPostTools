# Calendar and Endeavor activity API

## Automatic website calendar (September 28, 2026)

This section supersedes the older event-publication and derived-only public_event
rules below after activation. CalendarEvent and Meeting create/update accept explicit
`calendar_category: public_event` as well as other stored categories. Null can infer a
display category, but never website eligibility.

Both resources accept these top-level fields under existing write permissions:

- `website_listing`: `default`, `show`, or `hide` (default `default`).
- `attendance`: `members`, `public`, or `invited` (default `members`). Independent of listing.
- `website_title`: optional public title; blank uses the source title.
- `website_description`: optional public copy, never copied from internal descriptions.
- Meetings also accept `cancelled` as a JSON boolean and show cancellation notices.

Private responses include `website_calendar` with those four website/attendance
fields, `enabled`, `listed`, and `type_default`. Active CalendarEvents report
`website_publication.status` as `listed` or `hidden`, `automatic: true`, and the current
public projection when listed. The older publication state remains before activation.
After activation `website_designation` writes are rejected; use `website_listing: hide`.
Schedule/place/copy edits and cancellation immediately affect active notices.
Public responses keep existing v1 fields and add attendance; description includes
the attendance label for compatibility with existing consumers.

Publisher-only policy endpoints:

- `GET /api/website_calendar`: enabled, types, version and available_types.
- `POST /api/website_calendar/preview`, with `types: [...]`: all existing occurrences,
  proposed visibility and public fields, plus a signed `review_token` valid for 30 minutes.
  This is a private review; no writes or publication occur.
- `PATCH /api/website_calendar`, with `review_token`: activate or update the reviewed
  defaults on human instruction. Stale source/policy state or invalid/expired token
  returns 409; invalid types return 422. Activation is one-way to prevent restoring
  stale legacy snapshots. Empty types hides defaults, but Show overrides remain.

Session CSRF and bearer Idempotency-Key apply to both POST and PATCH. Existing records
are not automatically classified or exposed by migration. Audit captures notice/policy
changes, actor and delegated-agent identity. See [the design](AUTOMATIC_WEBSITE_CALENDAR.md).

Design and implementation contract, 6 September 2026. The existing calendar UI and
production seed were deployed at `f22eec3`; this follow-up release adds private API parity. No public website synchronization, caching, or unauthenticated feed is
introduced. Repository-only development does not require a production API sign-in.

## Boundaries

Reuse the existing session/bearer authentication, CSRF, idempotent bearer writes, and
current-user permissions. Members read events and tasks. Event mutations require the same
`User#can_manage_calendar?` policy as the UI (administrative settings access or the current
Commander/Adjutant position-derived authority). Task and Endeavor mutations require
`manage_agendas`. Handbook visibility must use these same predicates. All records and
optional Endeavor links are organization-scoped. CalendarEvents may be deleted explicitly with a lock version, or cancelled to retain
a notice. Tasks can be completed/reopened and have no delete route. None of these writes changes official records.

## Endpoints

- `GET /api/calendar?start_date=2026-09-01&view=events`: bounded month grid, including its
  leading/trailing week days, matching the UI. `view` is `events`, `deadlines`, or `public`.
  Default date is the current month; default view is events. Events and Meetings have
  distinct `type` values. Deadline entries identify their project/task rather than an
  attendance event. Public view contains only allowlisted public event fields and type.
- `GET /api/calendar_events`: paginated complete history, including cancelled/past events.
  Optional `endeavor_id` and `visibility=members|public`; optional `preview=public` returns
  only the public projection and excludes private rows. Public preview cannot be combined
  with `endeavor_id` or members visibility. Normal reads include Endeavor links and locks.
- `GET /api/calendar_events/:id`: event detail; `preview=public` hides private links,
  actor IDs, and lock metadata, and returns 404 for private events.
- `DELETE /api/calendar_events/:id`: permanently delete the named CalendarEvent with
  required last-read lock_version; returns 204. Calendar-management permission is required.
  Member/PEC/officer meeting entries return 422 and cannot be deleted here.
  Linked Endeavors and official records remain. Listed under Only when asked in `/api`.
- `POST /api/calendar_events`, `PATCH /api/calendar_events/:id`: title, description,
  location, optional `endeavor_id`, visibility (`members` default), `all_day`, `cancelled`,
  `starts_at`, optional `ends_at`. PATCH requires the last-read `lock_version`.
- `GET /api/endeavors/:endeavor_id/tasks`: paginated steps including completed ones;
  optional `status=open|completed`. `GET .../tasks/:id` reads one scoped step.
- `POST /api/endeavors/:endeavor_id/tasks`: title and optional `due_on`.
- `PATCH /api/endeavors/:endeavor_id/tasks/:id`: title, due_on, completed, lock_version.
  Completion/reopening preserves actor/time provenance; repeated completion preserves the
  first completion time. The parent lookup prevents cross-project task edits.
- `PATCH /api/endeavors/:id`: same editable project fields as create, plus required
  lock_version. Detail/create/update responses include lock_version and activity collection
  paths. Existing completion/reopening and append-only update endpoints remain unchanged.

Event/task lists and monthly entries accept `limit` (1–500, default 500) and `offset` (default 0).
Responses include pagination counts; follow pages before assuming a list is complete.
Endeavor detail points to task and filtered event collections rather than embedding an
unbounded history. Calendar Meeting projections expose schedule fields only, never draft
minutes, transcripts, agenda status, or internal records.

## Response shapes

- Monthly response: `calendar` contains date, view, timezone, and entries; sibling
  `pagination` describes the selected page. Entry type is event, meeting, or deadline.
- Event list: `calendar_events`, `pagination`, timezone. Detail/create/update:
  `calendar_event`, timezone.
- Task list: `tasks`, `pagination`. Detail/create/update: `task`.
- Project detail/create/update: `endeavor`, including tasks_path, calendar_events_path,
  lock_version, due_on, and the legacy raise_by_on alias. The existing detail history
  remains unchanged.
- Pagination contains count, returned_count, offset, limit, truncated. While truncated is
  true, request offset + returned_count. Counts refer to the filtered collection.

Example date-only event (session CSRF or bearer Idempotency-Key headers still required):

```json
{"title":"Community event","endeavor_id":1,"all_day":true,"starts_at":"2026-09-19","ends_at":null,"visibility":"members","description":"Time has not yet been confirmed."}
```

Event reads return ISO datetimes even for date-only entries; interpret them in the response
timezone. Date-only writes use YYYY-MM-DD. Internal event/task responses include creator,
last editor, timestamps, and locks; task responses also include completed, completed_at,
and completed_by_id. Public previews expose only the documented safe field allowlist.

## Values, errors, and safe operation

JSON fields are top-level, consistent with the private API. Dates are strict YYYY-MM-DD.
Timed events use ISO 8601 datetimes with an explicit offset or Z. Date-only events use
`all_day: true` and YYYY-MM-DD starts_at/ends_at; local midnight and inclusive end-of-day
storage match the UI. Member views omit time metadata for date-only events. Explain unknown times in the description.
Dates normalize in the Post's saved timezone, which responses identify. Do not
invent times, infer event dates from project deadlines, or publish private logistics.
When switching all_day mode, send both starts_at and ends_at (null is allowed for end).
Omitted PATCH fields remain unchanged; null clears optional dates/links. Booleans must be
JSON true/false. Completion/cancellation are reversible; deletion requires an explicit request for the named event.

`due_on` is preferred; `raise_by_on` remains the same stored date and backward-compatible
API alias. When both are supplied, due_on wins. Task dates never create calendar events;
only the member deadline view shows open dated tasks and active project deadlines.

Validation errors return 422, missing/out-of-scope records 404, permissions 403, stale
lock versions 409, and missing authentication 401. PATCH requires a nonnegative integer
lock_version. Fetch again after a conflict and reconsider the intended edit; do not blindly
replace the version. Session writes need the handbook's X-CSRF-Token. Bearer writes need
Idempotency-Key; exact retries reuse it, changed requests need a new key. Fetch `/api` in
full at each operational session start, and again after deployment or permission changes.

Verification covers both authentication modes, idempotence, live permission revocation,
member reads/write denial, public-data isolation, stale edits, organization/project scope,
invalid dates/booleans, pagination, completed history, and handbook filtering.

## Local validation

The completed extension passed the full Rails suite: 920 tests and 5,950 assertions,
zero failures/errors/skips. The sequential browser regression suite passed 24 tests and
169 assertions. Eight changed Ruby files passed focused RuboCop; Brakeman reported zero
warnings/errors, the dependency audit found no vulnerabilities, and `git diff --check`
passed. Tests used synthetic records in the test database, including DST boundaries,
member/office-derived access, both authentication modes, CSRF, and idempotent writes.
No production data changes, migration, or paid AI generation were needed for this API
extension. Release verification also checks the running revision and site health.

## Calendar readability refinements

Calendar month bounds now use Sunday–Saturday, including spillover days. Responses include
`week_starts_on: "sunday"` and selected `categories`. Optional `categories[]` accepts multiple
values: `officer_meeting`, `honor_guard`, `planning_meeting`, `member_meeting`, `public_event`, `other`, `deadline`.
Omitting the filter selects all; an empty array selects none. Unknown values return 422.
Deadlines still require `view=deadlines`; public preview never includes meetings/deadlines.

CalendarEvents and Meetings accept nullable `calendar_category` on their existing create
and update endpoints, under unchanged permissions and locking. Values are the above list
except `deadline` and `public_event`. Null/blank restores automatic classification by
name, then public visibility.
Event reads expose the stored override and effective `category`; public projection includes
only the effective category. Monthly Meeting entries include both fields plus `display_title`
without a trailing matching house-format date; original `title` remains unchanged.
New default meeting/agenda titles omit dates. Existing official headings are not rewritten.
The forgiving time entry is a website feature; API datetime writes still require their
existing format, including explicit offsets for timed CalendarEvents.

The redesigned attendance UI labels `other` as Other activities and filters immediately
in the browser, with selections retained in the URL. The API still filters its response
server-side. The former website Show dropdown is replaced by secondary officer links to
planning/public previews; existing API `view` values and permissions remain supported.

Public events are classified from public visibility after specific meeting/Honor Guard types.
`public_event` is a derived category, not an editable override. Legacy `volunteers`
overrides remain readable but use current title/visibility classification. Volunteering
is participation, not an event type; Honor Guard does not imply open recruitment.

Event deletion design and verification: `CALENDAR_EVENT_DELETION.md`.

## Separate website publication (local implementation, September 27, 2026)

`/public/v1` requires a Post-owned website token and serves explicitly reviewed
website snapshots, independently of the
existing private API and its public preview. Public calendar visibility never
publishes an event by itself. See [Public publishing](PUBLIC_PUBLISHING.md).

Normal private event payloads now add `website_designation` and
`website_publication`: publication status, `pending_calendar_changes`, the last
approved `published_event` (or null), the signed-in `review_path`, and the required
`publish_public_content` permission. Public-preview payloads remain unchanged.
A missing publication reports `status: unpublished` and the publishing permission.

Calendar create/update accepts `website_designation: internal` only. An internal
category or designation, private visibility, or authorized deletion immediately
withdraws any website publication in the same transaction, through either HTML
or API. Cancellation immediately marks the existing approved snapshot cancelled.
Clearing cancellation restores only the private calendar: public reinstatement
requires publishing again. Normal title, description, date and location changes
remain pending; they do not silently replace approved public content.

Eligibility approval and publication are separate actions in Public website under
Officer tools, requiring an explicit publishing grant. Calendar-management access
alone cannot publish or approve eligibility.
