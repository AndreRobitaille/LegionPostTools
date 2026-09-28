# Public website publishing

## Automatic calendar listings (September 28, 2026)

The event workflow below is legacy behavior until automatic listings are activated.
See [Automatic website calendar](AUTOMATIC_WEBSITE_CALENDAR.md) for the current design.
In Public website > Calendar defaults, a publisher chooses explicit event types,
reviews the actual notices, and activates the policy. CalendarEvents and formal
Meetings then supply live notices with Type default / Show / Hide exceptions.
Attendance is separate from website visibility. Calendar and meeting managers edit
their respective notices during ordinary saves; no event eligibility or Publish step
is required. Introductions retain their consent and publication workflow.

Migration leaves the policy inactive and never infers website types from titles.
Suggested defaults are member_meeting and public_event; unclassified existing events
need an explicit type or Show exception. Legacy publications and audit remain, but
event editorial mutations are disabled after activation. Only dedicated website copy
and schedule/place/attendance/cancellation fields reach the authenticated feed.

Design and implementation, September 27, 2026. Baseline: the companion's revision 3
`public-publishing-api-v1.md` and `publisher-api-request.md`. The subsequent release
authorization covers deployment and migration; live grants and publication remain
separate decisions.

## Product and visual direction

The members application remains the private meeting and officer workspace. A
capability-gated **Public website** workspace in Officer tools owns introductions,
portrait review, approved event copy, and homepage selection. The separate public
website consumes approved snapshots using a Post-owned website token; there is no shared login or database.

Use The 1919 working-screen system: navy actions, ivory panels, warm rules, gold
only for Publish, red for withdrawal. Sans-serif working text, 16px inputs/body,
14px secondary text, existing 900/560px breakpoints. The defining review surface
pairs **Working draft** with **Currently published**, stacking on narrow screens.
This makes pending dates and locations visible without implying Save publishes.
Portraits use an explicit center crop with both output previews before Publish.
No real member or generated likeness is supplied as default content.

## Implementation decisions

- Dedicated publication records retain opaque IDs, working drafts, approved
  snapshots and append-only audit events. Event source IDs never change; deleted
  sources leave withdrawn tombstones. Introductions need no Person relationship.
- `publish_public_content` is an explicit user/office capability, never implied by
  technical administration. Neither the migration nor first-time installation setup
  grants it to anyone.
- Publication operations and CalendarEvent saves/deletions serialize using a
  transaction-scoped PostgreSQL advisory lock per organization. Publish checks
  current authority and reviewed publication/source versions inside that boundary.
  A publication's optimistic version covers draft, consent, and restrictions;
  a stale review fails without retry. Explicit withdrawal and consent revocation
  may use an older version of the same identity: an intervening publication must
  not prevent someone from removing it. Such actions always advance the version.
  Source restrictions execute in shared model callbacks, including private API writes. Feature selection uses the same lock.
- Calendar eligibility defaults to unreviewed; stored internal categories force
  persistent internal designation. Only publishers approve eligibility, with a
  reason and explicit disposition of title flags. Approval and Publish are separate.
  Public dates/location always come from the reviewed source. Cancellation is
  immediately sticky; ordinary source edits leave approved text/schedule unchanged.
- Small bounded portraits are decoded with libvips, oriented, center-cropped and
  re-encoded without metadata. Only the two WebP renditions are retained in private
  database storage. No original or Active Storage signed URL exists for these
  uploads. This deliberately avoids adding a second public storage access path.
- GET/HEAD routes require a Post-owned website bearer token, including portraits. No CORS.
  This supersedes the original anonymous contract; see [WEBSITE_CONNECTIONS.md](WEBSITE_CONNECTIONS.md).
  Configured `PUBLIC_PUBLISHER_ORIGIN` is used for image URLs (HTTPS in production),
  falling back to `https://` plus the existing `APP_HOST`.
  Fresh responses use representation digests, Date, Age: 0 and a 300-second total
  private cache lifetime and `Vary: Authorization`; every conditional read rechecks
  website authentication and current publication state. Shared caching is forbidden.
  Errors are no-store. No fallback cache or stale-on-error publication exists.
- The public event feed uses snapshot overlap rules, independent of the existing
  private calendar scope. Complete 1–93-day intervals include cancellations and
  past events; all-day source ends become exclusive local dates.

## Deliberate internal differences

The optional Person link is omitted: publication does not require roster access,
so stories cannot accidentally disclose roster fields. Portrait originals are
not retained; staff can upload a replacement to change the center crop. One
optimistic publication version covers the separately described draft, consent,
and restriction versions. It advances for every such change and provides the
same stale-review protection. Website-token authentication supersedes the original
anonymous transport; the payload shapes remain unchanged.

Verification and reproducible synthetic access are recorded in
`PUBLIC_PUBLISHING_HANDOFF.md` after implementation.

## Authenticated editorial API design (September 27, 2026)

Provide admin-workflow parity under `/api/website_publications`, using the existing
session/CSRF and bearer/Idempotency-Key contract. Every editorial read and write
requires current explicit `publish_public_content`; no grants are added. The
`/public/v1` consumer payloads remain unchanged. Website connections now require
a dedicated Post-owned token; see [WEBSITE_CONNECTIONS.md](WEBSITE_CONNECTIONS.md).

Controllers call the existing publication domain operations, including their
transaction boundary, consent fingerprint, event restrictions, and stale-review
checks. Requests use `lock_version` (mapped to the domain's `version`) and event
actions additionally use `source_lock_version`. Draft content stays nested under
`draft`, contains only authored text, and never accepts snapshots or identities.
Portrait writes use bounded strict base64 JSON so existing bearer request
fingerprinting and retry storage work without multipart-file identity ambiguity.
Only generated private renditions are readable; there is no remote URL fetch.

List/detail expose draft versus approved snapshot, consent coverage, source review
fields and versions, pending changes, portrait paths, and history paths. History is
separately paginated. Featured order has a dedicated read/write endpoint returning
the full story-version map required for atomic replacement. Withdrawals preserve
tombstones; no delete endpoint exists. Audit events retain the human actor and add
delegated token id/name when a bearer acts for that same human, never token secrets.

The generated permission-filtered JSON/Markdown `/api` handbook documents every
route, field, retry rule, and a guided workflow. Consent, eligibility, publication,
withdrawal/revocation, internal designation and homepage ordering belong under
Only when asked: agents record supplied human decisions, never invent consent or
infer publication authority from content. Static API documentation includes
sanitized examples and local synthetic access. Verify authorization, session CSRF,
bearer replay, stale decisions, source restrictions, portrait handling, pagination,
history, and handbook coverage using the test database.

The implemented request/response reference and sanitized operator examples are in
[WEBSITE_PUBLISHING_API.md](WEBSITE_PUBLISHING_API.md).
