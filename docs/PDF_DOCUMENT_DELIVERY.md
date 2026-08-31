# PDF Meeting Document Delivery

## Purpose

Agenda, officer-document, and minutes-preview actions must open a finished US Letter PDF
on every platform. A member or officer should never have to recognize an intermediate
print layout, find a browser print command, or understand how a phone turns a print
preview into a PDF.

The concrete document is the official-looking American Legion meeting handout already
defined in `docs/OFFICIAL_MEETING_DOCUMENTS.md`. This design changes delivery, not its
approved typography, hierarchy, margins, or content boundaries.

## User Experience

- **Open agenda PDF** returns the member-safe agenda as `application/pdf`.
- **Open officer-notes PDF** returns the same document shell with private Commander cues
  and roll call, and remains restricted to users with `manage_agendas`.
- **Open draft PDF** on an editable minutes workspace returns a current officer-only
  proof clearly marked **DRAFT - NOT APPROVED**. It is not a minutes publication action
  and does not create an immutable revision.
- The response uses `Content-Disposition: inline` and a descriptive `.pdf` filename. A
  desktop or mobile browser may display its native PDF viewer, from which the document can
  be printed, downloaded, or shared.
- There is no responsive HTML page between the action and the PDF. The narrow HTML
  presentation remains useful only for reading a published agenda in the application.
- A generation failure returns the user to the agenda with plain guidance to try again;
  no partially generated file is sent.

## Rendering Architecture

The application uses headless Chromium because the approved document was designed and
verified with Chromium's paged-media implementation, including Letter sizing and running
`@page` footer boxes.

1. The authenticated member or agenda manager requests a PDF action.
2. The application confirms the existing agenda and permission scope.
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
- The administrative member agenda and officer-notes actions retain `manage_agendas`.
- The mutable minutes preview retains the minutes workspace's `manage_minutes` or
  `view_internal_records` boundary and is never exposed through a member route.
- The HTML rendering source accepts only loopback requests and a valid expiring signature.
- Rendering tokens are filtered from logs, expire after one minute, and cannot select a
  different organization, agenda, or document variant.
- The member PDF never renders Commander cues or roll-call working fields.
- The draft minutes PDF never renders transcript text, AI suggestions, confidence,
  evidence ranges, job provenance, or application controls.
- Responses use `Cache-Control: no-store` because officer documents can contain private
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
