# Calendar design

Status: calendar and Endeavor activity UI released 6 September 2026 at `f22eec3`.
The follow-up private API release is documented in `CALENDAR_API.md`.

## Purpose and first release

Members need one top-level Calendar destination to find upcoming Post meetings and
activities. The calendar combines existing Meetings with new CalendarEvents. A CalendarEvent
can stand alone or belong to an Endeavor. An Endeavor can have several events and next
steps. Its optional overall due date is a project deadline, not an event date. The old
`raise_by_on` storage/API name is retained as an alias for `due_on`. See
`ENDEAVOR_ACTIVITIES.md` for the current task, deadline, and activity design.

Meetings retain their existing source of truth and editing safeguards. Calendar management
links to the existing meeting editor, so rescheduling cannot bypass published-agenda locks
or change official documents. Events are edited from a central management page and can also
be added from an Endeavor page. Completing an Endeavor does not cancel its events.

Each event has a title, plain-text description, start, optional end, all-day flag, location,
visibility (Members only by default, or Public), optional Endeavor, creator, last editor,
optimistic lock, and cancellation flag. Date-only entries (all day or time not yet known) use the all-day flag and local midnight boundaries;
end date is inclusive in the editor. Timed events use the application time zone. Cancellation
keeps the record and displays a clear cancellation label. No recurring-series editor,
RSVPs, notifications, external calendar synchronization, or drag-and-drop in this release.

## Public boundary

A public event exposes only its own explicitly entered title, description, dates, location,
and cancellation status. It never makes the parent Endeavor, updates, members, agendas, or
minutes public. The visibility choice lives on each event, including events created from
an Endeavor. The form explains that event details are intended for public display.

The eventual public website can consume a separate, read-only projection of public events.
The signed-in Public events preview shows only public event details, including a separate
public-details-only event view. Private project links and deadlines are excluded.
The model prepares a field-allowlisted projection for later sync; activating an unauthenticated
endpoint and building the public website are deferred. Existing authenticated agent APIs
remain unchanged. Do not share member-calendar HTML or cache it for anonymous use.
A later API should use bounded date ranges, a field allowlist, conditional requests, and
short cache lifetimes. Changes to visibility and cancellations must invalidate cached
responses; a public consumer must discard withdrawn entries on refresh. Meeting publication
needs a separate explicit decision; meetings remain member-only for now.

## Access

All enabled signed-in members can read the calendar and event details. Calendar mutation
requires server-side checks matching rendered controls: manage_settings administrators,
or current office assignments with the configured Commander/Adjutant authority (the existing
position-derived approve_minutes/attest_minutes rule). Personal agenda-management or
minutes-approval grants alone do not grant calendar management. This follows the roles
named in the initial request; broader delegated calendar management is not enabled.
No official-action authority is implied.

## Visual direction

Follow The 1919: navy #0A2240, gold #C6A15B, cream #F4EEDD, card paper #FBF7EC,
ink #1b222b. System sans for both working headings and body, tracked capitals for month
and weekday labels; reserve serif for official documents. Bounded existing application
frame, compact page heading, no large hero. The signature is a gold-ruled month heading
and clearly separated dated rows that remain readable for older members.

Desktop: month grid with readable linked titles; chronological schedule below it with
time and place. Narrow screens: schedule becomes the primary display, preserving full
labels instead of squeezing seven columns. Previous month, Today, and Next month are
ordinary links. Management uses the same schedule with adjacent edit actions and explicit
Members only/Public labels. Event forms use existing large controls, plain labels, and
visible errors. Keyboard focus and print output must remain usable.

Use simple_calendar as a small rendering helper, with application-owned templates and
styles. Its documentation supports custom attributes, multi-day events, and Turbo frames:
https://github.com/excid3/simple_calendar. Business rules and authorization stay in Rails
models/controllers, independent of the gem.

## Verification

Cover authentication, member read access, mutation denial, manager actions, cross-organization
Endeavor rejection, date validation, cancellation, stale edits, multi-day range overlap,
public field isolation, and navigation. Run focused tests and lint, then wider tests and
security checks for the new access surface. Inspect rendered desktop and 390px pages,
forms, focus, overflow, and print using synthetic test data. Preserve pre-existing worktree
changes and use only the test database for automated checks.

