# Members site sharing and identity handoff

Prepared October 17, 2026 for the existing LegionPostTools project session.

## Goal and scope

Give internal links a clear **Post 165 Members** identity in text messages, browser
tabs, and saved shortcuts. Keep the members application out of search results and
keep all private information behind its existing authentication and authorization.
The public website has its own blue card and Legion-emblem favicon. These assets
use the members application's established navy, gold, and cream palette, with a
gold M mark and a conspicuous MEMBERS label.

The M is now the **Noto Sans Bold** glyph, as specifically requested by Andre.
It replaces the earlier custom-drawn letter everywhere: sharing artwork,
favicons, touch icon, and app icons. The glyph retains its original proportions
and is outlined in the exported SVGs, so browsers do not need to load a font.

Andre accepted this direction and asked how to divide the work between sessions.
This package prepares the visuals and the implementation handoff. It does not
modify the members repository or deploy anything. The finished artwork is ready
for Andre to review. The other session should receive its implementation request
from Andre and follow that project's current guidance and authorization.

## Asset package

This directory is outside both repositories:

`/home/andre/.codex/visualizations/2026/10/17/01a14a49-9283-7151-ab0c-49757282d941/post165-members-sharing`

| File | Purpose |
| --- | --- |
| `members-og.jpg` | Shipped 1200 × 630 sharing image |
| `members-og.png` | Lossless full-size copy |
| `members-og.svg` | Font-independent vector artwork; labels outlined |
| `preview-320.png`, `preview-240.png` | Actual thumbnail-size review |
| `favicon.svg` | Rounded navy tile, gold M, no external fonts |
| `favicon-96.png` | PNG favicon fallback |
| `favicon.ico` | Embedded 16, 32, and 48 px variants |
| `favicon-16.png`, `favicon-32.png`, `favicon-48.png` | Individual small renders |
| `apple-touch-icon.png` | Opaque 180 × 180 touch icon |
| `app-icon-192.png`, `app-icon-512.png` | Opaque app/shortcut icons if needed |
| `favicon-review.png` | Actual-size icons above enlarged pixel views |
| `app-icon.svg` | Square icon source for OS-applied corner masks |
| `build.py` | Editable text, layout, icon paths, palette, and deterministic export |
| `fonts/NotoSans-Bold.woff` | Bundled source font for the M glyph |
| `fonts/OFL.txt` | Noto Sans copyright and SIL Open Font License 1.1 |
| `SHA256SUMS` | Checksums regenerated with the package |

Design: authority navy #0A2240, service gold #C6A15B, cream #F4EEDD. Simple
system-style sans lettering; no serif document typography, no modified Legion
logo, no small captions, and no private records. The M means Members.

Only the M has changed to Noto Sans Bold. The card's other labels retain their
previous Liberation Sans Regular/Bold treatment, size, and placement. This is
an asset-specific font choice, not a request to change application typography.

