# Membership workspace

Implemented October 11, 2026. This is the first slice of the
[membership design and National/Department research](MEMBERSHIP_MANAGEMENT_DESIGN.md).

## Access and the member record

Open **Membership** from the navigation or Menu. Current full-membership officers
and people with `manage_people` can manage the workspace. A volunteer sees this
destination while they have a current assignment to an available roster member.
The assignment, drive dates, enabled account, and selected membership year all
limit volunteer access. Closing a drive or revoking an assignment ends access on
the next request. Holding a historical office does not preserve officer access.
The destination is absent from both the desktop navigation and Menu for people
without that current authority; direct URLs use the same access policy.

The landing page is **Member follow-up**, defaulting to **Needs attention**. It puts
due callbacks first, followed by membership records to review, payment confirmation
for officers, and renewal follow-up. Paid renewals, paused contact, declined renewal,
future callbacks, and completed welcome/Buddy Check contacts stay out of this view.
Deceased and removed roster records never appear as contact or review tasks, even
with an earlier callback or receipt. Officers can find their preserved history in
**All members**, with the reason for no outreach and no phone/email actions.
Choose **All members** (or **All assigned members**) to find them. Each row identifies
the next step and callback date. The **Drives**, **Adjutant report**, and **Post checks**
pages have their own tasks and preserve the selected membership year.

Choose the membership year explicitly. The initial selection is the next year
from July onward, otherwise the current year, using the Post's timezone. Each
volunteer starts in an active assigned year when they have no assignment for the
usual renewal year. A drive's detail and PDF use that drive's year. Each
member shows three separate lines: National record, Post renewal work, and next
step. An expired or removed National record is not repaired by a local receipt.
Login access continues to follow the existing roster rules.

## Dues received here and members who pay National

On a member's page, record **Full-year dues received by the Post** with the amount,
actual receipt date, and receipt reference. This pauses repeated payment requests
while the National roster remains unconfirmed. It does not transmit dues. Follow
the Post's established Department/MyLegion processing procedure, then import the
updated National roster. Local receipt history stays available after confirmation.

When the member reports renewing on National's website, record **Reports paid
through National** during outreach, or select **Member reports paying National**
in the dues register and leave the amount blank. The worklist marks this for
verification. The imported National record supplies confirmed standing.

When the Post later receives its check, open **Post checks**. Enter the amount
actually received; this register does not calculate
an expected check or allocate it to individual members. Check receipt does not
determine whether a member renewed.

Saved entries retain their original actor and contents. Use **Correct this entry**
to reverse a mistaken financial entry with a reason, then record a replacement.
The original and reversal stay visible; reversed entries leave effective totals.
Retrying the same form does not create another entry. A new form is a new observed
receipt, so check existing history before entering a receipt again.

## Calls, drives, and paper results

Record the actual contact date, channel, result, brief notes, and any agreed callback
date. Phone/email links open the person's device application; they do not send
messages or record a completed contact. Website and text channels can record
contacts that actually happened. There is no automated prompt or SMS sender yet.

Open **Drives** and create a drive with its purpose, dates, and script, then select members and a caller
with an enabled account. Every purpose excludes deceased and removed records.
Renewal candidates also omit paid members, payments awaiting verification, unclear
standing awaiting officer review, declined renewal, paused contact, and future
callbacks. Expired members can still need renewal help. Welcome and Buddy Check purposes are
separate; Buddy Checks cannot record dues solicitation outcomes. Volunteers can
record contacts for their assigned members, see their own recent results (including
officer transcription or review of their assigned calls), and print their own
current assignments needing contact. Fresh PDFs recheck each member's next step
and omit completed or deferred work. They cannot see financial history, another caller's notes,
or separate individual officer notes. Officers see all work and can transcribe
returned sheets, including sheets for expired or revoked assignments.

**Open call sheets PDF** produces a finished Letter-size document with member
contact blocks, result choices, callbacks, and writing space. Officers can choose
a caller; volunteers always receive their own permitted selection. Member numbers,
mailing addresses, financial history, and private contact notes are excluded.
Enter each block's reference when transcribing it to prevent duplicate paper entry.
The selected assignment identifies the caller; the signed-in person is separately
recorded as the recorder. Actual contact dates determine ordering, so entering an
older sheet does not replace a newer result or callback. A paper result from the
same day also preserves the digital next step, since the sheet does not establish
which contact happened later. An officer can choose **Officer review of a recorded
result**, enter an explanation and the confirmed next step, and leave the paper
reference blank. This records a review rather than claiming a new call occurred.

