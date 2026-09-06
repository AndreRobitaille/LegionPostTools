# Calendar readability and entry refinements

Design and implementation, 6 September 2026.

## Member tasks

The calendar is an attendance and participation surface. Meetings and public events
are visible together by default; membership does not imply attendance at every event.
Officer/PEC meetings remain visible and open to members. Volunteer opportunities appear
alongside other activities without implying that an online signup system exists.

- General member: find the next meeting, discover an event, and open its details to learn
  when/where to attend. There are no calendar editing controls for ordinary members.
- Honor Guard member: use the visible event-type checkboxes to focus on Honor Guard,
  retain the selection across months, and open an assignment's details.
- Officer: browse the same calendar and use compact Add event / Schedule meeting actions.
  Edit in the event/meeting context. Planning due dates and public preview are secondary
  officer utilities; the ordinary calendar has no Show dropdown.

## Visual direction

Use familiar calendar conventions within The 1919 shell: compact Today/chevron month
navigation, visible color-coded checkboxes, Sunday–Saturday weeks, and tinted event blocks
containing the event name and time. The whole block is clickable. Category names belong
in the legend rather than being repeated above every event. Long month-grid names use up to three
lines with the full name available through hover, accessible naming, and event details.
Desktop users choose Month or Schedule rather than seeing duplicate presentations. Phones
use the readable schedule with visible filters and adequate tap targets.