Rebuild with `python build.py`. Dependencies: Python fontTools, fontconfig,
Liberation Sans Regular/Bold, rsvg-convert, and ImageMagick.
The Noto font is a byte-identical copy of the public project's
`app/assets/fonts/body-bold.woff` (Noto Sans Bold, version 2.015). Its copyright
and license are included from the [official Google Fonts Noto Sans source](https://github.com/google/fonts/blob/main/ofl/notosans/OFL.txt).
The builder verifies the Noto Sans family and 700 weight before outlining the M.
Shipped SVGs contain outlined text and work without fonts. All exported files
are self-contained. Copy the font and its license along with the build source
when bringing the editable package into the target repository.

For crawler compatibility, use the same gold-M-on-navy identity with a stable
96 × 96 PNG icon URL, plus SVG and 16/32/48 px ICO browser fallbacks. There is no
separate crawler-specific logo. Retain the members service's noindex policy.

## Suggested implementation scope

1. Follow current `AGENTS.md` and inspect the worktree. Preserve unrelated work.
   Keep installation identity configurable; the Post 165 artwork is for this
   installation, not an application-wide assumption for all posts. Use an
   appropriate generic fallback/configuration for another installation.
2. Wire the favicon and touch icon into both entry and authenticated layouts.
   Update the default display/application name to the installation's members
   identity. Copy useful sources into the repository so regeneration does not
   depend on this external package directory. Do not add offline/service-worker
   behavior as part of this task.
3. Add generic sharing metadata visible to signed-out link preview fetches:

   - HTML title, `og:title`, and `og:site_name`: **Post 165 Members**
     (installation configuration; preserve useful authenticated browser titles).
   - Description: **Meeting agendas, minutes, and member resources for Post 165
     in Two Rivers. Member sign-in required.**
   - `og:type`: `website`.
   - `og:image`: absolute HTTPS URL of the static image on the configured members
     origin; `og:image:type`: `image/jpeg`; width 1200; height 630.
   - `og:image:alt`: **Post 165 Members — Two Rivers.**
   - `og:url`: stable, configured members entry URL with no query parameters or
     tokens. Never construct it from untrusted request Host input.
   - Matching `twitter:card=summary_large_image`, title, description, image, and
     image alt are reasonable compatibility additions.

   One generic preview is enough. Do not put person names, directory information,
   agenda/minutes content, private page titles, sign-in codes, session tokens,
   or token-bearing URLs into preview metadata. Preserve normal authentication;
   do not identify a crawler and grant it access. The static branded image is
   intentionally public; the records are not. Check all entry/error/token views
   for unsafe fallback titles or URLs rather than copying metadata blindly.
4. Retain HTML `noindex, nofollow`, and add consistent HTTP
   `X-Robots-Tag: noindex, nofollow` coverage for members pages and protected
   documents, including responses outside the normal HTML layout. Check the
   application and static-file/Active Storage delivery boundaries rather than
   assuming an ApplicationController callback covers everything. Keep these
   rules scoped to the members service; do not change the public site's indexing.
5. Keep crawler access to the generic signed-out entry page so search engines can
   read `noindex`. Do not replace the existing `Allow: /` with a blanket crawl
   block as an indexing fix. No private sitemap or public-site SEO schema needed.
6. Preserve the shared destination through sign-in. An ordinary member who opens
   an agenda link while signed out should return to that authorized agenda after
   email-code, magic-link, or passkey sign-in rather than land at the dashboard.
   Treat this as a deliberate authentication-flow change and use the project's
   design/testing guidance. Preserve existing mobile OAuth return behavior.

   Accept only validated local navigation destinations and recheck authorization
   at the destination. Do not accept external/protocol-relative URLs, replay POST
   requests, retain sign-in token URLs as destinations, or turn authentication
   endpoints into redirect loops. Choose an explicit supported route/path policy.
   The implementation should define safe behavior for browser/session changes
   during email sign-in instead of silently promising cross-device return.

## Findings from read-only source inspection on October 17

- The current `public/icon.svg` and `public/icon.png` are plain red circles.
- `application`, `entry`, and `print` layouts have `noindex, nofollow` already.
- `public/robots.txt` allows crawling specifically so crawlers can read noindex.
- Application and entry layouts default to `LegionPostTools` and have no OG tags.
- `require_authentication` redirects to sign-in without saving an ordinary member
  destination. `after_human_sign_in_path` preserves only the special mobile OAuth
  return, otherwise going to root. Passkey completion needs inspection too.
- Magic-link GET/HEAD renders confirmation; token consumption requires POST.
  Preserve that protection against link-preview fetches.
- Organization identity lives in the `Organization` model. Do not read real
  member data to implement or verify this work.

These are local-source observations, not a new audit of production. Recheck the
current code in the implementation session; concurrent work may change it.

## Proportionate verification

- Verify metadata, dimensions, MIME types, static asset access, and icon links on
  signed-out entry responses with synthetic test data. Verify absence of private
  record/person data and token/query leakage. Requests must stay unauthenticated.
- Test noindex headers on representative HTML, redirect, PDF/file, and error
  responses through the delivery paths the implementation actually covers.
- Verify ordinary shared-link return through supported email-code, magic-link,
  and passkey flows; test forbidden destinations, changed permissions, and the
  existing mobile OAuth flow. A preview GET must not consume a sign-in token.
- Review the actual 240/320 px card and 16/32 px favicons, plus entry rendering on
  desktop and phone. The supplied thumbnails are image QA, not proof of a real
  iMessage/other messaging client's preview behavior.
- Run relevant tests and required project checks once; use synthetic records.
  Never query, copy, reset, or use production-derived development member data.
- Deployment and live messaging-client validation remain separate steps requiring
  their usual authority; this package authorizes no commit, push, or deployment.

## References

- Current local `docs/STANDARD_MEMBER_EXPERIENCE.md` and
  `docs/superpowers/specs/2026-07-11-visual-design-system-design.md` establish the
  palette and system-sans style used here.
- [Google noindex documentation](https://developers.google.com/search/docs/crawling-indexing/block-indexing):
  crawlers must be able to read noindex; HTTP headers also cover non-HTML files.
- [Open Graph protocol](https://ogp.me/): metadata fields and image properties.
- [National's current brand guide, page 25](https://isu.pub/lKKNTyo): Noto Sans
  is one of its suggested website fonts; this M uses the Bold weight.

## Completed asset checks

The artwork was generated successfully and visually reviewed at actual 320 × 168
and 240 × 126 px thumbnail sizes. Favicons were visually reviewed at actual
16/32/48 px and enlarged to inspect the rasterization. ImageMagick confirmed
1200 × 630 JPEG/PNG exports, 16/32/48 px ICO frames, the 96 px PNG favicon,
180 px touch icon, and 192/512 px app icons.
The text in the shipped sharing SVG is outlined and has no external dependencies.
All icons and the OG artwork were regenerated from the same Noto Sans Bold M
outline. The bundled font's family and 700 weight were verified, its bytes were
compared with the public project's source font, and its copyright matches the
included upstream Noto Sans license notice.
Neither repository was changed by asset preparation. No application tests,
browser authentication checks, live preview-client checks, or deployment were
performed as part of this asset-only package.