## Implementation and validation

Routes: `/calendar`, `/calendar/manage`, and `/calendar_events` (new/create/show/edit/update).
The Endeavor detail page lists upcoming linked events and offers Add calendar event to
calendar managers. Meeting editing retains the existing manage_agendas check and record
locks. Calendar display, month boundaries, and event time entry use the Post's saved
Organization.timezone, with APP_TIME_ZONE as the fallback for legacy invalid settings.
Stored timestamps are unchanged; daylight-saving offsets follow the Post's zone.

Migration: `20260906020000_create_calendar_events`. It has been applied to local development, test,
and an isolated QA database. The development migration added only the new calendar table;
existing records were not modified during that initial local validation. Both calendar
and task migrations are now applied in production.

Validation on 6 September 2026: full suite 893 tests / 5,703 assertions, no failures;
final focused suite after refinements 30 tests / 198 assertions, no failures.
Focused RuboCop passed; Brakeman reported zero warnings and Bundler Audit found no
vulnerabilities. Tailwind built successfully. Browser inspection used synthetic data in
an isolated test database at desktop and 390px widths, including creating, editing,
and cancelling an event, visible keyboard focus, no horizontal overflow, and print layout.
Automated checks used synthetic data; paid AI generation was not used.


## Endeavor activity refinements

The Endeavor page provides Next steps and Scheduled activities before its meeting history.
Tasks have optional due dates and can be marked done or reopened by Endeavor editors.
Past activities and completed steps remain accessible. The planning calendar adds due dates on request; its default remains meetings and events. Due dates are labeled
as deadlines rather than scheduled attendance events. Public events preview excludes all
project/task deadlines and internal context, even when a public event belongs to a private
project. No public API or caching was activated by this refinement.


## Verified production population

The `f22eec3` release seeded 18 source-supported CalendarEvents: ten past and eight
upcoming as of September 6; six public and twelve members-only, with five linked to
existing Endeavors. Three existing Meeting entries were retained without duplication.
The September 8 planning meeting uses the recorded 17:30 start and no invented end.
Unrecorded times use Date only. The later September minutes establish September 5 for
the Car & Bike Show, superseding the July agenda's inconsistent date label.

Seed application and repeat validation preserved all 606 rows in thirteen protected
meeting/minutes/agenda/Endeavor/rich-text tables, verified by complete-row fingerprints.
The repeat found eighteen existing events and created no duplicates. The private manifest
was removed from production after verification. Source decisions are in
`ENDEAVOR_ACTIVITIES.md`. No public website sync is active.

## Private API

See `CALENDAR_API.md`. The calendar, complete event history, tasks, and project deadlines
have member-readable private endpoints and permission-matched writes. `/api` generates
both JSON and Markdown documentation from the same permission-filtered catalog. Its
activity fields document timezone handling, date-only values, locking, and public-safe
serialization. No public endpoint, integration credential, or cache is introduced.

## Readability and event types

See `CALENDAR_REFINEMENTS.md` for Sunday-start weeks, colored event types and multi-select
filters, date-free default meeting names, and forgiving time entry. Categories can be set
in event/meeting forms; existing names provide automatic defaults until overridden. Calendar
filters are shareable URL parameters and apply to the grid and schedule together. API
parity is covered in `CALENDAR_API.md`.


The revised presentation uses colored event blocks and visible, instant type filters.
Desktop readers choose Month or Schedule; phone readers get a readable schedule. Officer
planning/public-preview utilities are separate from the ordinary attendance calendar.
See `CALENDAR_REFINEMENTS.md` for the persona walkthrough and final visual design.

Calendar managers can also delete a mistaken or duplicate CalendarEvent from its edit
page after a record-specific confirmation. Cancellation remains available when members
should see that plans changed. Deletion requires the current lock version and removes
only the calendar entry; linked Endeavors and official meeting documents remain intact.
The matching API DELETE action is listed under Only when asked. See
`CALENDAR_EVENT_DELETION.md` for scope and validation.
