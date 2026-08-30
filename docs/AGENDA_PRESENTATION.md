# Agenda Presentation and Navigation Design

## Purpose

Structured agendas, agenda sections, and Endeavors are working, but the member
experience still presents the published agenda as a functional preview and leaves the
working Meetings destination disabled in primary navigation. This milestone finishes the
agenda experience before the minutes lifecycle begins.

The concrete subject is the agenda carried into an American Legion meeting. Its audience
is a member who may be reading from a phone at the meeting or printing a copy beforehand.
The page has one job: make the meeting's order, timing, and business easy to understand.

## Product Boundary

In scope:

- Make Meetings a working primary-navigation destination for every signed-in member.
- Remove unavailable destinations from primary navigation instead of showing disabled
  promises among working controls.
- Give the upcoming-agendas index a clear, meeting-shaped presentation.
- Refine the published agenda into a member-facing document with a deliberate masthead,
  readable ordered sections, and a separate page-action area.
- Improve phone and print behavior without changing agenda data or lifecycle rules.
- Verify active navigation, authentication, keyboard focus, desktop layout, phone layout,
  and printed output.

Out of scope:

- Minutes, records/archive, PDF generation, email distribution, or public anonymous
  agendas.
- Changes to agenda editing, approval, publication, or authorization.
- New meeting-location fields or content that is not already part of the published agenda
  and its organization.
- Turning the member agenda into another editable working screen.

## Navigation

Primary navigation contains only real destinations:

- Dashboard
- Meetings
- Endeavors
- People
- Profile
- Admin, when the user has an administrative capability

Meetings links to the signed-in member list of upcoming published agendas and remains
active on both the list and an individual agenda. Records is omitted until a real records
workflow exists. At phone width the destinations retain the established two-column grid
and full-size tap targets. Visible keyboard focus is required on every link.

## Visual Direction

This design follows the installed `frontend-design` skill and the established “The 1919”
system. The agenda is a formal working handout, not yet an immutable official record, so it
uses document ivory and navy authority without borrowing the later sealed-bronze treatment.

### Tokens and type

- Authority navy `#0A2240`
- Working navy `#0D2C54`
- Legion gold `#C6A15B`
- Document ivory `#FCFAF1`
- Paper cream `#F4EEDD`
- Ink `#1B222B`

The app shell and page actions use the system sans stack. The agenda document uses Georgia
for its masthead and item copy, with sans-serif labels for meeting metadata and section
orientation. Body and controls remain at least 16px, secondary text at least 14px, and
labels at least 13px.

### Published-agenda index

The index is an upcoming-meeting docket rather than a generic settings list. Each agenda
row leads with a calendar-like date block, followed by the meeting title and body, with a
plain **Read agenda** affordance kept on the same row.

```text
+--------------------------------------------------------------+
| Meetings                                                     |
| Published agendas for upcoming post meetings                 |
+--------------------------------------------------------------+
|  28   AUG   Membership Meeting — 28 AUG 2026                 |
|             Membership · 19:00              Read agenda  >   |
+--------------------------------------------------------------+
```

The empty state says that no upcoming agendas have been published and explains that this
page will show them when they are available. It does not suggest an action ordinary
members cannot perform.

### Published agenda

Page actions sit outside the document. The document opens with a centered meeting standard:
organization, published-agenda label, title, meeting body, and date/time. A thin double rule
separates that identity from the order of business.

```text
  All meetings                                      Print agenda

  +----------------------------------------------------------+
  |                    ORGANIZATION NAME                     |
  |                    PUBLISHED AGENDA                      |
  |                                                          |
  |                    Meeting title                         |
  |              Meeting body · 28 AUG · 19:00               |
  |                ====== ◆ ======                           |
  |                                                          |
  |  [1]── Opening Ceremony                                  |
  |   │    Call to Order                                     |
  |   │    ...                                               |
  |  [2]── Roll Call, Minutes & Guests                       |
  +----------------------------------------------------------+
```

The signature element is the **order rail**: a gold vertical rule joining navy number
plaques for the actual ordered sections. It makes the meeting sequence visible without
decorating unrelated content. This replaces generic disconnected cards and gives the
agenda a structure specific to parliamentary meeting order.

On narrow screens, the masthead remains centered, actions become full-width controls, and
the rail tightens without reducing type. Long titles and rich text wrap inside the page;
the document never creates horizontal scrolling.

### Print

Print removes the application shell and page actions, removes screen-only shadows, uses a
white page. The original masthead and order-rail treatment has since been replaced by the
shared official meeting-document shell described in `docs/OFFICIAL_MEETING_DOCUMENTS.md`.
Section headings remain with their first item where practical. Individual short items avoid
page breaks, but an entire long section may flow across pages rather than creating large
blank spaces. Item summaries are drafting and screen-scanning aids, not agenda content, so
member, admin, and commander's printed copies omit them. Rich-text unordered and ordered
lists retain visible markers, indentation, and nested-list hierarchy on screen and in print.

## Design Critique

An early direction treated every section as a bordered card. That was rejected because it
looked like a general-purpose dashboard and weakened the sense of one ordered meeting. The
order rail is the one visual risk; the masthead, typography, and spacing stay quiet around
it. No animation is added because movement would not help someone follow or print an agenda.

## Accessibility and Safety

- All access remains authenticated and published-only.
- The full agenda row is a descriptive link, with no nested interactive controls.
- Current navigation uses both color and a border, plus `aria-current="page"`.
- Links and controls have visible focus styles and at least 48px phone targets.
- Heading order remains one page heading, followed by agenda section and item headings.
- Decorative diamonds, rules, and date blocks are hidden from assistive technology where
  they would duplicate nearby text.
- Rich text stays within the structured agenda items and is rendered as the published
  snapshot.
- Semantic unordered and ordered lists retain visible markers rather than inheriting the
  application shell's reset styles.

## Verification

Coverage should establish:

- Meetings is a real link and active throughout member agenda pages.
- No unavailable Records control is rendered.
- Only upcoming published agendas appear in the member docket.
- Organization, meeting body, date/time, ordered sections, active items, and print action
  render in the document.
- The print layout remains chrome-free.
- Browser QA covers the index and a content-rich published agenda at desktop and phone
  widths, including keyboard focus and horizontal-overflow checks.
