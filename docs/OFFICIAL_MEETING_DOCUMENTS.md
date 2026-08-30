# Official Meeting Document Design

## Purpose

The concrete subject is the paper agenda carried into an American Legion meeting and the
minutes retained after that meeting. The primary audience is a Post member who may be older,
may read the document under ordinary meeting-room lighting, and may print it on a home or
office printer. The document has one job: establish what meeting this is and make its ordered
business easy to follow without competing with the content.

This design follows the installed `frontend-design` skill. It extends the established “The
1919” identity into a quieter official-document system rather than printing the screen card.

## Product Boundary

This milestone:

- creates one shared agenda document shell for member, administrative, and Commander's
  copies;
- explicitly targets US Letter portrait (`8.5in × 11in`) with a white background;
- respects the common non-printable boundary of `0.5in` at the top and `0.25in` on the other
  edges;
- uses the existing official American Legion emblem and configurable organization identity;
- establishes the visual shell future draft and accepted minutes will reuse; and
- preserves the existing member/Commander content boundary and agenda lifecycle.

This milestone does not create minutes, signatures, acceptance, or PDF storage. The shared
shell is rendered to a real PDF by the delivery service described in
`docs/PDF_DOCUMENT_DELIVERY.md`. Future minutes must reuse this shell while keeping accepted
minutes immutable.

## Visual Direction

### Tokens

- Authority navy `#0A2240`
- Legion gold `#C6A15B`
- Gold ink `#7A5F22`
- Officer blue `#2F5F87`
- Document ink `#171B22`
- Paper white `#FFFFFF`

Georgia remains the restrained document face for the meeting title and readable item copy.
The application system sans is used for institutional identity, date and time, and lifecycle
status. Print body copy targets `10pt`; the title is `15.5pt`, large enough to establish the
document without turning it into a web-page hero.

### Layout

```text
+------------------------------------------------------------------+
| [EMBLEM] Organization name                   MEETING LOCATION    |
|          Locality                      Location name and address  |
| =================================================================|
|                  Membership Meeting — Agenda                     |
|                       07 JUL 2026 · 19:00                         |
| -----------------------------------------------------------------|
|  I.  Opening Ceremony                                            |
|       A. Call to order                                          |
|     Meeting wording...                                          |
|                                                                  |
| II.  Roll Call, Minutes & Guests                                 |
|     Roll call                                                    |
+------------------------------------------------------------------+
| P.O. Box 11         public-email@example.org           Page 1    |
| City, ST ZIP                                                    |
+------------------------------------------------------------------+
```

The first-page letterhead follows the selected traditional letterhead direction. The emblem
and organization identity align on the left; the configured meeting location occupies the
upper right. A paired navy/gold rule is the only ornamental gesture.

The title combines the configurable meeting type and document kind, such as `Membership
Meeting — Agenda`. Date and time sit immediately beneath it. The location comes from the
meeting body's configured default, falling back to the installation's Post-wide default; it
is not copied into each dated agenda.

The ordered section gutter remains because order is meaningful in a parliamentary meeting,
but it loses the screen version's octagonal plaques, continuous decorative rail, all-caps
headings, and ornamental section rules. Restrained Roman numerals identify sections;
indented capital letters identify agenda items; supporting lists sit one level farther in.
That hierarchy makes parliamentary order visible without recreating the supplied template.

## Agenda and Minutes Family

The shell identifies a document by type and status rather than changing its visual language:

- **Agenda** — ordered business distributed before the meeting.
- **Commander's working copy** — the same agenda plus private blue officer cues and roll call.
- **Draft minutes** — the same meeting identity and section order, clearly marked draft.
- **Accepted minutes** — the same shell, marked accepted with later acceptance and attestation
  information. Accepted minutes are immutable; corrections belong to later records.

Agenda wording and future minutes wording remain separately controlled. Private Commander
cues never enter member agendas or minutes.

## Print Rules

- `@page` explicitly sets `size: Letter portrait`.
- The physical page and document surface are forced to white even when browser background
  graphics are enabled.
- The page boundary is at least `0.5in` top and `0.25in` elsewhere. The bottom margin expands
  to `0.45in` to hold the selected ruled footer safely.
- Section headings stay with following content. Long agenda items may split across pages;
  preventing every item from splitting creates large blank areas and is not acceptable.
- Roll-call rows and other short tabular records remain intact.
- Color is restrained and remains legible in grayscale. No meaning depends on gold or blue.
- The on-screen document closes with the configured mailing address, public email, document
  type, and meeting date. Browser print replaces that row with a running ruled footer: the
  two-line mailing address on the left, public email in the center, and `Page N` on the right.

## Narrow-Screen Rules

The same semantic document remains readable before printing. Below `560px`, the letterhead
becomes a two-column emblem/identity row with compact status beneath the identity, the title
shrinks modestly, and the ordered gutter tightens. Type remains readable and no horizontal
overflow is allowed at `390px`.

## Design Critique

The prior print treatment retained the screen document's ivory surface, centered decorative
masthead, diamonds, clipped number plaques, and vertical rail. Those choices help the screen
agenda feel like a designed destination, but they make a multi-page printout feel ornamental
and consume space needed by ceremonial wording.

A numbered rail and all-caps ruled headings were considered, but together they still read as
a web interface adapted to paper. The approved direction uses Roman numerals only as a quiet
outline aid; it does not reproduce the supplied template's spacing or page composition.

A dense newspaper layout was also rejected. Minutes and agendas are sequential records, not
editorial pages; multiple columns would make motions, reports, and long ceremonial text harder
to follow.

## Verification

- Request coverage asserts the emblem, meeting-type/document title, date and time, and shared
  member/admin/Commander shell.
- Browser critique covers the member document at desktop and `390px`, plus the Commander's
  copy where private fields differ.
- Generated PDF inspection confirms US Letter page dimensions, white paper, repeating page
  numbers and organization footer, safe geometry, readable page breaks, and no private-content
  leakage.