**Do not contact for this purpose** pauses that purpose across membership years
and roster imports. Only an officer can restore permission, with a reason. Other
purposes remain separate. Officers can enter a returned sheet while contact is
paused; recording that history does not restore permission. Downloaded paper
cannot be revoked: check the current
worklist before calling and return completed sheets to the drive lead. Contact
actions appear only when contact is needed now for the selected purpose. Officer
verification of a payment is not another renewal request. A new deceased/removed
status rejects stale contact submissions, including completed API retries. Officers
can still record an administrative review or transcribe returned paper history;
these entries do not restore outreach eligibility.

## Adjutant summaries and reports

The separate **Adjutant report** page explains today's confirmed renewals,
dues received here, claimed online payments, unpaid members, contact pauses, and
records needing review. Deceased and removed records have a separate historical
count and are excluded from outreach. Each count includes its definition. It also reports
recorded dues/check totals for the selected year. Its roster source date and stale
warning accompany the figures. **Save today's Adjutant summary** freezes those
figures and sources with the preparer and capture time; later imports or corrections
do not rewrite it. Saved summaries have a printable PDF.

These are working summaries, not certified Department counts, Post Excellence
certifications, or reconstructed historical retention. Partial payments, remittance
batches, member self-report prompts, award evidence/checklists, and CPR/PDR/officer
report prefill remain later slices. POR/PDR/CPR editions and local dues processing
still need confirmation from the Post's actual procedure.

## Private API

The existing officer-only roster API remains unchanged. The permission-filtered
`GET /api` handbook advertises these additional operations to current officers and
assigned volunteers:

| Operation | Route |
| --- | --- |
| Worklist and permitted drives | `GET /api/membership/workspace` |
| Member work, assignments, recent contacts | `GET /api/membership/workspace/people/:id` |
| Append an observed contact | `POST /api/membership/workspace/people/:id/contacts` |
| Drive script and permitted assignments | `GET /api/membership/workspace/drives/:id` |
| Finished private call sheet PDF | `GET /api/membership/workspace/drives/:id/print` |

Use `membership_year=2027` (or the actual chosen year). Contact writes use
`membership_contact` containing a unique `submission_key`, `occurred_on` (ISO date),
`channel`, and `outcome`; volunteers also require `membership_assignment_id`.
Callbacks require `follow_up_on`. Returned sheets include `paper_reference`.
The `administrative_review` channel and `contact_permission_restored` outcome
require current officer authority and explanatory `notes`, including on retries.
Member responses include `next_step`, `needs_attention`, and `outreach_needed`.
Phone/email values are omitted when contact is not needed for the selected purpose;
deceased/removed records remain officer-only history with `work_state=no_outreach`.
Member responses identify `contact_purpose`; their `contact_paused` and contact
links apply to that purpose. Pass `assignment_id` when opening a member from a
particular drive. A renewal opt-out does not suppress an independently permitted
Buddy Check. Changing a write's membership year requires fresh submission and
idempotency keys.
Bearer writes additionally require `Idempotency-Key`; exact retries reuse both keys
and recheck live authority. Lists accept `limit`/`offset` (maximum 500 members).
Website cookies and personal bearer tokens share the same policy. Officer drive
management, finances, and saved summaries currently use the signed-in website.
All workspace responses and PDFs are private and use `no-store`.

## Validation

Focused service/integration tests cover separate dues and National standing,
National self reports and Post checks, frozen summaries, reversals, duplicate forms,
returned paper ordering, callbacks, opt-outs, purpose boundaries, and current
assignment/role/account authority. Worklist checks cover default exclusions,
explicit all-member access, due callbacks, and distinct payment-verification actions.
Navigation checks cover both the desktop links and Menu, ordinary-member denial,
assignment closure, and officer turnover. Browser tests use synthetic members through real
magic-link sign-in at desktop and 390px widths, and fetch real Chromium PDFs for
pagination, complete blocks, Letter sizing, margins, and caller scoping. These are
local test results; no live member data or external delivery has been exercised.
