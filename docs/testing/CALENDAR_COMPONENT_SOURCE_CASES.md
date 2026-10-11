# Exact calendar component source cases

Source `b965cf76ea7e8228db074e5df6d2e886df40cc30`, seven fully read files / 52 exact cases. Source reading, recorded execution and controlled faults remain separate.

## test/controllers/calendar_controller_test.rb

Reviewed file blob: `3cce640c66a75c5f35a85002fb3be06f12e0e780`.

- [calendar and events require sign in](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_controller_test.rb#L13)
- [members see meetings and events with top level navigation but no management controls](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_controller_test.rb#L20)
- [members receive a private inline PDF of the selected month view and event types](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_controller_test.rb#L51)
- [PDF requests preserve an explicitly empty category selection](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_controller_test.rb#L75)
- [PDF generation errors return to the selected calendar with guidance](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_controller_test.rb#L85)
- [PDF requests reject invalid month values before rendering](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_controller_test.rb#L94)
- [members and agenda delegates cannot mutate calendar events](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_controller_test.rb#L101)
- [current office assignments expire in the Post zone across UTC midnight](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_controller_test.rb#L118)
- [admin creates public linked event and edits or cancels it with provenance](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_controller_test.rb#L140)
- [all day dates include the last day and need no time](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_controller_test.rb#L164)
- [invalid dates and end times remain visible with validation errors](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_controller_test.rb#L176)
- [stale changes cannot overwrite an event](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_controller_test.rb#L187)
- [events cannot link to an Endeavor in another organization](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_controller_test.rb#L196)
- [print omits the event-type summary while retaining selected filters](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_controller_test.rb#L206)
- [printed schedule descriptions stay plain text and meeting addresses stay out of public preview](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_controller_test.rb#L219)
- [invalid calendar month redirects safely](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_controller_test.rb#L236)
- [invalid management month redirects without rendering twice](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_controller_test.rb#L242)
- [due dates are optional on member calendar and absent from public preview](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_controller_test.rb#L248)
- [Sunday weeks and multi-category filters retain selection in navigation](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_controller_test.rb#L273)
- [event form accepts shorthand times and explicit categories](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_controller_test.rb#L295)
- [calendar uses the Post zone even when the application zone is UTC](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_controller_test.rb#L307)

## test/controllers/calendar_event_deletion_test.rb

Reviewed file blob: `b0bd06f331ab6e61a6fe83fda10e8946913af9ff`.

- [HTML deletion requires manager and current lock and retains Endeavor and Meetings](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_event_deletion_test.rb#L14)
- [API deletion is scoped authorized locked and idempotent](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_event_deletion_test.rb#L33)
- [member and PEC entries are protected in HTML API and model](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_event_deletion_test.rb#L59)
- [actual Meetings cannot be deleted through calendar event routes](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_event_deletion_test.rb#L74)
- [handbook deletion appears only under explicit actions for calendar managers](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_event_deletion_test.rb#L85)

## test/models/calendar_event_test.rb

Reviewed file blob: `fbe7e5aa8461a4f851aa983a287eae0b13595a07`.

- [public projection excludes internal ownership and planning records](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/calendar_event_test.rb#L9)
- [calendar month includes overlapping events and excludes unrelated months and organizations](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/calendar_event_test.rb#L21)
- [missing Endeavor is reported as a validation error](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/calendar_event_test.rb#L34)
- [end must not precede start and visibility is constrained](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/calendar_event_test.rb#L40)
- [completed steps and projects do not appear as calendar deadlines](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/calendar_event_test.rb#L47)
- [automatic categories recognize Post meeting and service names with explicit overrides](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/calendar_event_test.rb#L57)
- [public events and planning are distinct from volunteering and Honor Guard](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/calendar_event_test.rb#L68)
- [Post local dates control midnight events and deadlines outside a calendar request](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/calendar_event_test.rb#L80)

## test/system/calendar_event_deletion_test.rb

Reviewed file blob: `178ad3bd2260213c5813eb8d08243b3f2b005318`.

- [manager can cancel confirmation or delete at desktop and phone widths](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/system/calendar_event_deletion_test.rb#L4)

## test/system/calendar_mobile_schedule_test.rb

Reviewed file blob: `ded7c10f70e0ca216307a424667446d5524427b3`.

- [day groups and event details are clear on narrow screens](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/system/calendar_mobile_schedule_test.rb#L4)

## test/system/calendar_refinements_test.rb

Reviewed file blob: `35a94e952c81fa7435daf062e4d5317eac16a2bd`.

- [readable calendar filters and forgiving time entry at desktop and phone widths](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/system/calendar_refinements_test.rb#L24)
- [member discovers events and filters Honor Guard with visible controls](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/system/calendar_refinements_test.rb#L60)
- [event details stay legible with neutral colors and show timezone only for timed events](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/system/calendar_refinements_test.rb#L114)

## test/system/calendar_print_test.rb

Reviewed file blob: `f7177520a9d153fd4adbaf294f0dfefe1511a2c3`.

- [prints the month and detailed schedule together with the selected filters](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/system/calendar_print_test.rb#L60)
- [Print PDF delivers one finished document with fixed orientations margins and selected events](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/system/calendar_print_test.rb#L166)
- [a five-week month with two busy weekends fits one landscape page with a single-line heading](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/system/calendar_print_test.rb#L210)
- [a six-week month prints on one landscape page followed by the portrait schedule](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/system/calendar_print_test.rb#L245)
- [printing from a phone includes both layouts without changing the selected view](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/system/calendar_print_test.rb#L271)
- [printing and cancelling preserve either selected screen view and its filters](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/system/calendar_print_test.rb#L313)
- [printed dates do not highlight the current day](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/system/calendar_print_test.rb#L336)
- [print content keeps quarter-inch margins when the browser overrides page margins](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/system/calendar_print_test.rb#L351)
- [an empty selection prints one month page and an empty schedule without a trailing page](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/system/calendar_print_test.rb#L370)
- [crowded days continue onto additional pages without shrinking the chosen print size](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/system/calendar_print_test.rb#L382)
- [printed schedule includes the saved meeting address](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/system/calendar_print_test.rb#L406)
- [long schedule descriptions continue onto later pages without clipping](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/system/calendar_print_test.rb#L418)
- [one long paragraph flows across pages without forcing a heading-only sheet](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/system/calendar_print_test.rb#L438)
