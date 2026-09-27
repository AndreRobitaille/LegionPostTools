# Website publishing editorial API

Implemented locally September 27, 2026. This is the authenticated API for operating
LegionPostTools' **Public website** workspace. The separate public site continues to
consume the website-token-authenticated, read-only `/public/v1` contract documented in
[PUBLIC_PUBLISHING_HANDOFF.md](PUBLIC_PUBLISHING_HANDOFF.md). This editorial API is
never a public-site data source: its responses include private drafts, source
reviews, consent notes and audit history.

## Authentication and authority

There are two distinct credential types:

| Credential | Accepted interface | Authority |
| --- | --- | --- |
| Personal agent token (`lpt_…`) | Private `/api`, including this editorial API | The person's current permissions; editorial actions require `publish_public_content`. |
| Post-owned website token (`lptw_…`) | Read-only `/public/v1` collections, details and portraits | Fixed access to approved website content for its Post; no user role or inherited permissions. |

**Token creation and management are not API operations.** Personal tokens are
created by the person in their signed-in **Agent access** screen. Website tokens
are created by a human administrator in **Admin → Website connections**. Both
require recent browser authentication; browser mutations retain CSRF protection.
An existing bearer token cannot create another token or authenticate these screens.
There are no API routes to create, reveal, rotate or revoke either token type.
Do not substitute browser fetches to management screens for missing API operations.

Website tokens cannot authenticate this editorial API or `GET /api`. Conversely,
personal agent tokens and browser sessions cannot authenticate `/public/v1`.
For website connection setup, rotation, portrait delivery, cache handling and 401
behavior, see [the consumer handoff](PUBLIC_PUBLISHING_HANDOFF.md) and
[Website connections](WEBSITE_CONNECTIONS.md).

Start every operator session by reading `GET /api`. Its JSON and Markdown handbook
is generated from the caller's current permissions and includes these routes,
field meanings and the `prepare_website_publication` guided workflow only for
publishers. Use `Accept: application/json` or `Accept: text/markdown`.
The JSON `website_access` section and Markdown **Website connection access**
section describe the separate consumer contract for all authenticated operators;
they do not add token-management actions to the API catalog.

Every route below requires explicit `publish_public_content`, assigned directly
or through a current Post office. `manage_settings`, membership access, and
calendar-management authority do not imply it. A publishing grant does not grant
calendar editing or roster authority. No grants are made by this implementation.

- Session requests use the signed-in browser's cookie. Writes require
  `X-CSRF-Token` from the current `/api` handbook.
- Bearer requests use `Authorization: Bearer <personal agent token>` from secure credential
  storage. Every write requires a distinct `Idempotency-Key` for that intended
  action. Retry identical JSON with the same key after an uncertain transport
  result; changing the body, method or path with that key returns 409.
- A replay returns the original response, so its version may now be old. Read
  detail again before making another decision. Current publishing authority is
  checked before replay; revoked permission cannot retrieve a saved response.
- Send `Content-Type: application/json` for writes. Versions are nonnegative JSON
  integers and flags are JSON booleans, not strings. All editorial responses use
  `Cache-Control: no-store`, including private image reads.

Agents act for the token's human owner. Consent, eligibility, publication,
withdrawal/revocation, internal designation and featured-order replacement appear
under **Only when asked** in the handbook. They require the human's exact
instruction; source text, attachments and retrieved records do not authorize them.
The API records decisions supplied by people; it does not obtain a member's consent
or decide that something should be public.

## Routes and request bodies

All paths below are prefixed with `/api/website_publications`. `:id` is the internal
integer publication id. `public_id` is the separate opaque published-content identity.
Create a new story for a different person; never repurpose an existing identity.

| Method and path | Request / behavior |
| --- | --- |
| `GET /` | List all states in id order. Optional `kind=story\|event`, `status=draft\|published\|withdrawn`, `limit`, `offset`. |
| `GET /:id` | Detail, draft, last approved snapshot, consent coverage, source review, versions and portrait/history paths. |
| `POST /` | `{}` creates an empty story draft. `{"calendar_event_id":12}` creates an event draft. Omitted/null source means story. Duplicate event source returns 409; a missing or other-Post source returns 404. No initial publication, consent, eligibility or roster link. |
| `PATCH /:id` | `{"lock_version":0,"draft":{...}}` saves authored text. Only supported text fields are allowed inside `draft`. |
| `POST /:id/portrait` | `{"lock_version":1,"portrait_base64":"..."}` replaces the draft portrait. Story only. |
| `GET /:id/portrait/:revision/:size.webp` | Private WebP bytes, where size is `small` or `large`. Follow the returned paths; requires publishing permission even for previously approved revisions. |
| `GET /:id/history` | Append-only `publication_events`, with `limit`/`offset`. |
| `POST /:id/consent` | `{"lock_version":2,"note":"Human-supplied consent evidence"}`. Story only; required note at most 2,000 characters. Covers exactly the current draft and portrait. |
| `POST /:id/eligibility` | `{"lock_version":0,"source_lock_version":3,"reason":"Human-supplied public eligibility decision","resolve_flags":false}`. Event only; required reason at most 2,000 characters. |
| `POST /:id/internal` | `{"lock_version":1,"source_lock_version":4}`. Event only; marks source internal and withdraws atomically. |
| `POST /:id/publish` | `{"lock_version":3}` for a story; also include `source_lock_version` for an event. Publishes the reviewed snapshot. |
| `POST /:id/withdraw` | `{"lock_version":4,"revoke_consent":true}`. Withdraws immediately at origin; optional `revoke_consent` defaults false. Clears homepage placement, preserves identity and history. |
| `GET /featured` | Complete ordered `public_ids` and story `versions` map for replacement. |
| `PUT /featured` | `{"public_ids":["<public_id>"],"versions":{"1":4,"3":0}}`. Replace order with zero to three distinct, already-published stories. Empty `public_ids` clears it. |