Member meetings use red (#F3CCD0 / #811B2B) and officer meetings a lighter red
(#F8E1E2 / #943C43). Honor Guard is subdued gray (#E7E8E8 / #53585D), planning
meetings blue (#DDE8F6 / #173E69), public events green (#DBEDDF / #285E3A), other
activities warm neutral (#F0ECE3 / #655C48), and deadlines neutral. Preserve the brand
navy shell and sans-serif working typography.
Event names and controls are at least 16px; secondary metadata is 14px, date labels 13px.
Checkbox state and text accompany color; cancellation remains explicit. Keep keyboard
focus, reduced-motion behavior, and a printable schedule. Event details repeat the same
color treatment, with grouped date/place/description and one authorized edit action.

## Behavior and boundaries

One category per event/meeting; readers can select multiple types or none. Categories
are visible and filtering is immediate on already-authorized DOM entries. Selection is
reflected in the URL and month links; a no-JavaScript form submission remains available.
Server rendering supplies the same initial selection. API filtering still returns only
selected entries; the public projection excludes private rows and private fields.

A nullable calendar_category override is editable by existing event/meeting managers.
Without an override, conservative title/body/type keywords supply the category, including
PEC and Honor Guard. Unmatched public records are Public events; unmatched private records are Other activities (API value `other`). No AI
classifies events. Deadlines have their own fixed category and require the planning view.
The existing API `view` values remain supported; no public synchronization is introduced.

New default Meeting/DatedAgenda names omit dates. Calendar and member meeting presentation
omit a trailing house-format date only when it matches the scheduled date. Existing official
stored headings remain intact. API calendar entries provide display_title alongside title.

Shared time entry accepts 8, 8:00, 800, 0800, 19:30, 1930, and explicit AM/PM. Bare times
remain 24-hour (8 means 08:00). Normalize on blur and validate again on the server. API
writes retain their existing datetime requirements, including explicit event offsets.

## Verification

The additive category migration is applied locally to development and test. Existing
meeting/agenda titles have not been rewritten, and no paid AI generation was used.
Desktop and 390px phone screenshots were reviewed for member, Honor Guard, and officer
workflows. Browser tests cover instant filtering, retained selection, month/schedule modes,
keyboard focus, public/management boundaries, print, mobile overflow, and shorthand time
entry through a successful save. Full suite and focused checks are recorded below.

Final validation: 926 Rails tests / 6,015 assertions and 26 sequential browser tests /
206 assertions passed with zero failures, errors, or skips. Focused Ruby lint, JavaScript
syntax checking, Brakeman (zero warnings/errors), and diff whitespace checks passed.
Visual review covered desktop and 390px phone layouts, including the default Month route
on a phone and printing directly from Month mode. A CSS specificity issue that initially
hid those schedules was corrected and covered by the browser checks. All work remains
local; this redesign has not been committed or deployed.

## Final member feedback: time, hierarchy, and categories

Remove the redundant Calendar heading/tagline; begin with month navigation and keep
management actions compact. Suppress date-only metadata inside month event blocks.
Member meetings use stronger red, officer meetings a softer red, Honor Guard neutral
gray, planning meetings blue, and public events green. This requested meeting emphasis
is a calendar-specific exception to the usual red-for-decisions visual rule.

Calendar display, grouping, HTML time entry, and calendar API requests use the Post's
saved timezone, falling back to the application zone only for legacy invalid/missing
settings. Production config already specifies America/Chicago. No stored timestamps
are rewritten. Verify summer/winter offsets and local-midnight grouping.

Replace the volunteer category with actual planning meetings; volunteer shifts are not
inferred to be meetings. Public events derive from existing public visibility, without
changing publication settings. Keep Other activities for unclassified private records.
Existing explicit volunteer overrides fall back to name/visibility classification;
legacy public category overrides cannot make a private event public.

Volunteer participation cuts across planning meetings and public events; it is not a
calendar type. Honor Guard is an established volunteer group, not an open call for
members. Category labels must not invent invitations or volunteer opportunities.

Validation after the category/timezone refinements: 929 Rails tests / 6,041 assertions;
26 browser tests / 212 assertions; no failures or errors. Desktop and 390px screenshots
confirm the red meeting blocks, subdued Honor Guard, visible filters, removed header,
and date-only month blocks without metadata. Focused lint passes on 11 files; Brakeman
reports no warnings. Central-time summer/winter entry, near-midnight grouping, and local
due dates are covered with an intentionally UTC application test context.

## Event detail refinement

Use a bounded, lightly outlined paper card on the tan application background. A strong
category-colored top rule and compact type label provide identity without relying on a
low-contrast pastel panel. Keep the title navy and the main surface #FFFDF7; use navy
#0A2240, muted slate #536477, border #C8C1B2, and the established category ink/fill pair.
System sans remains the working typeface, with tracked 13px type labels, a 30px title,
18px facts/body, and 14px timezone notes. No document serif or oversized hero.

Layout: type/visibility → title → When and Where → description → related Endeavor →
authorized Edit action. On phones the facts stack. The signature is the category rule
paired with its explicit type label; it stays legible even for neutral Other activities.
Date-only events show no timezone. Timed events place the timezone immediately under
the time as a quiet footnote. Keep cancellation prominent and public-preview boundaries
unchanged. Review both neutral and colored categories at desktop and 390px.

Detail-page validation: 15 controller tests / 161 assertions and 3 browser tests /
52 assertions pass. Reviewed neutral desktop/mobile, Honor Guard mobile, and date-only
public event screenshots. No horizontal overflow at 390px; event type is above the title,
timezone is absent for date-only events, and member pages have no edit action. Focused
Ruby lint and diff whitespace checks pass.

## Mobile schedule refinement — September 6, 2026

Use the dashboard's event cues for the calendar schedule: paper cards, a category-colored
edge, category icon/label, separate clock and location lines, and an explicit Details
action. Retain existing category colors (#DBEDDF/#285E3A public, #DDE8F6/#173E69 planning,
and the existing meeting/Honor Guard palette), navy headings and system sans type.
Titles stay 18px on phones; metadata is 14px and actions 16px. Color is reinforced by
category text and icons. Avoid full-card pastel fills and inline separator dots.

On phones each date becomes a horizontal heading above its group, giving all events the
full available width. Keep one date heading for multiple events that day. Desktop schedule
retains its date column; the month grid, filters, category visibility, cancellation,
public preview and management permissions keep their existing behavior. Reuse shared
activity icons with the dashboard. Verify 390px and 320px, long titles/locations, multiple
events on a day, filtering, details navigation, keyboard focus, desktop schedule and print.
