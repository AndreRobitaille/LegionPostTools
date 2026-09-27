# Publisher handoff to the public-site consumer

September 27, 2026. Implemented and verified locally in LegionPostTools on top of
`9d278b7ce449ea54d60b151b32f6e23cac97eacf`, then prepared for the authorized release.
The release migrates the schema without granting publishing access or publishing
content. Development/member data was not seeded with demonstration records.
Tests use the test database; the runnable demonstration uses a separate synthetic
database. Confirm the actual deployed revision through the release verification.

## Interface and operation

No public JSON, route, identity, interval, or freshness differences from revision 3
are proposed. These anonymous routes accept GET and HEAD:

| Route | Output |
| --- | --- |
| `/public/v1/featured_members` | Complete ordered selection of zero to three full introductions |
| `/public/v1/member_stories/:id` | Published introduction, independently of homepage placement |
| `/public/v1/events?from=YYYY-MM-DD&to=YYYY-MM-DD` | Complete 1–93-day interval, inclusive start/exclusive end |
| `/public/v1/events/:id` | Published event, including past/cancelled events |
| `/public/v1/member_stories/:id/portrait/:revision/:size.webp` | Current approved `small` 320×400 or `large` 640×800 WebP bytes |

The deployment's existing `APP_HOST` yields the intended publisher origin
`https://members.wipost165.org` after this release.
`PUBLIC_PUBLISHER_ORIGIN` can explicitly override the origin. No request Host value
is copied into portrait URLs. Production requires HTTPS, with no trailing slash.
No consumer credentials, shared database, browser JSON requests, or CORS are needed.

Success uses `application/json` (images use `image/webp`), representation ETags,
Date, Age: 0 and `max-age=300, public, must-revalidate`. Cache directive ordering is
semantically equivalent to the requested ordering. Every conditional request checks
current publication state before returning 304. Errors are no-store: 400, 404,
405 with Allow, 429 with Retry-After: 60, and 503 with Retry-After: 60. The initial
throttle is 240 requests/minute per client IP across these routes, backed by the
configured Rails cache. There is no silent truncation or stale-on-error fallback.

The members app remains private. Its new **Public website** workspace is under
Admin/Officer tools at `/admin/website_publications`, gated by an explicit user or
office-derived `publish_public_content` grant. Technical administration does not
imply publishing; the migration and first-time setup grant nobody this capability. The workspace
handles drafts, crop previews, exact-draft consent, eligibility, explicit Publish,
withdrawal, and homepage order. The same operations are available to authorized
operators through the [authenticated editorial API](WEBSITE_PUBLISHING_API.md),
documented in the caller's permission-filtered `GET /api` handbook. Public-site
consumers continue to use only the anonymous routes above.
Create a new introduction for a different person;
do not reuse an existing public identity for another subject. Calendar editors and private API readers see the
last approved event and pending changes. Source restrictions/cancellation work
through either HTML or bearer API and take effect in the source transaction.

Internal implementation choices worth carrying back to the companion:

- Introductions omit the optional private Person link. They cannot inherit roster fields.
- Only the two private WebP renditions are retained; original uploads are discarded.
  Cropping is centered, with both sizes previewed before publication. A differently
  framed crop requires a replacement upload.
- One optimistic publication version covers draft, consent, and restriction changes;
  event publication additionally requires the exact reviewed source lock version.
- Withdrawal/consent revocation may use an older version of the same identity, so
  an intervening publication cannot prevent removal. They still advance the version;
  an earlier Publish cannot resurrect the content.

These choices preserve the external behavior. Full implementation rationale is in
[PUBLIC_PUBLISHING.md](PUBLIC_PUBLISHING.md).

## Reproducible synthetic access

From this repository, with its installed Ruby/gems, PostgreSQL and libvips:

```sh
bin/publisher-demo prepare
bin/publisher-demo serve
```

This explicitly selects `RAILS_ENV=test` and the dedicated database
`legion_post_tools_publisher_demo_test`. It does not reset or use development data.
First preparation creates one fictional introduction with a blue test card and two
synthetic October 2026 events. Later preparation preserves existing demonstration
records. The server binds `0.0.0.0:3105`; local API origin is `http://localhost:3105`.
The dates are fixed so boundary checks remain reproducible even after October.

