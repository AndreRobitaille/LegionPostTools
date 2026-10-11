# Membership management, outreach, and reporting

Research and design, October 11, 2026. The first workspace is implemented;
see [its operating guide and boundaries](MEMBERSHIP_WORKSPACE.md). The broader
delivery sequence remains proposed. Repository baseline: `6d4e96d`.

## First implementation

### October 11 screen revision

Andre's desktop review found the landing page too broad, its report labels unclear,
and its default list filled with members who did not need action. The revised
landing page has one job: help the officer or assigned caller choose the next member
to work on. Reports, drive administration, and Post checks have separate destinations.
The navigation remains limited to current membership authority or active assignments;
ordinary members do not receive the destination or direct workspace access.

The default **Needs attention** view includes due callbacks, unresolved renewal
follow-up, payment confirmation for officers, and membership records needing review.
It omits confirmed renewals, paused contact, declined renewal, future callbacks, and
completed welcome/Buddy Check contacts. **All members** (or **All assigned members**)
keeps those records available. Payment confirmation is named as verification, never
as another request to pay. Buddy Checks and welcome assignments retain their purpose.

Visual direction: compose from The 1919's bounded shell, existing list rows, quiet
rules, section headings and large controls. Use navy #0A2240, gold #C6A15B, cream
#F4EEDD, paper #FBF7EC and ink #1b222b. Working text uses the existing system sans;
tracked capitals identify sections and 14px secondary text explains the next action.
Serif remains reserved for official documents. Desktop rows use the width for member,
next step with its Open action, and callback date; phones stack those same fields.
There are no report counters or financial forms above the worklist.

```
Membership   [Member follow-up] [Drives] [Adjutant report] [Post checks]
Year | Needs attention / All members | Member name
Member           Next step + Open                         Callback
```

The Adjutant report defines each count in plain language: paid for the selected year,
dues collected here but awaiting National confirmation, claimed online renewals,
unpaid members, paused renewal contact, and records needing review. Financial totals
are separately labelled as money recorded, and source/staleness remains visible.
Rendered desktop and 390px review, ordinary-member navigation denial, default-list
exclusions, explicit all-member access, and separate report/check workflows are
required verification for this revision.

### October 11 outreach exclusions

Andre identified deceased members at the top of the follow-up list. Imported
deceased and removed records are historical records, not contact or record-review
tasks. Exclude them from every outreach purpose, even if an earlier callback or
receipt remains. Keep their history available to officers through **All members**,
show a plain **No outreach** explanation in the existing next-step row, and omit
phone/email actions. No roster facts or historical entries are changed. The report
lists deceased and removed records separately from records needing review; older
saved summaries retain their original figures and definitions.

Renewal drives and freshly generated call sheets also omit confirmed renewals,
payments awaiting officer verification, declined renewal, paused contact, future
callbacks, and records whose standing needs officer review. Expired members can
still need renewal help; an expired status alone is not a contact exclusion. Paid
members remain eligible for separately assigned welcome calls and Buddy Checks.
Current work determines whether contact actions appear; administrative verification
is not a new request to renew. A new roster status suppresses a stale call form on
submission and on API replay. Officers may still enter reviews or returned paper
history without restoring outreach eligibility.

Visual direction remains the existing 1919 rows and quiet notices. Add no counters
or panels to the landing page. Keep the reason beside the member and use the report
only for the historical counts. Verify the default list, all-member history, stale
submissions, renewed/declined/deferred assignments, and actual PDF content with
synthetic records, and inspect the changed screens at desktop and 390px widths.

Andre authorized starting the feature and clarified another actual workflow:
members renew directly on National's website, and the Post later receives a check.
This describes the Post's reported practice; the check schedule and calculation
have not been verified. Track the check as money received by the Post, separately
from each member's renewal. A confirmed renewal does not depend on that check.

The initial slice includes a private Membership workspace with explicit year
selection, per-member outreach history, dated volunteer assignments, drive call
sheet PDFs, an append-only register for full-year local dues receipts and reports
of National payment, a separate Post-share check register, and saved aggregate
Adjutant summaries. Officers with current full-membership access manage this
workspace. Volunteers can work only their active assignments. Existing login and
National roster rules remain authoritative.

