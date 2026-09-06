# Calendar design

Status: implemented locally, 6 September 2026. Not deployed.

## Purpose and first release

Members need one top-level Calendar destination to find upcoming Post meetings and
activities. The calendar combines existing Meetings with new CalendarEvents. A CalendarEvent
can stand alone or belong to an Endeavor. An Endeavor can have several events; its Raise by
date remains an officer planning deadline and is not an event date.

Meetings retain their existing source of truth and editing safeguards. Calendar management
links to the existing meeting editor, so rescheduling cannot bypass published-agenda locks
or change official documents. Events are edited from a central management page and can also
be added from an Endeavor page. Completing an Endeavor does not cancel its events.

Each event has a title, plain-text description, start, optional end, all-day flag, location,
visibility (Members only by default, or Public), optional Endeavor, creator, last editor,
optimistic lock, and cancellation flag. All-day dates use local midnight boundaries;
end date is inclusive in the editor. Timed events use the application time zone. Cancellation
keeps the record and displays a clear cancellation label. No recurring-series editor,
RSVPs, notifications, external calendar synchronization, or drag-and-drop in this release.

## Public boundary

A public event exposes only its own explicitly entered title, description, dates, location,
and cancellation status. It never makes the parent Endeavor, updates, members, agendas, or
minutes public. The visibility choice lives on each event, including events created from
an Endeavor. The form explains that event details are intended for public display.

The eventual public website can consume a separate, read-only projection of public events.
This first release prepares that projection in the model; activating an unauthenticated
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
locks. Calendar events use the installation's APP_TIME_ZONE, consistent with Meetings;
Organization.timezone is not a separate per-record scheduling zone.

Migration: `20260906020000_create_calendar_events`. It has been applied to local development, test,
and an isolated QA database. The development migration added only the new calendar table;
existing records were not modified. No production changes were made.

Validation on 6 September 2026: full suite 893 tests / 5,703 assertions, no failures;
final focused suite after refinements 30 tests / 198 assertions, no failures.
Focused RuboCop passed; Brakeman reported zero warnings and Bundler Audit found no
vulnerabilities. Tailwind built successfully. Browser inspection used synthetic data in
an isolated test database at desktop and 390px widths, including creating, editing,
and cancelling an event, visible keyboard focus, no horizontal overflow, and print layout.
Automated checks used synthetic data; paid AI generation was not used.
