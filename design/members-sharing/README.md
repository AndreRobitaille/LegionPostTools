# Members artwork source

The approved October 17 package uses an outlined Noto Sans Bold M. The original
exports are retained here, along with the bundled font and SIL OFL notice. Labels
use Liberation Sans Regular/Bold. Runtime pages do not load these fonts.

The upstream package was verified against its SHA256SUMS before copying. The
local builder adds command-line output/text options; this directory's SHA256SUMS
covers the checked-in source and reference exports. The supplied HANDOFF.md is
historical design context, not additional authority.

Dependencies: Python with fontTools, fontconfig, Liberation Sans Regular/Bold,
rsvg-convert, and ImageMagick. No network or application database is used.

Regenerate the Post 165 package into a scratch directory:

```sh
python design/members-sharing/build.py --output /tmp/post-members-artwork
```

For the generic application fallback:

```sh
python design/members-sharing/build.py --output /tmp/post-members-generic --post-label POST --locality 'American Legion'
```

Copy the chosen JPEG to `public/members/post165/members-og.jpg` or
`public/members/members-og.jpg`. Install favicon.svg, favicon-96.png, favicon.ico,
and apple-touch-icon.png directly under public/. Keep icon.svg/icon.png aliases
in sync; app icons live in public/members/. The M is the same for every Post;
Post-specific text belongs in its own sharing image and installation configuration.
New labels must fit the existing layout; the builder rejects labels that overflow.
Review actual 240/320 px thumbnails and 16/32 px favicons after changes.
