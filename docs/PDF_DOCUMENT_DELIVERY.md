# PDF Meeting Document Delivery

## Purpose

Agenda, Commander/Adjutant-notes, and minutes-preview actions must open a finished US Letter PDF
on every platform. A member or officer should never have to recognize an intermediate
print layout, find a browser print command, or understand how a phone turns a print
preview into a PDF.

The concrete document is the official-looking American Legion meeting handout already
defined in `docs/OFFICIAL_MEETING_DOCUMENTS.md`. This design changes delivery, not its
approved typography, hierarchy, margins, or content boundaries.

## User Experience

- **Open agenda PDF** returns the member-safe agenda as `application/pdf`.
- **Open minutes PDF** on the member minutes page prints the same member-visible
  attested or final approved revision as the web document. Working corrections stay
  officer-only. The signed rendering token fixes the member revision; the loopback
  source rejects a token whose revision is no longer member-visible. Its layout and
  record details reuse the member document described in `MEMBER_MEETING_DOCUMENTS.md`.
- **Cmdr Notes PDF** returns the same document shell with private
  Commander cues and roll call. It is available only when the signed-in person currently
  holds a configured Commander or Adjutant assignment; `manage_agendas` alone is not enough.
- The minutes workspace offers **Open draft PDF**, **Open attested PDF**, or
  **Open official PDF** according to lifecycle state. A draft is an officer-only proof from mutable working
  rows, including Adjutant edits after Commander handoff. Attested and official PDFs
  render the immutable attested revision with the corresponding meeting-approval label.
- The response uses `Content-Disposition: inline` and a descriptive `.pdf` filename. A
  desktop or mobile browser may display its native PDF viewer, from which the document can
  be printed, downloaded, or shared.
- There is no responsive HTML page between the action and the PDF. The narrow HTML
  presentation remains useful only for reading a published agenda in the application.
- A generation failure returns the user to the relevant agenda or minutes record with plain
  guidance to try again; no partially generated file is sent.

## Saved document titles

Creating a dated agenda copies the template's sections, items, wording, and document
controls into meeting-owned records. Starting minutes copies the dated agenda into
independent minutes records. Source IDs identify where a copy originated; editing the
catalog or template must never update either document's saved content.

Document headings and PDF filenames use the saved agenda or minutes title, rather than
the current meeting-type name or slug. Attested and official minutes use the title in
the immutable revision selected for that document. This also applies when a template is
renamed after the document was created. Existing saved titles remain authoritative;
do not rewrite historical records or infer an earlier template name from today's name.

Visual direction: retain The 1919 letterhead, serif document heading, navy/gold rules,
status labels, date line, and existing desktop/narrow layouts. Display the saved title
in the existing heading so longer meeting-specific titles wrap naturally. Verify
desktop and 390px agendas/minutes after a template rename, and cover member and officer
PDF variants with regression checks.

## Rendering Architecture

The application uses headless Chromium because the approved document was designed and
verified with Chromium's paged-media implementation, including Letter sizing and running
`@page` footer boxes.

1. The authenticated member or agenda manager requests a PDF action.
2. The application confirms the existing agenda and document-specific permission scope.
3. It creates a short-lived signed rendering token containing only the organization,
   exact document ID, and allowed document kind or variant.
4. A Chromium process inside the application container requests a loopback-only HTML
   source using that token.
5. Chromium prints the source with background graphics and CSS page sizing, and the
   controller returns the resulting bytes inline as a PDF.

Chromium is an application runtime dependency in the production image. Generation is
bounded by a timeout, uses an argument array rather than a shell command, and always removes
temporary files.

## Security Boundary

- The user-facing member action retains the existing published-only lookup.
- The administrative member agenda action retains `manage_agendas`.
- The private notes action additionally requires current position-provided Commander
  approval or Adjutant attestation authority. This follows the dated assignment and does
  not infer authority from a position's display name.
- The officer minutes route permits `manage_minutes`, `approve_minutes`, `attest_minutes`,
  or `view_internal_records`. Member access remains limited to attested or later records
  through the authenticated member HTML and PDF routes, including the last attested
  copy while corrections are prepared. A member PDF never uses mutable working rows.
