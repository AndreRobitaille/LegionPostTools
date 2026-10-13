# Buddy Check coordination and separate county reporting

October 12, 2026. Andre clarified that Buddy Checks are check-ins, taking care of
one another, and sometimes suicide prevention. Renewal/dues work is Membership.
County receives a separate monthly total of checks performed, counting only checks
where the person was reached. Other statistics are for internal coordination.

## Workflows and boundaries

Menu → Your work → Buddy Checks remains the entry. A pilot gets their personal
calling workspace. A coordinator without pilot access gets Post activity. Existing
full membership-information authority controls coordination: current configured
Commander, 1st Vice Commander, Adjutant, or an explicit full-information grant.
This reuses the current private-outreach reading boundary, not a new office or an
expanded caller grant. Coordinators can enter through a distinct Buddy Checks row
in Officer tools as well. Ordinary callers keep their own check history and notes.

Post activity lists effective Buddy Check records saved on the website, mobile app,
or returned paper, across membership years. It shows who checked in, whom they
checked on, when, channel, result, and a link to that member's Buddy Check history.
Search/filter/pagination never add dues contacts. Member history is a Buddy-only
record; private notes stay here rather than under Renewal follow-up.

County report selects one Post-local calendar month and presents one count:
Buddy Checks performed. Reached and callback-requested conversations count, as do
actual contacts where the person asked for no more contact. Administrative reviews,
permission changes entered administratively, no-answer/message/wrong-number attempts,
not-attempted records, renewal/welcome entries, and superseded revisions do not count.
A callback completion alone is not another check. Use the contact date, not entry date.
The summary contains no member names, caller notes, care concerns, or financial data.
It is a live, dated total for a human to review and report to county, not an automatic
submission or an official Meeting record.

Internal coverage uses current roster-backed people excluding removed/deceased entries.
No Buddy-contact permission excludes outreach regardless of renewal standing. Show
last actual conversation and last recorded attendance. Human-recorded extra-care
follow-up sorts first by review date, followed by explicit absence alerts. The Post
activity page calls attention to care reviews due for follow-up. A configurable look-back (default
60 days, visibly named) identifies missing/older recorded conversations. Missing
history means unknown. Only the latest two covered registers, both complete and both
explicitly absent, produce a meeting-absence alert; later incomplete/unknown/present/
excused evidence interrupts that inference. No attendance or AI inference of risk. HTTP no-store and disabled Turbo snapshots
protect the coordinator pages from stale private previews after authority changes.

Private extra-care follow-up is human-entered, attributed, and versioned. A coordinator
records a short practical reason, responsible coordinator, and review date. Resolution
adds a later event; the original note survives. Stale submissions cannot overwrite newer
care decisions; retries of the same submission cannot create another revision. Disabled
accounts and expired roles lose read/write access on the next request. Notes never
enter county summaries, caller pages, mobile API responses, or general member profiles.
No automated diagnoses, risk scores, external messages, or crisis-service instructions.

Renewal screens cease serving Buddy-only history and drive lists. Existing storage and
mobile contracts stay intact. Buddy drive pages retain their current write guards and
paper workflow, but use Buddy headings/navigation and no renewal-year chooser.

## Visual direction

Apply the frontend-design skill and the established 1919 system: navy #0A2240,
gold #C6A15B, cream #F4EEDD, paper #FBF7EC, ink #1A2638. Keep system sans for body
and headings; use the existing tracked utility labels. Body/actions at least 16px,
secondary 14px, labels 13px, and targets 44px. Use bounded, full-row task destinations,
plain filters, and stacked phone records. The signature is a care-coverage ledger:
last conversation, last attendance evidence, and the next human follow-up stay together.
County reporting deliberately has one large monthly number, with no internal dashboard
statistics beside it. Distinguish observation, unknown evidence, and human concern in
words; color supports those labels. Avoid extra tabs in the global menu.

## Verification

Use synthetic named test databases. Verify mobile/API write → coordinator activity →
member history → county count, date boundaries, corrections/retries, unanswered and dues
exclusions, no-contact coverage, revised/incomplete attendance, care owner/date/revision,
stale/retried care forms, expired authority, ordinary-caller denial, and report privacy.
Render desktop and phone layouts; exercise filters, empty states, keyboard navigation,
and invalid-form recovery. Establish a bounded fault detector and green restoration.
Leave the requested development server on 0.0.0.0; apply only necessary additive local
schema migrations, preserving tracked schema output and existing member records.