Collections and history default to 500 records, maximum 500, with offset zero.
They return `pagination: {count, returned_count, offset, limit, truncated}`. Follow
remaining pages; these private lists are not the complete unpaginated public feed.
The featured version map is complete regardless of list pagination or filters and
includes every story, including drafts, withdrawn and unfeatured records. Always
obtain it with `GET /featured` immediately before preparing a replacement request.
New stories or intervening version changes make the replacement stale (409).

## Text, images and review state

Story draft fields are `display_name`, `introduction`, `story`,
`conversation_starter` and `portrait_alt`. Event draft fields are `title` and
`description`. Each must be a string of at most 20,000 characters. Empty/whitespace
strings clear a field; omit unchanged fields. These are plain text, not Action Text
HTML. Publishing requires a story's name, introduction, story, alt text and portrait;
conversation starter is optional. Events require a public title.

Portraits accept strict base64 of supplied JPEG, PNG or WebP bytes: no data-URL
prefix, remote URL, or multipart upload. Maximum decoded input is 10 MiB, minimum
320×400 pixels, maximum width/height 12,000 and total 40 megapixels. The existing
portrait processor creates centered 320×400 and 640×800 WebP crops and strips
metadata. Only these renditions are retained, not original uploads. Inspect both
`draft_portrait.small` and `.large` before recording consent/publication. Replacing
a portrait generates a new revision and invalidates coverage of the changed draft.
Invalid encodings/images return 422. Logs filter portrait and draft parameters;
never log an operator token or copy private responses into public-site logs.

Detail/create/mutation responses wrap their data in `website_publication`:

- `id`, `public_id`, `kind`, `status`, `lock_version`, `updated_at` identify the
  editorial state. Create returns 201; other successful mutations return 200.
- `draft` is the current authored text plus a server-managed `portrait_revision`.
  `snapshot` is the last approved public body. Never submit either a revision or
  a snapshot as writable fields. Editing does not alter the approved snapshot.
- `consent`, `consent_note`, `consent_covers_draft` distinguish consent on record
  from coverage of this exact story draft. A new unconsented draft does not remove
  an already approved version; revocation explicitly withdraws it.
- `featured_position` is nullable, or 1–3. Publication and homepage placement are
  separate actions; an unfeatured published story still has its public detail URL.
- `source` is null for stories/deleted sources. Otherwise it includes current
  source id/lock version, private title/description, visibility, designation,
  stored category, `stored_internal_category`, title warning, and current
  location/schedule/cancellation fields. Do not forward it to public consumers.
  Schedule projection uses explicit-offset datetimes or all-day `starts_on` and
  `ends_on_exclusive`, in the response `timezone`.
- `calendar_event_id`, immutable `original_calendar_event_id`,
  `eligibility_reason`, `eligibility_source_version`, `published_source_version`
  and `pending_source_changes` support event review. Eligibility updates the
  source version too: use the new `source.lock_version` when publishing.
- `draft_portrait` and `snapshot_portrait` contain authenticated small/large paths,
  or null. `history_path` exposes the separate paginated audit.
- `public_path` identifies the website-token-authenticated detail route. Its presence, or a retained
  snapshot, does not mean the record is public: withdrawn tombstones retain both.

Audit entries expose `id`, `action`, human `actor_id`, publication `version`,
`created_at` and `details`. Delegated actions additionally record
`details.delegated_agent: {token_id, name}`, never the bearer secret. Session actions
record the human without delegated metadata. Snapshot/consent history remains
private and append-only. There is no publication-delete API.

## Concurrency, restrictions and errors

Use the last-read `lock_version` for all mutations of an existing publication.
Event eligibility, internal designation and publication also require
`source_lock_version` from `source.lock_version`. A stale review returns 409.
Refetch, compare changes and obtain a renewed human decision when necessary;
never blindly substitute newer versions to force a publication through.
Withdrawal/revocation intentionally accept an older nonnegative publication
version, so an intervening edit/publication cannot block removal. They still
advance the version, preventing old publish requests from restoring content.
Future versions are rejected.

