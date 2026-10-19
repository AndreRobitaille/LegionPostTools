# Public officers API

This is the version 1, read-only contract for the public website's officers page.
It provides current officer names and offices, the Post's saved role explanations,
and its general email address. Personal contact details remain private.

The website integration requires a backend release containing this route. Confirm
availability using the existing website connection before enabling production requests;
a complete empty 200 response is valid.

- Machine-readable contract: [OpenAPI 3.1](api/public-officers.openapi.json).
- Website implementation brief: [Public officers handoff](PUBLIC_OFFICERS_WEBSITE_HANDOFF.md).
- Other website feeds: [Publisher handoff](PUBLIC_PUBLISHING_HANDOFF.md).

## Endpoint and authentication

| Item | Contract |
| --- | --- |
| Method/path | `GET /public/v1/officers`; `HEAD` returns equivalent status/headers without a body |
| Production origin for Post 165 | `https://members.wipost165.org`; other installations use their publisher origin |
| Authentication | `Authorization: Bearer <Post-owned website token>` on every request |
| Successful body | `application/json`, UTF-8 |
| Query/body | No supported filters, pagination, historical-date parameter or request body |
| Scope | The authenticated website token's Post only |
| Writes | None; other methods return 405 after authentication |

Use the existing server-side website connection (`lptw_…` token). Browser sessions,
personal agent tokens, query-string credentials and anonymous requests are not accepted.
A human administrator manages the connection under **Administration → Website connections**;
there is no token-management API. See [Website connections](WEBSITE_CONNECTIONS.md).
Keep the credential in the website server's secret storage, out of rendered pages,
browser JavaScript, public logs and URLs. There is no browser CORS integration.

Send this request from the website server using its stored token:

```http
GET /public/v1/officers HTTP/1.1
Host: members.wipost165.org
Authorization: Bearer <website token from server secret storage>
Accept: application/json
```

## Successful response

This is synthetic example data, not the Post's actual officer list:

```json
{
  "schema_version": 1,
  "complete": true,
  "as_of": "2026-10-18",
  "timezone": "America/Chicago",
  "post": {
    "name": "Example American Legion Post",
    "email": "post@example.test"
  },
  "officers": [
    {
      "name": "Morgan Example",
      "office": "Commander",
      "responsibility": "Leads the Post's work and coordinates its officers and committees.",
      "examples": [
        "You have a concern about a Post decision or how you were treated.",
        "You want to raise an issue at a Post meeting."
      ],
      "primary_contact": true,
      "display_order": 1
    },
    {
      "name": "Drew Example",
      "office": "Assistant Chaplain",
      "responsibility": "Assists the Chaplain.",
      "examples": [],
      "primary_contact": false,
      "display_order": 11
    }
  ]
}
```

Every field below is present. Nullable values are JSON `null`, not omitted keys.

| Field | Type | Meaning |
| --- | --- | --- |
| `schema_version` | integer, exactly `1` | Supported response version; reject unsupported versions |
| `complete` | boolean, exactly `true` | Full eligible collection; no pagination or silent truncation |
| `as_of` | ISO date string (`YYYY-MM-DD`) | Post-local date used to select current assignments; not a historical-query control or fetch timestamp |
| `timezone` | string | IANA timezone used for that date, such as `America/Chicago` |
| `post` | object | Public Post identity and general contact route |
| `post.name` | string | Configured Post name |
| `post.email` | string or null | Configured general Post email; never an officer's personal email |
| `officers` | array of officer objects | Zero or more current, eligible officer/office pairs |
| `officers[].name` | string | Current directory name formatted in first-name then last-name order; no stable person identifier is supplied |
| `officers[].office` | string | Configured office title; custom titles are possible |
| `officers[].responsibility` | string or null | Saved role sentence, at most 1,000 characters; null when blank |
| `officers[].examples` | string array | Zero to two ordered member situations; each is nonblank and at most 300 characters |
| `officers[].primary_contact` | boolean | True for offices named Commander or Service Officer; false otherwise |
| `officers[].display_order` | integer | Configured office order; values need not be contiguous, positive or unique |

