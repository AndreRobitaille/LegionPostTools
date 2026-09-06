# Dashboard activities

## Purpose and selection

Keep the next member meeting and most recent member meeting as the primary dashboard
content, including their existing member-visible agenda and minutes actions. Select
those records using the calendar's member-meeting classification so officer meetings
cannot replace them.

Below both meeting cards and Browse all meetings, show Coming up at the Post: the next
three eligible activities from Meetings and CalendarEvents, in chronological order.
Use the organization's calendar time zone and include today's activities and ongoing
multi-day events. There is no arbitrary month or 30-day cutoff. Exclude Honor Guard,
officer/PEC meetings, and member meetings using the existing calendar categories.
Public events, planning meetings, and other activities qualify automatically. Exclude
cancelled events here; their cancellation notices remain on the full calendar.

No new management fields, volunteer labels, signup workflow, or inferred invitations.
Hide the section when empty. Always include View full calendar when the section appears.

## Visual direction

Preserve The 1919 system: navy #0A2240, gold #C6A15B, cream #F4EEDD,
paper #FBF7EC, and ink #1B222B. Use existing system sans for working UI;
serif remains reserved for documents. Reuse the shared diamond/rule section heading.
The member meeting cards retain first position and their primary document buttons.
Activities now use compact event cards with a colored date panel, a category icon and
label, clock/location icons, and a distinct Details arrow. Reuse the calendar's green
(#DBEDDF / #285E3A) for public events, blue (#DDE8F6 / #173E69) for planning meetings,
and stone (#F0ECE3 / #655C48) for other activities. Color, icon, and text reinforce the
same meaning; none relies on color alone. The date panel is the signature visual cue.

Use 18px event titles, 16px actions, and 14px secondary text. Put weekday in the date
panel and omit the year for current-year events to reduce repeated text. Keep dates
machine readable and show the year for future-year events. Each whole card is a single
link with visible focus. On phones the Details action sits under the copy; the colored
date panel stays beside it. Keep generous spacing, bounded widths, and the established
900px/560px breakpoints. No new management inputs or invented volunteer invitations.

## Verification

Cover member-meeting selection, category exclusions across both record types, ordering,
three-item limit, past/cancelled exclusion, ongoing events, organization/time-zone
boundaries, and empty state. Browser-check desktop and 390px, document prominence,
keyboard focus, event navigation, and overflow using synthetic test records.
