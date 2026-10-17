# Members site identity, sharing, and sign-in return

Approved direction implemented October 17, 2026. Internal links identify this service as
Post Members, distinct from a Post's public website. The first installation uses
**Post 165 Members**, the approved Noto Sans Bold M, authority navy `#0A2240`, service
gold `#C6A15B`, and cream `#F4EEDD`. The sharing card keeps its Liberation Sans labels.
These are artwork fonts; application working screens retain The 1919 system sans and
documents retain their existing typography. Entry headings use the configured members
name within the established sign-in layout. Review at desktop and phone widths, card
thumbnails at 240/320 px, and favicons at 16/32 px.

## Public identity and private records

Identity is installation configuration, independent of member records. All layout
sharing fields use one generic name, description, image, and configured HTTPS origin.
Signed-out HTML titles use that name. Signed-in browser titles may still describe the
page; social metadata never includes those titles. No request Host, query, token, person,
agenda, or minutes content is used to build social metadata. Preview clients receive
the ordinary signed-out page through the existing authentication redirect. GET/HEAD of
an email link still displays confirmation only; sign-in requires POST.

`MEMBERS_SITE_NAME`, `MEMBERS_SITE_DESCRIPTION`, `MEMBERS_SITE_ORIGIN`,
`MEMBERS_SITE_IMAGE_PATH`, and `MEMBERS_SITE_IMAGE_ALT` configure the identity.
The origin accepts HTTPS with a host and optional port, with no credentials, query,
fragment, or non-root path. It defaults to HTTPS on `APP_HOST`, or `example.invalid`
for an unconfigured local installation. The entry URL is the origin's root. Image
paths must identify a local JPEG under `/members/`; image URLs always use that origin.
Defaults use a generic American Legion Post Members card. The existing Post 165 Kamal
profile selects the approved Post 165 text and card. No deployment is part of this work.

Editable artwork, bundled Noto Sans Bold font, OFL notice, and original package checksums
are in `design/members-sharing`. See its README for regeneration and installation.
Icons use the same generic M in every installation. No service worker or offline cache
is added. Existing `/icon.svg` and `/icon.png` URLs remain compatible.

HTML retains `noindex, nofollow`; the existing outermost `NoIndexHeader` middleware
also covers redirects, JSON, static files, Rails-rendered errors, PDF responses, and
Active Storage redirect/proxy/local-disk delivery. `robots.txt` continues to allow
fetches so crawlers can read noindex. Authentication and authorization protect private
content. Noindex is an indexing instruction, not an access control. Current storage is
local disk served through Rails. Any future external object-storage/CDN delivery must
set its own noindex headers; the Rails redirect cannot set headers on another server.
Likewise an upstream proxy-generated error requires that proxy's own header policy.

## Ordinary navigation after sign-in

A signed-out member following a supported HTML GET returns to that page after email
code, magic-link confirmation, or passkey sign-in in the same browser. This intentionally
changes the former dashboard-only behavior. The destination is held only in the signed
Rails browser session for 15 minutes, survives session rotation, and is consumed once
at successful sign-in. The most recent supported protected navigation wins. Invalid or
expired sign-in attempts leave an unexpired destination available for retry.

Supported paths are root/dashboard/profile/officer tools, member meeting and agenda
lists/details, member minutes details, calendar/event details, people lists/details,
Endeavor lists/details, and selected officer meeting/agenda viewing pages. The exact
anchored allowlist is `SignInReturnPath::NAVIGATION_PATHS`. Only canonical paths with
numeric record IDs are accepted. Query strings and fragments are not retained (including
filters, revision selectors, codes, and tokens). PDFs, internal renderers, API/JSON,
authentication/reauthentication, OAuth, token-management, setup, arbitrary edit/action
paths, external URLs, and protocol-relative URLs are excluded. POST/HEAD requests are
never recorded or replayed. Sign-in does not accept a user-supplied `return_to` parameter.

Every returned request goes through its controller's current permissions and visibility
rules. A removed/private record or changed officer grant can therefore deny access after
sign-in. Saving a path grants no access and performs no action. Official-record authority
and reauthentication rules are unchanged.

Email links contain no destination. Opening one in a different browser/device uses that
browser's own unexpired destination, if any, otherwise the dashboard. Clearing browser
cookies loses the destination. The emailed code still requires its requesting browser.
There is no promise of cross-device return. Existing validated mobile OAuth return takes
priority and consumes any ordinary destination; its consent, state, PKCE, and callback
validation remain in force.