Names prefer the current saved `roster_name`, matching the member directory, and
reorder a `Last, First` label. The split `first_name` and `last_name` fields are the
fallback when no roster name exists; they can predate later roster imports. Names
already in first-name-first order retain that order. Preserve middle names and
initials. A roster Sr/Jr prefix before a name moves to the end as well. A trailing
generational suffix (`Sr`, `Jr`, with or without a period, or
II, III or IV) in either name part appears once at the end of the display name,
with its recorded capitalization and optional period. Put a comma before Sr/Jr and
a space before Roman numerals. For example, a roster name of
“Example, Sr. Charles” and “Example, Charles Sr.” both display as
“Charles Example, Sr.” The raw roster label is
not returned; consumers should display the supplied name without parsing or
rearranging it. This formatting does not rewrite the saved name fields.

All names and copy are plain text. Escape them when rendering; never treat them as
HTML. Render “Contact them when:” only when `examples` is nonempty. Assistants have
an assistance sentence and an empty examples array. A publicly listed custom office
can have `responsibility: null` and `examples: []`; still display its officer's name
and office. Build a normal mailto link from `post.email` when present.

The array is ordered by office display order, office title, then stored officer last
and first names, with assignment id as an internal tie-breaker. Preserve the returned
order rather than sorting displayed names in the browser. Internal ids are not returned.
One person holding multiple offices produces multiple entries. Different people can
have identical display names; do not merge rows or use names as unique identities.

## Selection, turnover and absence

An entry appears only when all of the following are true:

1. Its office belongs to the token's Post, is active, and has public officer listing enabled.
2. Its assignment starts on or before `as_of` and has no end date or ends on/after `as_of`.
3. Its person is directory-visible: not roster-removed and not marked deceased or expired.

Both date bounds are inclusive. Account/login availability is not a listing requirement.
Duplicate assignments for the same person and office collapse to one entry. Unassigned
offices do not create placeholders. Absence does not declare a vacancy or prove that
someone is not a Post member; this is not an export of the full membership roster.

The migrations and new-installation preset initially select the standard officer
offices, including Assistant Chaplain. Custom offices start unlisted. An administrator
can edit the explanation and public-listing choice in **Administration → Post Positions
→ Edit contact guidance**. The member page and API use the same saved explanation.
Clearing its text hides only the explanation; turning off public listing removes that
office's names from this feed. Ending an assignment, deactivating the office or applying
a directory exclusion also removes the corresponding entries on subsequent origin reads.

Names, text and assignments follow current records automatically. This policy supplies
names and role text only. Individual email addresses, phone numbers, home addresses,
membership numbers, assignment dates, account status, internal ids, private profile
links and portraits are excluded. Introductions and portraits keep their separate
consent/publication workflow.

These are valid results, not upstream failures:

```json
{
  "schema_version": 1,
  "complete": true,
  "as_of": "2026-10-18",
  "timezone": "America/Chicago",
  "post": { "name": "Example American Legion Post", "email": null },
  "officers": []
}
```

## Caching, conditional requests and removal

Successful responses include `ETag`, `Date`, `Age: 0`, `Vary: Authorization`,
`X-Content-Type-Options: nosniff`, and
`Cache-Control: private, max-age=300, must-revalidate`. Cache directive order is not
significant. Keep the cache on the website server and key it by publisher origin,
credential and request path; do not put publisher responses in a shared proxy/CDN cache.

Carry forward the response's remaining freshness budget rather than starting a new
five-minute lifetime at every downstream hop. Expired content cannot be served on an
upstream failure. After fetching again, replace the full collection so removed officers
disappear. Never fill gaps with private APIs, copied descriptions or inferred contacts.

To revalidate a cached response, return its opaque ETag exactly, including quotes:

```http
GET /public/v1/officers HTTP/1.1
Host: members.wipost165.org
Authorization: Bearer <website token from server secret storage>
Accept: application/json
If-None-Match: "<ETag from the previous response>"
```

