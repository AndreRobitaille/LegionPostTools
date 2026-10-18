# Members site sharing implementation handoff

Local implementation on October 17, 2026. Session:
`01a14abb-d1e3-74b3-abf4-daf59ee755e6`.

## Result

The approved Noto Sans Bold M is installed for members sharing and browser/saved
shortcut icons. Post 165's existing deployment profile selects **Post 165 Members**,
the approved description/alt text, members origin, and 1200 × 630 JPEG. Other
installations default to a generic American Legion Post Members identity and card.
The configured HTTPS origin supplies preview URLs; request Host and query input do
not supply metadata. Signed-in browser titles retain their existing page meaning.

The approved source assets, editable Python builder, bundled font, OFL notice,
thumbnail/icon review sheets, and checksums are in the repository. The builder adds
optional output/label arguments for regeneration without the original package.
Every regenerated PNG, JPEG, and ICO matches the approved package byte for byte.
Runtime typography is unchanged. The generic favicon SVG's accessible title says
Post Members; its Noto M outline matches the approved glyph.

Ordinary HTML navigation now survives email-code, magic-link, and passkey sign-in
for 15 minutes in the same browser. An explicit path allowlist, session rotation,
one-time consumption, and destination authorization apply. Queries are discarded;
POST, HEAD, JSON/API, token, auth, internal, and file routes are not saved. Mobile
OAuth retains priority. Direct passkey sign-in without a pending return retains
its existing JSON response. See [policy and configuration](../MEMBERS_SITE_SHARING.md)
and the [member guide](../MEMBER_SIGN_IN_GUIDE.md).

The existing outermost `NoIndexHeader` middleware and HTML noindex policy were
already implemented. They are retained, with expanded tests for static assets,
errors, redirects, PDFs, and Active Storage proxy/redirect/local-disk delivery.
`robots.txt` still permits crawling so clients can read noindex. No crawler bypass,
service worker, offline behavior, or public-site change was added.

## Changed paths

Runtime/configuration:

- `app/controllers/application_controller.rb`
- `app/controllers/passkeys_controller.rb`
- `app/helpers/application_helper.rb`
- `app/models/sign_in_return_path.rb`
- `app/views/shared/_members_metadata.html.erb`
- `app/views/layouts/application.html.erb`
- `app/views/layouts/entry.html.erb`
- `app/views/layouts/print.html.erb`
- `app/views/sessions/new.html.erb`
- `app/views/sessions/code.html.erb`
- `app/views/sessions/magic_link.html.erb`
- `config/initializers/members_site.rb`
- `config/deploy.yml` (local configuration only)
- `lib/members_site.rb`

Shipped assets:

- `public/favicon.svg`, `public/favicon-96.png`, `public/favicon.ico`
- `public/apple-touch-icon.png`
- `public/icon.svg`, `public/icon.png` (compatible aliases)
- `public/members/members-og.jpg`, `public/members/post165/members-og.jpg`
- `public/members/app-icon-192.png`, `public/members/app-icon-512.png`
- `design/members-sharing/`: approved reference exports and historical handoff,
  `build.py`, `README.md`, `SHA256SUMS`, and `fonts/NotoSans-Bold.woff` / `fonts/OFL.txt`.

Documentation:

- `README.md`
- `docs/MEMBER_SIGN_IN_GUIDE.md`
- `docs/MEMBERS_SITE_SHARING.md`
- This implementation handoff.

Tests:

- `test/controllers/dated_agenda_pdf_sources_controller_test.rb`
- `test/controllers/dated_agendas_controller_test.rb`
- `test/controllers/mobile_authentication_test.rb`
- `test/controllers/sessions_controller_test.rb`
- `test/integration/login_page_test.rb`
- `test/integration/search_engine_indexing_test.rb`
- `test/integration/members_site_sharing_test.rb`
- `test/integration/shared_link_sign_in_test.rb`
- `test/lib/members_site_test.rb`
- `test/models/sign_in_return_path_test.rb`
- `test/system/shared_link_sign_in_test.rb`

## Verification

All application checks used `RAILS_ENV=test` and synthetic records. Test and system
runners were serial relative to each other. No development database was queried,
used, copied, or reset. No production connection, commit, push, merge, deployment,
paid application AI call, external message, public website edit, or subagent was used.