Returned sheets retain both caller and recorder. A same-day paper result preserves
the digital next step until an officer records a reasoned administrative review.
Volunteers can see officer-entered results and reviews attached to their assigned
calls; separate individual officer notes remain outside their scope. Officers can
transcribe historical assignments after revocation without reopening caller access
or restoring paused contact permission.

Receipt and check entries record observed administrative facts; they do not
transfer funds or authorize expenditure. Mistaken entries are reversed with an
attributed reason. No amount or expected check is calculated from a presumed dues
rate. A local receipt is explicitly for full-year dues; partial-payment accounting,
transmittal batches, automatic message sending, historical import reconstruction,
and form-specific award certification follow in later slices.

The first screens use The 1919 working components, with National standing, Post
renewal work, and next contact visibly labeled. Source dates accompany totals.
Call sheets use generous member blocks and the same outcome terms as the screen.
The first summaries freeze today's figures; they do not claim to reconstruct a
past date. Current authority is rechecked for HTML, JSON, and PDF generation.
The initial JSON surface supports scoped worklist/member/drive reads, contact
entry, and call sheet PDFs. Drive management, financial entries, and saved summaries
currently use the signed-in website.

## Purpose and confirmed scope

Give American Legion membership officers one place to prepare the Adjutant's
membership report, follow up with individuals, run membership drives on screen or
paper, and assemble evidence for awards and Department reports. Ground the first
installation in Post 165 while keeping identity, dues, goals, and Department rules
configurable for other American Legion posts.

Andre confirmed:

- Membership officers and volunteers may help with drives. Volunteers see only
  assigned members.
- Post Excellence is the first award to support.
- Track dues received locally separately from National's roster. The software
  should explain the steps because the local processing mechanics need discovery.
- Investigate the other recurring reports, recalled as something like “POR.”

This proposal treats “website” as the private LegionPostTools member application.
Any later public recruitment page would use the separate reviewed public-publishing
contract; individual membership standing and outreach history stay private.

## Research findings

### Membership administration and personal contact