An unchanged, authorized representation returns **304 with no body**; use the saved
body and refreshed cache metadata. A changed representation returns **200 and a new
body/ETag**. Changes include names, guidance, the general Post email, visible listing
changes, and the Post-local date. The token is checked before any 304 decision.
`HEAD /public/v1/officers` also requires the token and has no response body.

Revocation and removals affect subsequent origin requests immediately. Already fetched
content can remain visible for the remainder of its existing 300-second freshness
budget. A 401 invalidates cached access even if an older cached body is still available.

## Errors and consumer recovery

Errors use `Cache-Control: no-store`, contain no ETag, and have this shape unless the
request is HEAD (which has no body):

```json
{
  "schema_version": 1,
  "error": {
    "code": "unauthorized",
    "message": "A valid website token is required"
  }
}
```

| Status / code | Meaning | Consumer action |
| --- | --- | --- |
| `200` | Complete current collection, possibly empty | Validate and replace the collection |
| `304` | Authorized cached representation is unchanged | Reuse its body and update cache metadata |
| `401 unauthorized` | Missing, malformed, invalid or revoked website token | Clear cached access, fail closed and check the server-side connection; `WWW-Authenticate: Bearer realm="website"` is present |
| `405 method_not_allowed` | Authenticated request used a method other than GET/HEAD | Correct the method; `Allow: GET, HEAD` is present |
| `429 rate_limited` | Feed rate limit reached | Respect `Retry-After: 60`; avoid tight retries |
| `503 unavailable` | Publisher temporarily unavailable | Respect `Retry-After: 60`; show an unavailable state once cached content expires |
| `404 not_found` on this path | Wrong origin/path or a backend revision without this route | Verify the backend release; do not interpret this as an empty officer list |

Authentication runs before method/resource handling: an unsupported method without a
valid token returns 401. The shared feed limit is 240 requests/minute per client IP
across its routes, not 240 per officer or per token. Tokens remain valid until revoked;
they do not inherit the creator's current role or account status. Rotate them through
the website-connection screen, with overlap while testing the replacement.

For an incomplete/malformed response or unsupported schema version, use the consumer's
unavailable handling. Never render partially validated personal data or fall back to an
anonymous request or personal agent token. The public endpoint has no editorial writes,
Idempotency-Key requirement, CSRF token, token-management or individual-officer detail route.

## Consumer integration and verification

In `wipost165`, extend the existing `Publishing::Client` and `Publishing::Contract`
with a dedicated officers read/validation kind. Reuse their authentication, transport,
private cache and remaining-lifetime machinery. The
[implementation brief](PUBLIC_OFFICERS_WEBSITE_HANDOFF.md) gives the page requirements.

Use synthetic responses to verify normal officers, primary contacts, assistants,
nullable explanations/email, identical names, multiple offices, empty collections,
escaped text, malformed data, ETag changes, 304/HEAD, removal, token revocation and
upstream failure. Inspect rendered desktop and phone layouts. Backend verification
does not establish that the separate website page has been built or deployed.

## Documentation verification — October 18, 2026

Cross-checked this reference against the feed controller, officer projection, token
authentication, position validation and directory-exclusion policy. The OpenAPI 3.1
document passed `openapi-spec-validator`; its schemas validated all three Markdown
JSON examples and both OpenAPI success examples.

Nine synthetic integration requests were captured from the Rails test application
inside a rolled-back database transaction. Their bodies, statuses and relevant
authentication/cache headers matched the contract: normal officers (including an
assistant and a null explanation), 304, HEAD, 401, 405, 404, 503, an empty list with
null Post email, and a revoked-token conditional request. The schema also rejected
eight malformed/private-field variants, including missing fields, incorrect types,
an extra personal phone field and too many examples. The 429 example was checked
against the schema and controller's rate-limit handler, not produced by load testing.

Local documentation links and `git diff --check` passed. These checks use synthetic
test data; they do not establish deployment or a completed companion website page.
