# Calendar event deletion

Managers need to remove mistaken or duplicate CalendarEvents, in addition to cancelling
activities whose changed plans should remain visible. Actual Meeting records are outside this deletion route. CalendarEvents categorized as
member or officer meetings (including automatically recognized PEC/membership titles)
also reject deletion at the model level and hide the delete control. Their existing
meeting/document safeguards remain intact.

Use the existing calendar-management permission for HTML and API. Add Delete event below
the edit form, outside its save form, using The 1919's existing danger button and shared
confirmation dialog. Show the saved event title and date, explain permanent removal, and
keep cancellation available for changes of plan. Retain readable desktop/phone layout,
keyboard focus handling, Cancel, and Escape from the existing dialog controller.

Deletion requires the last-read lock_version; reject missing/invalid or stale versions.
Scope lookup to the current organization. Delete only the CalendarEvent, never a linked
Endeavor, Meeting, agenda, or minutes record. Return to the same calendar month in HTML;
API DELETE /api/calendar_events/:id returns 204 and follows bearer idempotency/session CSRF.
Advertise it under Only when asked, with the existing calendar-management predicate.
No production record is deleted as part of implementing this feature.

Verify permission denial, scoping, missing/stale locks, dependent-record preservation,
public projection removal, idempotent API retries, and desktop/390px confirmation flows.

Local verification: 932 Rails tests / 6,078 assertions and 29 system tests / 243 assertions
passed, with no failures/errors/skips. The focused calendar/API suite passed 45 tests /
618 assertions. Five changed Ruby files passed RuboCop; Brakeman reported zero warnings
and the dependency audit found no vulnerabilities. Desktop and 390px screenshots confirmed
readable confirmation details and actions without overflow; Cancel and confirmed deletion
were exercised using synthetic records. No live event was deleted. Release includes the additional member/PEC/officer meeting-entry guard.