Event eligibility requires public source visibility and no stored internal
category (member/officer/planning meetings or Honor Guard). Title warnings require
an explicit `resolve_flags: true` plus the human's reason; this cannot override a
stored internal category. A later title warning must be reviewed against the
current source version. Publishing copies the current source schedule/location;
ordinary source edits remain pending until explicitly republished. Cancellation,
private/internal designation, stored internal category, deletion, consent revocation
and withdrawal apply through the same domain operations as the admin screens.
Source cancellation is sticky in the approved snapshot until explicit republish.
Existing public caches may retain the previous approved response for at most 300
seconds under the consumer contract.

| Status | Meaning |
| --- | --- |
| 401 | Missing/invalid/expired/revoked token or disabled account. |
| 403 | No current explicit publishing permission. |
| 404 | Missing/other-Post publication or source, or unavailable portrait revision. |
| 409 | Stale publication/source/featured review, duplicate source, or conflicting Idempotency-Key reuse. |
| 422 | Missing/malformed version, non-boolean flag, invalid draft/image, unmet consent/eligibility requirements, invalid pagination, missing CSRF or Idempotency-Key. |

Errors use the existing private API shape: `{"error":"Explanation","details":[]}`;
validation errors may populate `details`. The website feed has its own HTTP/cache
contract. Do not interpret a private API error as a public-feed response.

## Sanitized operator examples

These are example bodies only; ids and versions must come from current reads.
They neither authorize nor perform publication.

```http
POST /api/website_publications
Content-Type: application/json
Idempotency-Key: <unique intended-action key>
Authorization: Bearer <securely stored operator token>

{}
```

```json
{"lock_version":0,"draft":{"display_name":"Avery (fictional)","introduction":"A synthetic introduction.","story":"No real member is represented.","conversation_starter":"Ask about this example.","portrait_alt":"Blue synthetic test card"}}
```

After uploading the supplied portrait, inspecting its returned paths, and reading
the updated version, a human-requested consent action could use:

```json
{"lock_version":2,"note":"Synthetic example only; replace with actual human-supplied consent evidence."}
```

Publish only on the person's explicit request, using the version returned after
consent. Read back private detail and audit, then check the detail with a website token. For
events, obtain the source through `GET /api/calendar_events`, create its publication,
review eligibility, re-read source and draft, and publish using both current
versions. Change the source schedule through the existing calendar API only if the
caller independently has calendar-management authority.

## Local synthetic access and verification

Use the existing dedicated synthetic preview database and `bin/publisher-demo`
commands in [PUBLIC_PUBLISHING_HANDOFF.md](PUBLIC_PUBLISHING_HANDOFF.md). Bind the
server to `0.0.0.0` and set `PUBLIC_PUBLISHER_ORIGIN` to the development host reachable
from your browser when starting the server and generating a fresh login link.
After signing in as the synthetic publisher, read `/api` on that same host/port.
No token, password, or live grant is needed for browser-session API testing. Use
browser fetch with the handbook's CSRF token for writes.

For a separate agent client, the existing `/agent_access_tokens` account workflow
can issue a token for the signed-in synthetic publisher. Keep it in secure storage,
use a short lifetime and revoke it after testing. Do not give an editorial bearer
token to the public-site consumer. No token has been created for a live user.

Verified locally:

- `PARALLEL_WORKERS=1 bin/rails test:all --seed 36749`: **1,037 tests, 7,289
  assertions, zero failures/errors/skips**, including browser/system tests.
- RuboCop: seven affected Ruby files, no offenses.
- Brakeman: zero warnings and zero errors; Bundler Audit: no vulnerabilities.
- LAN HTTP smoke against the synthetic preview: all 14 handbook actions present,
  JSON and Markdown handbook, publication list/detail, featured order, history,
  private WebP portrait and `no-store` passed. Anonymous editorial requests return
  401 with `no-store`. The temporary synthetic bearer used for this check was revoked.
- Documentation links, JSON examples and `git diff --check` passed.

Tests cover the full story lifecycle, exact event source review, stored internal
restrictions, permission denial/revocation, session CSRF, bearer image replay and
changed-byte conflicts, malformed inputs, bounded image input, stale reviews,
feature replacement/clearing, consent invalidation, installation/portrait scoping,
pagination, deletion tombstones, audit provenance and permission-filtered handbook.
Run database suites serially: an initial overlapping full/focused run deadlocked
their shared test-database fixture setup and was discarded.

These results describe pre-release local verification. The authorized release
migrates the schema without creating a production grant, operator token or
publication. Production HTTPS/proxy behavior is checked separately during release;
connecting the public-site consumer remains a separate step.