The [2026 Post Adjutant's Guide][adjutant], printed pages 18–21 and 23–24, describes
recording payment, providing the member's card, and transmitting membership through
Department or MyLegion. Local receipt and National processing are separate steps.
Post-paid honorary life membership still requires annual dues handling; it is
distinct from National Paid Up For Life membership. These distinctions should be
visible in our workflow.

[National's report guidance][report-guidance] explains that MyLegion rosters and
membership totals can differ because of transfers, report selection, and timing.
Therefore an imported roster count should carry its source and definition and
should not be presented as the Department's certified award count.

[Post experiences published by National][post-examples] provide useful examples:
Chula Vista Post 434 followed up with new members through a welcome contact, and
Yelm Post 164 contacted prior-year nonrenewals and headquarters-post members.
These are reported practices, not controlled evidence of effectiveness. They
support separate welcome, renewal, and transfer follow-up worklists.

The [Buddy Check toolkit][buddy-check], printed pages 1 and 4–5, supports assigned
call lists, paper copies, scripts, and recorded follow-up. Its purpose is veteran
welfare. Use a distinct Buddy Check purpose and script, without inserting a dues
request. A member who independently asks about renewal can receive help, recorded
as a separate membership follow-up. Keep clinical or detailed personal hardship
information out of general drive notes.

### Reports and awards have different definitions and years

| Report or award | Verified purpose | Proposed support |
| --- | --- | --- |
| [Post Excellence, current National page][post-excellence] | 103% of assigned membership goal, 90% renewal of the 2026 roster, officer attendance at district meetings, CPR submission, community activity, and district certification | Evidence checklist, separate growth and cohort-retention measures, dated supporting records, submission tracking |
| [Wisconsin Post Excellence form][wi-excellence] | Currently linked as 2025–2026; its renewal baseline is 2025 | Preserve form edition; do not silently reuse its year for a new application |
| [2027 National membership awards guide][awards] | Different programs have distinct qualifications; the Post Membership Retention Award specifies 95% by the May target date | Keep award rules attached to their membership year and source; do not use one threshold for all awards |
| [Wisconsin membership report][wi-report] | Separates new, PUFL, renewal, headquarters transfers, total, goal, and goal percentage | Officer-entered Department observations alongside locally derived counts, with report date and source |
| [Consolidated Post Report (CPR), 2025–2026][cpr] | June 1–May 31 activity reporting; includes prior-year final membership and Buddy Check participation/contact fields | Dated totals and supporting outreach evidence; membership is one part of the larger Post activity report |
| [Post Data Report (PDR), linked for 2026–2027][pdr] | Updates Post contact/location information, dues amount/address, meeting schedule, and facilities | Prefill from organization settings for human review; retain submitted version |
| [Yearly Post Officers Reporting Form, linked for 2027][por] | Officer names, IDs, contacts, election/installation dates, and requested MyLegion access | Prepare from dated position assignments; each officer reviews contact details |

“POR” may mean the Post Officers Report. PDR and CPR are other likely candidates;
Andre has not yet identified which additional reports the Post routinely submits.
The Wisconsin officer form is revised August 13, 2026 and requests submission even
when officers have not changed. Its PDR is an updates-only form. These cannot share
one generic annual “report complete” checkbox.

The currently linked [Wisconsin McCoy/O.W. Rolfe form][wi-americanism] also uses
Post membership size and a comparison with the preceding year. It is marked
2017–2018. Record it as a candidate future mapping, with currency requiring review.

There are source ambiguities worth preserving rather than programming around:

- The 2027 awards guide's printed page 31 describes retention using prior/current
  totals. That wording does not establish a same-member cohort calculation. Seek
  Department clarification before automating certification for that award.
- The National Post Excellence page and Wisconsin's linked older form refer to
  different baseline years. A report must identify the intended award cycle.
- Wisconsin still links a 2025 paper membership transmittal. Its printed remittance
  rate is not sufficient evidence of the rate for a future membership year.

These issues do not prevent recording evidence, receipts, and contacts. They prevent
claiming automatic official qualification from an unverified formula or old form.

## Existing application foundation

Source review located these usable components:

- [Person](../app/models/person.rb) stores current imported roster fields, local
  directory contacts, paid-through year, membership type, and continuous years.
- [MembershipReport](../app/services/membership_report.rb) classifies an explicitly
  requested year and reports import freshness. Its `current_members` definition is
  present Active/Grace roster records, not necessarily paid for the selected year.
- [Membership API](../app/controllers/api/membership_controller.rb) supplies private
  summaries, renewal lists, roster records, and individual records.
- [Roster importer](../app/services/roster_imports/importer.rb) matches member IDs,
  updates the current projection, records aggregate field changes and named status
  changes, and reconciles roster-controlled login access.
- [Roles policy](ROLES.md) and `User#full_membership_access?` provide current dated
  membership authority, including configured membership positions and existing
  people-management access. Role labels are not permission checks.
- [Loops roster synchronization](LOOPS_ROSTER_SYNC.md) provides audience management.
  It does not establish a membership correspondence log or individual delivery
  evidence, and its Active/Grace selection is insufficient for lapsed-member drives.
- [PDF delivery](PDF_DOCUMENT_DELIVERY.md) already provides authenticated Chromium
  PDF rendering and resource restrictions.

The current directory is a roster reader. It has no dedicated drive assignments,
structured outreach history, local dues register, or saved membership report.
Import summaries are not complete per-member historical snapshots. Requesting an
old membership year against today's Person rows cannot reconstruct what the Post
knew at that earlier date. Existing tests were read; no runtime or production
membership behavior was exercised during this research.

## Proposed product model

Keep three independently understandable kinds of status:

| Kind | Examples | Authority |
| --- | --- | --- |
| Imported membership facts | National status, paid through 2027, PUFL, continuous years, import date | Dated National roster observation; corrections follow the established external process |
| Post renewal work | Member reports paying online, dues received here, ready to transmit, submitted, confirmation outstanding | Attributed local records and external references |
| Outreach | Assigned to Pat, left message, callback Friday, contact details need correction, renewal contact declined | Dated contacts, assignments, and member preferences |

An outreach result never changes National status or login eligibility. An import
never erases local contact history, preferences, receipts, or unresolved corrections.
“Removed from this import” does not mean deceased, transferred, or resigned.
Paid ahead alone does not establish enrollment in a particular multi-year program.

### Dues: explain the handoff and preserve the evidence

The proposed local workflow is:

1. **Record dues received.** Select the member and membership year, receipt date,
   amount, method, payer (member/Post/sponsor), receiving officer, and a receipt or
   accounting reference. Keep membership year separate from receipt calendar year.
2. **Prepare a transmittal.** Group eligible records by membership year. Show what
   is ready, incomplete, already submitted, or already confirmed through another
   channel. Store configured rates with effective dates and source; never hard-code
   the Post's dues or a historical Department rate.
3. **Record submission.** An authorized officer actually submits through MyLegion
   or the Department process, then records channel, date, batch/reference, and
   amounts. Saving a local batch is not evidence it was submitted externally.
4. **Reconcile confirmation.** A later roster or reviewed external confirmation
   establishes year coverage. Match by member ID and year, preserving the evidence.
   A roster match proves coverage, not necessarily which payment caused it. A
   possible duplicate local/online payment remains an officer exception.

This follows the administrative separation in the [Adjutant's Guide][adjutant] and
the year-specific batches on [Wisconsin's linked transmittal][transmittal]. It is a
local working register; bank/card collection and accounting integration are later
work. Never store card details or bank credentials in notes.

Other required cases:

- **“I already paid online”** creates a follow-up hold, not a cash receipt or verified
  renewal. It has an owner and review date so it cannot disappear indefinitely.
- **Direct National renewal** can become confirmed without any local receipt.
- **Post-sponsored dues** record who funds the year; honorary life and PUFL remain
  distinct. Partial receipts remain incomplete until an officer resolves funding.
- **Errors, returns, and refunds** use linked corrections/reversals with reasons,
  retaining the original financial event. Do not delete a receipt to fix a total.
- **Membership card delivery** has its own optional date/method so an officer can
  distinguish payment work from getting the card to the member.
- **Duplicate and interrupted entry** must not create duplicate money or batch
  records. Submitted batches preserve exact included records; corrections append.

Recommended authority: full-membership officers manage outreach; receipt and
transmittal changes use an explicit membership-finance capability configured on
appropriate positions. Initial Adjutant/Finance Officer duties need to be checked
against the Post's actual practice. Giving a Finance Officer this narrow capability
must not silently grant the entire private membership workspace.

## Proposed screens and workflows

### Membership overview and the Adjutant's report

Add **Membership** to the authorized officer navigation. Lead with selected
membership year, source date, next follow-ups, and a clear route to **Prepare
Adjutant report**. Provide distinct totals for roster-confirmed coverage, local
receipts awaiting confirmation, self-reported payments to verify, renewal work,
and unresolved records. Display Department progress separately when a sourced
Department observation is available.

Preparing a report selects its meeting/as-of date and comparison snapshot. Save the
counts, definitions, source import IDs, local observation cutoff, preparer, and
exceptions. Distinguish events effective by the date from evidence learned later.
Do not fabricate historical counts where no baseline exists: show “Not recorded.”

Produce an aggregate meeting handout and officer-only supporting detail. The
Adjutant can copy a reviewed summary into the draft Adjutant report using existing
meeting authority. Private call notes and individual dues details are excluded.
Saved meeting report text and accepted minutes never change with a later import.

### Individual outreach

A member's membership page shows imported standing, local renewal work, last
contact, next action, and the contact timeline together. **Record contact** asks
for purpose, actual date/time, channel, result, brief factual note, and next action.
Channels include in person, phone, email, postal mail, website, and manually logged
text messages. Use separate purposes for renewal, welcome, transfer assistance,
contact correction, and Buddy Check.

Results distinguish no answer, message left, reached, callback requested, reports
already paid, interested in renewing, declined renewal, and officer review needed.
A sensitive report such as possible death suppresses ordinary renewal outreach
pending review without silently rewriting the National record. Detailed financial
hardship or welfare case notes belong in a narrower follow-up, not volunteer lists.

Track preferred channels, do-not-contact choices by purpose/channel, their source,
and when they were recorded. A phone number is not permission for automated texts.
Contact updates and suppression survive the next import. A correction needing
National attention stays visible until an officer resolves it.

Email has useful steps before provider automation: prepare a reviewed message,
open the member's email address, and record actual contact separately. Opening an
email composer is not “sent.” Later integrated sending needs recipient/content
review, current suppression checks, reply ownership, delivery/failure history,
and duplicate-send protection. Existing Loops opt-outs must be preserved. Actual
sending behavior and suitable provider remain a focused integration decision.

For logged-in members, show only their own dated status and a plain renewal prompt,
with **Renew through National**, **I already paid**, and **Ask the Adjutant**.
Self-reports create officer work rather than altering paid status. Show a pending
local receipt in place of another request to pay. Expired members may have disabled
accounts under existing policy, so phone, mail, and email remain necessary.

Texting automation is a later optional channel. The core contact model supports
it, but automated sends require chosen provider behavior, recorded permission,
opt-out handling, and reply management before activation.

### Membership drives and paper call sheets

Create a drive with purpose, membership year, date range, lead, script, and explicit
audience criteria. Preview eligible members and exclusions. Assign each member to
one responsible caller, with temporary access ending on the saved date or earlier
revocation. People without logins can be named paper callers; an officer distributes
their sheets and transcribes results with both caller and recorder attribution.

Drive worklists show contact choices, relevant year status, last attempt, next
action, and a quick **Record result** action. Detect conflicting assignments across
active drives and show recent contact to prevent repeated calls. A new roster can
resolve renewal work without deleting the member's participation or the drive's
original selection. Follow-ups survive drive closure under a membership officer.

PDF packet design:

- US Letter, low ink, readable type, clear drive/year/caller/date, short script,
  and a reminder of where to return the completed sheets.
- Two generous member blocks per page by default, with name, approved contact
  route, applicable renewal state, outcome checkboxes, callback date, and writing
  space. Include an address only for an authorized in-person/postal assignment.
- No default full member ID, unrelated roster fields, payment detail, or private
  history. Use an internal sheet/member reference to match returned notes.
- Mark source date, packet ID, page numbers, and private Post use. Paper reflects
  its generation time; changes after printing require a replacement or caller
  update. Online revocation cannot recall a printed copy.
- **Enter paper results** preserves contact time, caller, transcription time,
  recorder, and packet reference. Detect previously entered lines and show newer
  online results before saving; never overwrite them from an old sheet.

Drive totals distinguish attempts, distinct people reached, follow-ups remaining,
renewals later observed, and payments received. A renewal after a call is an
observation, not proof the call caused it or automatic recruiter credit.

### Post Excellence and report preparation

Start with a Post Excellence worksheet for a selected cycle. Show each requirement,
current evidence, missing evidence, responsible officer, and due date. Membership
evidence includes assigned goal, official observation, and prior-year cohort.
Other evidence links district meeting attendance, the submitted CPR/receipt, and
community activity records. A calendar event alone does not prove attendance or
that an activity actually occurred.

Show these measures separately:

- **Goal attainment:** accepted official count divided by the assigned goal.
- **Operational cohort retention:** distinct members from an explicit prior-year
  baseline who have confirmed coverage for the target year, divided by that
  baseline. Preserve baseline membership and any approved adjustments with reasons.
- **Official award determination:** the reviewed rule edition and evidence accepted
  by the relevant certifying authority. It may require reconciliation beyond the
  local cohort metric.

Do not infer retention by dividing this year's total by last year's total. New and
transferred members can increase totals while prior members fail to renew. Do not
silently exclude deaths or transfers from a historical denominator; any adjustment
depends on the named rule. A missing or zero denominator produces “Not available.”

Reports use explicit states: preparing, ready for review, submitted externally,
receipt/acknowledgment recorded, and returned for correction where applicable.
Each submitted version is preserved with source/form edition, reporting window,
supporting evidence, submitter, submission date, and confirmation. A correction
creates a new version. The app prepares evidence; it does not provide a district
signature or certify an award itself.

For CPR, retain attempted contacts, successful contacts, and distinct members
reached so an officer can apply that edition's counting instructions. Do not
equate every call attempt with a member contacted or claim membership records
complete the full CPR. PDR and officer-report preparation should reuse organization
settings and dated role assignments rather than inventing parallel member fields.

## Access and implementation boundaries

| Actor | Proposed membership access |
| --- | --- |
| Current full-membership officer | Overview, full worklists/history, drive administration, reports, correction review |
| Authorized receipt/transmittal officer | Explicit financial work and only the member details required for it |
| Assigned volunteer | Current assigned members, necessary contact/renewal context, drive script, own work results, and authorized packet |
| Ordinary signed-in member | Existing directory plus their own member-facing status, self-report, and contact choices |
| Public visitor | No private membership records, assignments, or drive PDFs |

Use the same policy for HTML, PDF, JSON, and delegated-agent calls. Enforce current
authority on every read and write, including downloads, queued delivery, and stale
open tabs. Assignment expiry uses the Post's configured local date. Volunteers
cannot enumerate the full renewal audience or change financial/official status.
Old assignments and historical officer terms preserve attribution without access.

Build within Rails, PostgreSQL, Turbo, Solid Queue, and existing PDF services.
Proposed records, introduced only with the workflow that needs them:

- Immutable import membership observations, linked to person and import, storing
  the minimum membership facts needed for history; keep current Person projection.
- A membership-year record for confirmed dues settings, goal, baseline, and sources.
- Dues entries and transmittals with attributed lifecycle events and reversals.
- Drives, dated assignments, structured contact entries, and contact preferences.
- Saved report versions and explicit external evidence references/attachments.

Capture import observations atomically with successful imports. Do not infer
historical rows from today's values or keep duplicate full contact data in every
membership snapshot. First adoption can start with a labeled current baseline;
older baselines require officer-supplied source evidence. Protect linked history
from cascading person deletion. Use database uniqueness and transactions for
duplicate receipts, assignments, batch entries, and paper-result submissions;
version checks protect concurrent edits. Reuse private/no-store PDF delivery,
short-lived rendering authorization, and deny-by-default resource policy.

Avoid a general CRM, arbitrary rules engine, new payment gateway, automatic National
write-back, or a second account-permission system. Membership activity is structured
work tied to existing people and Post responsibilities.

## Visual direction

Follow [The 1919 system](superpowers/specs/2026-07-11-visual-design-system-design.md):
warm paper, navy working text/actions, restrained gold structure, sans-serif working
screens, and serif only where an actual report calls for it. Make the defining
visual element the three clearly labeled lines on each member's work record:
**National record**, **Post renewal work**, and **Next contact**.

The overview prioritizes today's follow-ups and report preparation. Use labeled
lists with clear status text, rather than a wall of charts. Desktop can pair the
worklist with member detail; narrow screens open one member at a time and keep
**Record result** easy to reach. Use the existing 900px/560px breakpoints and 16px
body/interactive, 14px secondary, and 13px label floors. Status never depends on
color alone. Call sheets use the same vocabulary as the screen and enough space
to write with a pen. Render and critique desktop, narrow, and actual PDFs during
implementation; this text specification is not rendered UI verification.

## Delivery sequence

1. **Membership facts and local dues:** year selection, historical observations,
   independent local receipts/submissions, reconciliation exceptions, saved
   Adjutant summary, and source-aware member status.
2. **Outreach and drives:** contact history/preferences, temporary volunteer
   assignments, web worklists, actual call-sheet PDFs, paper result entry, and
   member self-reports. Include welcome and distinct Buddy Check purposes.
3. **Post Excellence and recurring reports:** evidence checklist, sourced goal and
   retention measures, report versions/submission tracking, and mappings for the
   identified CPR/PDR/officer-report editions.
4. **Integrated communications:** reviewed individual email, provider outcomes and
   replies; optional texting after its operational choices are resolved.

The first useful release should include the officer summary, local dues tracking,
and a complete web-to-paper drive workflow. Do not call it complete if it only
adds status labels to the directory. Form-specific prefill and communications can
follow without delaying manual outreach and reliable evidence collection.

## Acceptance evidence required for implementation

Following [Testing and workflow validation](TESTING.md), exercise synthetic users
through realistic saved, visible, and later-read behavior:

1. A 2027 local receipt entered during 2026 removes repeated payment requests but
   leaves imported standing intact; later National coverage reconciles it without
   double counting. Test direct National renewal, partial receipt, duplicate
   payment, failed batch, reversal, PUFL, and Post-sponsored dues variants.
2. A report saved before another import retains its original totals and sources.
   Missing historical baseline is explicit. New members increase goal progress
   without artificially increasing prior-year retention.
3. An assigned volunteer works on screen and from a PDF, records callbacks, and
   transcribes an old sheet without overwriting newer work. Another volunteer,
   expired assignment, expired officer term, and stale bearer/session requests
   cannot retrieve or modify those records.
4. National imports preserve local history and do-not-contact settings. Reported
   death or contact problems enter review; a contradictory import remains visible.
5. A logged-in member sees only their own private status; self-reported payment is
   visibly unverified. No private status leaks into the public publishing API,
   standard directory payload, unauthorized PDF, or member-visible minutes.
6. Post Excellence shows each requirement and unresolved evidence; filling a
   worksheet never marks district certification or external submission complete.
7. Real Chromium PDFs handle long names, missing contacts, many pages, writing
   space, and no split member blocks. Review desktop and 390px workflows, keyboard
   use, validation errors, network interruption, and PDF generation failure.
8. Provider sending, when added, distinguishes prepared, queued, sent, failed, and
   reply states; rechecks current suppression/authority and prevents duplicate
   sends. Use synthetic offline provider tests before separately authorized live
   delivery checks.

## Remaining operational discovery

The following needs the Post's actual practice, not assumptions about National:

- Who currently receives/deposits dues, who submits them, which channel is used,
  and who may correct/reverse entries; verify the membership-finance capability.
- Current Post dues, applicable remittance rates, sponsored-member policy, receipt
  references, and any bookkeeping reconciliation procedure.
- Exact additional reports and the cycle being prepared; obtain any missing
  prior-year baseline and assigned Department goal from a dated source.
- The sender/reply process for integrated membership email. Texting remains optional.

These are targeted discovery items. No production data, National account, payment,
message delivery, commit, push, or deployment was used to produce this proposal.

## Sources

All linked sources were accessed October 11, 2026. Document editions above are the
editions actually found, not claims that every Department form is current for 2027.
The Wisconsin forms page required direct HTML/PDF retrieval because the web reader
could not open it; the PDR, officer report, and transmittal text were extracted from
the PDFs linked there. No private National or Post account was accessed.

[adjutant]: https://www.legion.org/getmedia/32a81555-9d40-460f-b236-01717f9d42ab/89ia1225-post-adjutants-guide.pdf
[report-guidance]: https://www.legion.org/information-center/news/dispatch/2022/may/how-to-access-membership-reports
[post-examples]: https://www.legion.org/information-center/news/dispatch/2024/july/contact-members-for-renewal-success
[buddy-check]: https://www.legion.org/getmedia/3ecf21c8-2df1-4c8b-a7ad-b68b3497030d/57mem0923-buddy-check-toolkit.pdf
[post-excellence]: https://www.legion.org/about/leadership/national-commander/post-excellence-award
[awards]: https://www.legion.org/getmedia/d263b2aa-03f4-49c8-b597-108ad6c87865/47mem0326-2027-membership-awards-points-manual.pdf
[wi-excellence]: https://img1.wsimg.com/blobby/go/b3421eb7-36e9-43f7-86b8-17a5786633b2/downloads/16df952e-2f7a-4f80-ba58-cd13eec5c0af/2025-2026%20Post%20Excellence%20Award%20Description%20an.pdf?ver=1791463698647
[wi-report]: https://img1.wsimg.com/blobby/go/b3421eb7-36e9-43f7-86b8-17a5786633b2/downloads/eee21828-6f8f-448b-a46f-a89b7aab0b02/Week%20_13%20Membership%20Report.pdf?ver=1791463694244
[cpr]: https://www.legion.org/getmedia/2cf68a99-4989-4ad0-bdca-8e7ed764699d/71ia1125-consolidated-post-report-fillable2.pdf
[pdr]: https://img1.wsimg.com/blobby/go/b3421eb7-36e9-43f7-86b8-17a5786633b2/downloads/a7a1a206-da27-4cea-8913-1463ef47d38b/2026-2027%20Post%20Data%20Report%20(PDR).pdf?ver=1791463703543
[por]: https://img1.wsimg.com/blobby/go/b3421eb7-36e9-43f7-86b8-17a5786633b2/downloads/63d3363d-5938-438b-9b9a-aa5dc37bd204/2027%20Yearly%20Post%20Officer%20Report%20%20Fillable.pdf?ver=1791463703543
[transmittal]: https://img1.wsimg.com/blobby/go/b3421eb7-36e9-43f7-86b8-17a5786633b2/downloads/Post%20Membership%20Transmittal%202025%20-%20fillable.pdf?ver=1791463703543
[wi-americanism]: https://img1.wsimg.com/blobby/go/b3421eb7-36e9-43f7-86b8-17a5786633b2/downloads/McCoy-%20O.W.%20Rolfe.pdf?ver=1791463698467