Request tests exercise generic signed-out metadata (including an ordinary preview
user agent and an untrusted Host), token GET/HEAD without consumption, absolute image
URLs, MIME types/dimensions, icon links/ICO frames, useful signed-in titles, internal
PDF-source metadata, and noindex delivery boundaries. Return tests exercise email
retry, session rotation, later reads, single-use links, expired paths, browser/cookie
changes, latest-navigation behavior, rejected destinations, changed permissions,
withdrawn agenda visibility, passkey challenge arguments, and OAuth priority for
all three sign-in methods. Existing mobile tests continue through consent and PKCE
token exchange. The browser passkey test uses real WebAuthn with Chromium's virtual
authenticator; the integration passkey tests substitute the credential verifier.

An isolated copy at `/tmp/members-sharing-regression` retained the new tests and
restored the original two authentication controllers. Email-code and magic-link
return tests failed because they landed at root; passkey return errored because the
original response had no destination. The project checkout was not fault-modified.
The first broader run also detected an unnecessary default passkey JSON change; that
change was removed to retain compatibility, and the initial run was interrupted.
Early new-test failures involving browser assertions and the integration harness
were corrected. The initial Brakeman invocation could not write its global gem-spec
cache; rerunning with `GEM_SPEC_CACHE=/tmp/members-sharing-gem-specs` resolved it.

Visual review inspected the approved 240/320 px card thumbnails and actual small
favicons, plus entry screenshots at 1400, 390, and 320 px. The new heading fits, wraps
at 320 px, and preserves the established system sans, emblem, colors, spacing, and
large controls without horizontal overflow. Local screenshots are in
`tmp/members-sharing-review` (ignored), with card/icon references in the tracked
source package. This is local rendering evidence, not a messaging-client preview.

The Buddy Check same-day offline-entry test also fails against the original
controllers in the isolated copy: its setup creates a drive starting two days before
the actual current date, then the test travels back to October 11, 2026. On October 17,
that instant precedes the drive's start and assignment lookup raises RecordNotFound.
This unrelated test/source was left unchanged. Two old sign-in heading expectations
were updated for the approved configurable identity. The first full run executed
1,510 tests with those two stale assertion failures plus the unrelated error; the
updated full run is recorded below. Bundler's fallback temporary-home cleanup also
printed fork cleanup errors in that first parallel run; the final run uses a stable
`BUNDLE_USER_HOME` under `/tmp`.

Final command results:

| Check | Result |
| --- | --- |
| `BUNDLE_USER_HOME=/tmp/members-sharing-bundle-home RAILS_ENV=test PARALLEL_WORKERS=4 bin/rails test` | 1,510 runs, 15,678 assertions, 0 failures, 1 unrelated baseline error, 0 skips |
| `RAILS_ENV=test RUBOCOP_CACHE_ROOT=/tmp/members-sharing-rubocop bin/rubocop` | 643 files, no offenses |
| `GEM_SPEC_CACHE=/tmp/members-sharing-gem-specs RAILS_ENV=test bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` | 0 errors, 0 security warnings |
| `RAILS_ENV=test bin/bundler-audit` | No vulnerabilities found |
| `sha256sum -c SHA256SUMS` in `design/members-sharing` | All 21 files verified |
| `python design/members-sharing/build.py --output /tmp/members-sharing-rebuild` | All 13 raster/ICO outputs match approved reference exports |
| `python design/members-sharing/build.py --output /tmp/members-sharing-generic --post-label POST --locality 'American Legion'` | Generic fallback built successfully |
| `git diff --check`, local Markdown reference checks, unrelated-file SHA256 comparison | Passed |
| `BUNDLE_USER_HOME=/tmp/members-sharing-bundle-home RAILS_ENV=test SYSTEM_TEST_CAPTURE_DIR=tmp/members-sharing-review bin/rails test:system` | 108 runs, 5,813 assertions, 0 failures/errors/skips |

The ordinary suite therefore is **not entirely green** because of the independently
reproduced, unchanged Buddy Check date test. All affected request/model tests and the
entire browser suite pass. No CI or production result is claimed.

## Remaining boundaries

No live iMessage/social preview, real device passkey prompt, deployed revision, or
production proxy response was verified. Those remain separate release/device checks.
The Rails header policy cannot set headers on future external object-storage/CDN
responses or errors produced solely by an upstream proxy; those need that server's
own header configuration if introduced. Current Active Storage uses local disk.

The five unrelated mobile handoff files identified in the request remain byte for
byte unchanged from the initial worktree snapshot, including their pre-existing
modified/untracked state. Nothing was staged.
