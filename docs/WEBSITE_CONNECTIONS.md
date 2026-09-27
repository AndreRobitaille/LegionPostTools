# Post-owned website connections

September 27, 2026. This design supersedes anonymous access in the original public
publishing contract. Implementation is local until explicitly released.

## Access and ownership

Every `/public/v1` request requires `Authorization: Bearer <website token>`,
including GET, HEAD, portraits, unknown paths and conditional requests. The path
name describes content intended for publication, not anonymous access. Browser
sessions and personal agent tokens cannot authenticate this interface. Existing
`/api` editorial and member routes retain their human/session or personal-agent
authentication; website tokens cannot access them.

A `WebsiteAccessToken` belongs to an Organization. The creating administrator and
revoking administrator are audit references, not the identity used for requests.
Disabling an administrator or changing their permissions does not disconnect the
website. Only administrators with `manage_settings` may create/revoke tokens;
creation requires recent human authentication. Publication authority remains the
separate `publish_public_content` capability.

Website access is a fixed feature boundary, not a role or configurable permission
bundle. Tokens never inherit officer roles or user grants and cannot be upgraded
to editorial or general API access.

Token creation and management are browser-only. No API route creates, reveals,
rotates or revokes a website or personal agent token. A bearer credential alone
cannot authenticate the token-management screens. The private `GET /api` handbook
documents the distinction in JSON `website_access` and Markdown **Website
connection access**, outside its actionable API catalog.

Tokens have a random identifier and 256-bit secret, a distinct prefix, a stored
keyed digest, a recognizable name, creation/revocation timestamps and last use.
The secret appears only in the creation response, which is no-store and excluded
from Turbo snapshots. It is never stored in the database or placed in a URL.
Connections last until revoked to avoid an unattended website outage. Replacement
uses create, install/test on the website server, then revoke the old token; the
overlap makes rotation possible without downtime. Revoked rows are retained.

## Website contract and rollout

Payloads and publication/consent restrictions stay the same. The token selects
its Post, including for detail and portrait lookups. Authentication precedes ETag
evaluation. Missing, malformed and revoked credentials return 401 with no-store
and a Bearer challenge, without revealing whether a requested record exists.
Successful responses use `private, max-age=300, must-revalidate` and
`Vary: Authorization`; no shared HTTP cache may serve the publisher API.

The public website must store this credential server-side, fetch JSON and portraits
with it, and serve approved content through its own presentation routes. Never
embed publisher portrait URLs directly in public HTML or expose a token to browser
JavaScript. Its private application cache must be separated by credential and
honor the existing 300-second total freshness budget; 401 invalidates cached access
and fails closed. Other failures must not serve expired content.

This is a breaking consumer change. Before a coordinated release, adapt the
companion's HTTP authentication, cache-policy validation and portrait delivery.
Existing shared publisher caches may hold old anonymous responses for up to 300
seconds; purge them on rollout, or account for that remaining lifetime. This work
does not create live credentials, modify the companion, or deploy either app.

## Visual direction

Administration → Website connections → Create connection → Copy token → list.
Use The 1919 working-screen system: navy #0A2240 primary actions, cream #F4EEDD
background, paper #FBF7EC panels, gold #C6A15B section rules and red #8C1622 revoke
actions. System sans for working text; monospace only for the copyable secret.
Keep body/controls at least 16px, secondary text 14px and labels 13px.

The defining content is the named Post owner and the plain “Approved website
content only” boundary. Reuse the existing bounded token panels, section headers,
form fields and copy control. Keep each connection's status beside its revoke
action; stack on narrow screens. Show who created/revoked it and when, and whether
it has been used. Revoke has a dedicated confirmation page explaining the effect.
Review rendered creation, reveal and list screens at desktop and 390px widths.

## Verification

Cover one-time issuance, retained revocation audit, administrator/recent-sign-in
gates, CSRF, secret storage, independence from the creator, organization isolation,
all anonymous routes/methods, rejected personal/session credentials, revoked
conditional requests and portraits, and denial at private APIs. Retain publication
regression coverage with authenticated website requests. Run the full suite,
focused lint, security checks and desktop/narrow browser review.

## Local verification results

- `PARALLEL_WORKERS=1 bin/rails test:all --seed 24471`: 1,051 tests, 7,680
  assertions, zero failures, errors or skips, including the browser suite.
- Focused RuboCop: 17 changed Ruby source/test/migration files, no offenses.
  Generated `db/schema.rb` passed Ruby syntax checking separately.
- Brakeman 8.0.6: zero warnings and errors. Bundler Audit: no vulnerabilities.
- Browser review at 1400px and 390px: creation, one-time reveal, empty/list states,
  back-navigation secret removal and revocation passed; no horizontal overflow.
  Screenshots are under `tmp/screenshots/website-*`; reveal screenshots mask the
  synthetic secret. Existing type sizes and navy/paper components remain readable.
- Live HTTP on the isolated publisher demo database: the companion's payload
  Contract accepted three synthetic stories, two events and both portrait sizes.
  Thirty responses exercised authenticated GET/HEAD/304, 400/404 and anonymous 401.
  A subsequent revoked-token conditional request returned 401, no-store, no ETag.
  The synthetic credential was revoked and the temporary server stopped.
- Local documentation links and `git diff --check` passed.
- Follow-up token-management/API-documentation checks, seed 15521: 39 tests,
  726 assertions, zero failures, errors or skips. They verify absent API creation
  routes, rejection of both bearer types by browser token-management screens,
  and complete matching website-access guidance in JSON and Markdown `/api`.
  Focused lint on the three changed Ruby files, 19 documentation references and
  JSON example parsing passed. No authentication behavior changed in this follow-up.

The companion's current Client rejects `private` responses; its end-to-end
authenticated integration is not verified or implemented by this change. The live
check above exercised its payload Contract, not its Client cache or public portrait
delivery. No production migration, credential, grant, publication or deployment
was performed. Development/member data was not modified.