- The HTML rendering source accepts only loopback requests and a valid expiring signature.
- Rendering tokens are filtered from logs, expire after one minute, and cannot select a
  different organization, agenda, or document variant.
- The member PDF never renders Commander cues or roll-call working fields.
- The minutes PDF never renders transcript text, AI suggestions, confidence,
  evidence ranges, job provenance, or application controls.
- Responses use `Cache-Control: no-store` because private notes documents can contain
  meeting instructions.
- User content is rendered through the existing sanitized Action Text output. Chromium
  receives no arbitrary command-line values derived from agenda content.

## Failure and Capacity

PDF generation is infrequent and initiated by an authenticated person, so one short-lived
Chromium process per request is appropriate for the first installation. The renderer has a
fixed timeout and returns a controlled failure instead of tying up a web worker indefinitely.
If usage later becomes frequent, the same service boundary can move generation to Solid
Queue and stored attachments without changing the document templates or controller policy.

## Pagination

- Section headings stay with at least the first agenda item beneath them.
- An item title stays with its own printed wording, Commander cue, or roll-call worksheet.
- A title-only item remains an independent break point. It must not be joined to the next
  item merely because its heading is the item's final element; otherwise a sequence of
  short procedural items can become one unbreakable block and leave excessive blank space.
- Roll-call rows stay intact, while the table and ordinary agenda sections may continue on
  the following page when necessary.

## Verification

- Request tests assert authentication, permission, PDF content type, inline disposition,
  filename, and member/officer variant selection.
- Source tests assert loopback-only access, signed-token validation, and content separation.
- Browser/system coverage exercises real Chromium generation for both variants.
- PDF inspection confirms `%PDF`, US Letter dimensions, repeating address/email/page-number
  footers, and absence of officer-only content from the member PDF.
- The container build confirms Chromium is present in the production runtime.

## Resource policy for generated PDFs

The signed HTML sources share a deny-by-default Content Security Policy. Only the
fingerprinted application emblem and the five print stylesheet assets may load; arbitrary
same-origin URLs, remote URLs, scripts, frames, connections, fonts and media are blocked.
The existing footer style element receives a fresh nonce. Sanitized inline text formatting
remains allowed; any CSS image requests still obey the image allowlist. Allowed assets are
static, nonredirecting files. No broad host or asset-directory source is permitted.
The allowlist uses the renderer's HTTP loopback host and port, including when production
`assume_ssl` makes Rails treat the source request as HTTPS behind its public proxy.

This policy is enforced by Chromium before loading document subresources. Print presentation
also replaces embedded images/media with an explicit text marker, retaining an image's alt
text when available. Source records and immutable revision payloads are never changed.
The normal member reading view remains unchanged.

Visual direction: retain The 1919 official-document shell, navy/gold letterhead, emblem,
Georgia narrative, system-sans labels, Letter pagination and authority folio. An omitted
image is indicated inline as “Image omitted from PDF: description” (or “Image omitted from
PDF” without alt text), using readable secondary text, not a broken-image icon or a large
warning panel. Verify desktop and 390px source layouts and real generated Letter PDFs.

## Calendar handout delivery

The calendar's Print PDF action reuses `BrowserPdfRenderer` and `PdfResourcePolicy`.
Authenticated members receive a private, no-store inline PDF containing the landscape
Letter month overview followed by the portrait Letter detailed schedule, with a
quarter-inch inset on every page. The source token binds the organization, month,
calendar view and event-type selection; unsigned query parameters cannot change them.
The loopback source uses the same member-readable calendar templates without a session
or JavaScript. Public preview retains its restricted event projection. Calendar PDFs
do not include Endeavor narrative, officer notes, agendas, or minutes.

This fixes page dimensions before the PDF reaches the user's browser, avoiding mixed
orientation and margin overrides in HTML print dialogs. The screen view and selected
filters remain intact. See `CALENDAR.md` for the low-ink handout design and pagination.
