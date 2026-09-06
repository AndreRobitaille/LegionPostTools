# Endeavor next steps and scheduled activities

Design and implementation scope, 6 September 2026.

An Endeavor is the continuing project. Its meeting history remains intact and separate
from its current next steps and scheduled activities. No task creates an agenda item,
meeting record, or public event automatically.

## Small, functional scope

- Replace “Raise by” in the working UI with “Overall due date (optional)”. Preserve existing
  stored dates exactly; use `due_on` as the application name and retain `raise_by_on` as a
  storage/API compatibility alias. Never infer event times from a legacy deadline.
- A next step has a title, optional due date, and open/done state. Officers with the existing
  Endeavor editing permission can add, edit, complete, and reopen it. Record creator,
  last editor, completion actor/time, and optimistic lock. Members can read next steps.
  No assignees, dependencies, boards, recurrence, notifications, or task deletion.
- Scheduled activities reuse CalendarEvent: multiple planning meetings, volunteer shifts,
  and public events can link to one Endeavor. Keep the existing calendar management policy.
  Show dates, start/end times, location, visibility, and cancellation beside edit actions.
  Past events remain accessible in a collapsed section; completing an Endeavor does not
  erase or cancel its events or complete its tasks.
- Next steps and scheduled activities appear before meeting history on the Endeavor page.
  An optional project deadline appears with the project heading. Summary becomes “Summary”
  rather than a second unstructured task list. Keep existing summary text unchanged.
- Member Calendar defaults to meetings/events. “Include due dates” adds open task deadlines
  and active project deadlines as explicitly labeled due dates, not attendance events.
  Undated/completed tasks and completed project deadlines do not appear.
- Signed-in calendar offers “Public events preview”. Only explicitly public CalendarEvents
  appear, with their own description/time/location/cancellation. The preview links to a
  public-details-only event view. Never show parent title, private links, tasks, official
  meetings, or internal metadata in that preview. A public projection provides the same
  allowlisted fields for later synchronization, scoped by organization and bounded month.
  No unauthenticated API, website sync, or caching is activated in this change. The follow-up
  private API parity contract is in `CALENDAR_API.md`.

## Visual direction

Follow The 1919: navy #0A2240, gold #C6A15B, cream #F4EEDD, paper #FBF7EC,
ink #1b222b. System sans for working headings/body; restrained tracked labels. Keep the
existing bounded record-and-rail layout. The main signature is two clearly titled activity
sections with gold rules: “Next steps” and “Scheduled activities”, each a readable list
with adjacent actions. Completed tasks and past events collapse below active rows.
On narrow screens actions wrap below their own item. Body/actions at least 16px,
secondary text 14px, labels 13px. Avoid a dashboard tile grid or a project-management board.

## Verification

Test member reads and mutation denial, officer access, cross-Endeavor scoping, invalid
and missing dates, task completion/reopening provenance, stale edits, legacy due-date
compatibility, calendar deadline filtering, and public-preview/serialization isolation.
Verify desktop and 390px activity/forms/calendar flows with synthetic test data, keyboard
focus and overflow. Preserve all pre-existing worktree changes. No paid AI generation.

Local verification completed: full Rails suite (904 tests, 5,784 assertions), final focused
suite after the compatibility test and date-parsing refinement (66 tests, 428 assertions),
and system suite (24 tests, 169 assertions) passed. Focused RuboCop, Tailwind build,
Brakeman (zero warnings), and dependency audit passed. Synthetic browser checks covered
desktop/390px layouts, task creation/completion/reopening, visible keyboard focus,
calendar deadlines, and public-preview isolation without horizontal overflow. The system
suite was rerun alone after an overlapping test run caused a database lock conflict.
At initial local verification, the additive migration was applied locally. The subsequent
`f22eec3` release applied it to production; public synchronization remains inactive.

## Calendar population for the September 6 release

The production inventory contains three existing Meeting records, two sets of minutes,
with six Endeavors and no standalone CalendarEvents. An additive, transaction-checked
seed added 18 calendar entries, including historical events: six explicitly public
community events and twelve member logistics/other entries. Five entries link to the
existing Car & Bike Show, Ethnic Fest, and SnowFest Endeavors. Existing Meeting entries
are not duplicated. Creator/editor attribution uses the authorized calendar manager.

Sources are July 7 minutes items 16, 19, 22–26, 29 and September 1 minutes items 44, 46,
50, 56, 60–62, 69, including their preserved agenda text. September's explicit Saturday,
September 5 Car & Bike Show date supersedes the July agenda's inconsistent July 5 label.
The SnowFest entry reflects the later correction about who carried the colors. The
October 25 drawing date and November banquet details come from preserved agenda text.

Unrecorded end times remain blank. Dates with no recorded time use the existing all-day
storage flag and the clearer “Date only” display; descriptions explicitly say the time
was not recorded. This wording follows the existing The 1919 form and schedule layout.
Approximate meeting times remain labeled approximate. No event date is inferred from an
Endeavor deadline, and undated planning meetings, National Night Out, or nonspecific
military-honors references are not assigned invented dates. Home addresses and volunteer
arrival/shift details remain member-only. No new tasks or official records are inferred.

The seed validates current source text, refuses to overwrite differing existing events,
and compares counts plus complete-row SHA-256 fingerprints for thirteen protected
meeting, minutes, agenda, Endeavor, and rich-text tables before/after. A dry run inserted all
18 valid events and rolled back. Production application then added eighteen entries; the
repeat accepted identical existing events without duplication. All 606 protected rows
remained unchanged. The private seed manifest and detailed evidence stay outside Git.