```sh
curl -i http://localhost:3105/public/v1/featured_members
curl -i 'http://localhost:3105/public/v1/events?from=2026-10-01&to=2026-11-01'
bin/publisher-demo login
```

The final command prints a fresh, short-lived sign-in URL for the **synthetic**
editor. Follow the ordinary confirmation page, then open
`http://localhost:3105/admin/website_publications`. No credentials or sign-in tokens
are recorded in this handoff. Stop a foreground server with Ctrl-C.

For another machine on the local network, use an origin that machine can resolve:

```sh
PUBLIC_PUBLISHER_ORIGIN=http://YOUR_DEVELOPMENT_HOST:3105 bin/publisher-demo serve
```

Use the same origin when requesting `bin/publisher-demo login`. Port reachability
from another machine/firewall was not verified. This test environment is synthetic;
its HTTP setting is not a production configuration.

The current companion **Client intentionally rejects HTTP origins**. Two local
options are available: put a trusted HTTPS reverse proxy in front of this server,
or inject a test transport while keeping the logical publisher origin HTTPS. Do
not weaken production TLS validation. The following check implements the second
option without editing the public-site repository, rewriting response bodies, or
following redirects:

```sh
# In a separate terminal, advertising HTTPS while listening locally over HTTP:
PUBLISHER_DEMO_PORT=3106 PUBLIC_PUBLISHER_ORIGIN=https://localhost:3106 bin/publisher-demo serve

# From this repository; PUBLIC_SITE_REPO defaults to ../wipost165:
CHECK_PUBLISHER_ORIGIN=https://localhost:3106 \
CHECK_PUBLISHER_CONNECT_ORIGIN=http://localhost:3106 \
PUBLISHER_EXAMPLES_DIR=tmp/publisher-https-examples \
RAILS_ENV=test bin/rails runner script/check_public_publisher.rb
```

This checks the **actual companion Contract, Client and Transport** against live
publisher bytes, with a narrowly injected connection-origin adapter. It is not a
TLS or public-browser integration test: browsers following the HTTPS portrait URLs
would still need a real HTTPS proxy. For directly fetchable browser portraits, use
the normal HTTP demo on port 3105 or a trusted HTTPS test origin.

## Sanitized examples and headers

[examples/public-publishing](examples/public-publishing/) contains captured output
from the running HTTP demonstration:

- [featured.json](examples/public-publishing/featured.json) and
  [story_0.json](examples/public-publishing/story_0.json).
- [events.json](examples/public-publishing/events.json),
  [event_0.json](examples/public-publishing/event_0.json), and
  [event_1.json](examples/public-publishing/event_1.json).
- [not_found.json](examples/public-publishing/not_found.json) and
  [invalid_interval.json](examples/public-publishing/invalid_interval.json).
- [responses.json](examples/public-publishing/responses.json): measured status,
  allowlisted headers and body byte counts for 15 GET, HEAD and conditional requests.
- [small portrait](examples/public-publishing/portrait_0_small.webp) and
  [large portrait](examples/public-publishing/portrait_0_large.webp): plain blue
  test cards, with no likeness or personal metadata.

The URLs inside `featured.json` are directly fetchable while the original synthetic
server/database exists. A newly prepared database gets different random public
IDs; discover them from the feed. To regenerate captures and verify all details:

```sh
RAILS_ENV=test bin/rails runner script/check_public_publisher.rb
```

Captures default to `tmp/publisher-examples`; set `PUBLISHER_EXAMPLES_DIR` to choose
another directory. Collection examples are 926 and 900 bytes; the synthetic small
and large WebPs are 306 and 990 bytes. These are not load-test measurements. The
feed stays complete even for larger collections; the consumer's 2 MiB ceiling and
1/2/4-second transport limits still apply. Production volume/latency is unverified.

Example error bodies additionally verified by integration tests:

```json
{"schema_version":1,"error":{"code":"method_not_allowed","message":"Use GET or HEAD"}}
{"schema_version":1,"error":{"code":"rate_limited","message":"Try again later"}}
{"schema_version":1,"error":{"code":"unavailable","message":"Temporarily unavailable"}}
```

The 405 includes `Allow: GET, HEAD`; 429/503 include `Retry-After: 60`. All have
`Cache-Control: no-store`, and no internal reason or private identifier.

## Verification evidence

The new regression coverage verifies:

