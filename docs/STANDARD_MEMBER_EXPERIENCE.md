# Standard Member Experience

**Status:** Accepted for implementation on September 1, 2026.

## Product job

The subject is an American Legion Post's current meeting life. The primary reader is a
member who may visit infrequently and may have low confidence with websites. The member
experience should answer two questions without requiring the reader to understand the
application's record structure:

1. When is the next meeting, and is its agenda ready?
2. What happened at the most recent meeting, and are its minutes ready?

Meeting records remain the first-class workflow. Endeavors and the directory are useful
supporting references, while passkeys and agent access must not compete with current Post
business.

## Visual direction

Keep the established "The 1919" system rather than introducing a new dashboard style:

- **Authority navy `#0A2240`:** headings, active navigation, and available document actions.
- **Service gold `#C6A15B`:** date plates, section rules, and visible focus.
- **Cream field `#F4EEDD`:** application background.
- **Paper `#FBF7EC`:** meeting records and quiet account guidance.
- **Ink `#1B222B` and slate `#6B7684`:** readable content and secondary explanation.
- **Type:** the existing system face for application text; Georgia remains reserved for
  official agenda and minutes documents.

The signature element is the meeting docket: real Post dates in the existing date plate,
paired with one direct document action. Restraint matters more than decoration.

```text
POST MEETINGS

+-------------------------------------------+  +-----------------------+
| NEXT MEETING                              |  | SIGN IN FASTER        |
| [date] Membership Meeting                 |  | Optional passkey      |
|        time and place       [View agenda] |  | [Set up] [Not now]   |
+-------------------------------------------+  +-----------------------+

+-------------------------------------------+
| MOST RECENT MEETING                       |
| [date] Membership Meeting  [View minutes] |
|        Awaiting member acceptance         |
+-------------------------------------------+
```

At 390px the security rail moves after the meeting docket. No horizontal scrolling,
clipped focus, or sub-16-pixel interactive text is acceptable.

## Dashboard

- Replace the generic organization introduction and Meetings tile with the next and most
  recent Meeting records.
- Link directly to the best member-visible document.
- Keep the passkey invitation optional, brief, and visually subordinate in a desktop
  sidebar. On phones it follows meeting information.
- Keep login-email review prominent when it genuinely requires the member's attention.

## Meeting document actions

The date plate owns the date. A default generated title omits its repeated date in member
lists, and the meeting body/type is not repeated as metadata.

| Meeting state | Action | Supporting message |
| --- | --- | --- |
| Upcoming with published agenda | **View agenda** | None |
| Upcoming without published agenda | **Agenda not published yet** | Noninteractive |
| Past with attested minutes | **View minutes** | Awaiting member acceptance |
| Past with agenda but no attested minutes | **View agenda** | Minutes not available yet |
| Past without member-visible documents | **No documents available** | Noninteractive |

Upcoming records retain time and place. Past list rows omit time and place. The Meeting
detail route remains available for record context and deep links, but the member index and
dashboard do not make "View meeting" the primary action.

Attested minutes are member-visible but are not accepted, final, or official. Accepted
minutes become official only after the separately recorded membership act.

## Minutes PDF authority

- Draft PDFs say **Draft - not approved** in the heading, running footer, filename, and
  authority folio.
- Approved PDFs say **Approved - awaiting attestation** and remain officer-only.
- Attested PDFs say **Attested - awaiting acceptance**, name the approval and attestation,
  and never call the record official.
- Accepted PDFs say **Official minutes** only when that lifecycle state exists.
- Every non-draft PDF renders the immutable approved revision, not mutable working rows.

## Endeavors

- Standard members see an Endeavor's title, public summary, completion state, and history.
  Agenda-planning language such as "Raise by," "Due in," and "Overdue" is restricted to
  users who manage agendas.
- Completed Endeavors show their completion date and never retain overdue language.
- A timeline appearance links to attested minutes once available; otherwise it links to
  the published agenda.
- Actions use **View details** rather than the ambiguous **Open**.

## Directory and profile

- Constrain the standard directory to a readable desktop measure. Its search control is
  compact on desktop and full width on phones.
- Every directory row has a visible **View details** cue while retaining a generous click
  target.
- Translate National roster service codes into ordinary labels and suppress missing-data
  sentinels.
- Put **View your directory listing** beside the Profile identity instead of leaving a
  loose link after the page content.
- Keep personal Agent access available; it is an existing self-service capability whose
  token is limited to the member's own current app permissions.

## Verification

- Controller/model/helper tests cover every meeting action state, immutable revision PDF
  rendering, Endeavor link promotion, completed-date wording, directory labels, and the
  Profile cross-link placement.
- Render and inspect the attested Meeting 1 PDF, including every page footer and the final
  authority folio.
- Browser-check the member Dashboard, Meetings, Endeavors, People, and Profile pages at
  desktop and 390px, including keyboard focus and horizontal overflow.