| Behavior | Evidence |
| --- | --- |
| Empty content and zero–three stories | Complete empty collections, ordered selections, rejection of a fourth story |
| Draft edits and explicit publication | Draft leaves snapshot unchanged; consent must cover exact text/photo; publication replaces snapshot |
| Rotation | Removal changes collection ETag; the published story detail remains available |
| Withdrawal/consent revocation | Detail and portrait return 404 even with old matching validators; placement is removed |
| Portrait replacement | Draft replacement keeps old image valid; publication changes revision and old URL returns 404 |
| Event editing and moves | Public wording is independently authored; source schedule/location remain old until approved republish; old interval empties while detail remains |
| Cancellation/restriction/deletion | Cancellation is immediate/sticky; private/internal restrictions withdraw; deletion keeps tombstone identity/audits |
| Eligibility | Public visibility alone never publishes; internal categories persist through `other`; title flags require recorded disposition |
| Interval edges | Exact lower/upper endpoints, null/equal timed ends, all-day exclusive/null ends, 93-day limit, spring/fall DST, stable ID tiebreak |
| Authorization | Explicit and office-derived grants; no implied admin grant; revoked publishing authority denied; calendar managers cannot approve eligibility |
| Races | Separate PostgreSQL connections in both commit orders; real lock-wait detection; source edits, cancellation, visibility restoration, internal designation/category, deletion, draft edits, withdrawal and consent revocation |
| Mutation paths | Restriction races also run through real HTML and bearer API requests in both commit orders |
| Freshness/outage | Current metadata on 304; publisher outage returns 503 instead of stale/empty success; actual companion client accepts Age: 240 for 59 seconds and fails closed after 61 seconds during an injected outage |
| Browser workflow | Upload, preview both crops, deny Publish before consent, publish, homepage selection and revoke consent at phone width |

The race tests exercise the shared transactional model path and both application
mutation interfaces. Unsupported callback-bypassing SQL/bulk writes are not an
editorial interface and must not be used to modify publication/source restrictions.

Final checks:

- `PARALLEL_WORKERS=1 bin/rails test:all --seed 56083`: **1,023 tests,
  7,044 assertions, zero failures/errors/skips**, including the existing browser
  suite and new publisher system test. An initial combined run exposed setup-state
  leakage in the new nontransactional concurrency fixture; that fixture was fixed
  and the same seed passed on rerun.
- Final first-setup grant exclusion and workspace checks after that run:
  `PARALLEL_WORKERS=1 bin/rails test test/controllers/setup_controller_test.rb
  test/controllers/dashboard_controller_test.rb test/controllers/website_publishing_admin_test.rb`:
  **37 tests / 260 assertions, zero failures/errors/skips**.
  `PARALLEL_WORKERS=1 bin/rails test test/controllers/admin/dashboard_controller_test.rb`:
  **9 tests / 80 assertions, zero failures/errors/skips**.
- Focused RuboCop: **28 changed Ruby files, no offenses** (`--force-exclusion
  --cache false`).
- `GEM_SPEC_CACHE=/tmp/legion-publisher-gem-specs bin/brakeman --no-pager`:
  **zero warnings/errors**. A temporary writable gem cache was needed by the sandbox.
- `bin/bundler-audit`: **no vulnerabilities found**.
- `bin/rails tailwindcss:build`, `git diff --check`, example JSON parsing and local
  handoff-link validation passed.
- Manual Chromium review at **1400px, 390px and 320px**: readable standard inputs,
  stacked review panels, decoded 320×400/640×800 portraits, readable Post-local
  dates, and no horizontal overflow. The system test also exercised actual upload,
  consent, publication, selection and revocation at 390px.
- `script/check_public_publisher.rb`: **15 captured response checks passed**;
  the real companion validator accepted every collection/detail. Its actual Client
  passed collection/detail and bounded-age outage checks via the documented
  test-only transport adapter.

Only the synthetic server on port **3105** was left running for local inspection;
the temporary port-3106 compatibility server was stopped. No production endpoint
was accessed or verified.

## Remaining dependencies

Select real publishing grants, collect consented text/photos, review actual event
eligibility, and authorize deployment/publication separately. Validate production
TLS, reverse-proxy/cache behavior, shared cache-backed throttling, real data volume,
and browser image loading against the chosen HTTPS origin before connecting the
live public site. No automatic synchronization of private records is needed.
