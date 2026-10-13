# Membership workspace

Implemented October 11, 2026. This is the first slice of the
[membership design and National/Department research](MEMBERSHIP_MANAGEMENT_DESIGN.md).

## Who can use Membership?

The **1st Vice Commander** handles membership. The **Commander** and **Adjutant**
also have full membership access. Use these existing offices; a separate
"Membership Officer" position is not needed.

The standard American Legion Post preset supplies this access automatically:

| Person's current authority | Membership access |
| --- | --- |
| Current Commander, 1st Vice Commander, or Adjutant | Full workspace: member follow-up, drive management, dues and Post checks, and Adjutant summaries. |
| Volunteer with an active drive assignment | Assigned members and permitted contact results, drive instructions, and their own call sheets. |
| Other member or historical officeholder | No Membership destination unless another current role, assignment, or manual permission grants access. |
| Application administrator or someone granted **Manage people and accounts** | Full workspace through application permissions. |

Everyone needs an enabled website login account. Holding an office does not create
that account or grant technical administration. Managers open **Menu → Post duties → Officer tools → Membership**. Assigned
volunteers open **Menu → Your work → Your assigned calls**. These destinations
appear only while access is current; direct URLs and the private API enforce the
same boundary.

### Assign or end an officer's membership access

An application administrator manages officer assignments:

1. Open **People** and select the person.
2. Under **Post Roles**, choose **Commander**, **1st Vice Commander**, or **Adjutant**.
3. Enter **Starts on**, then select **Assign role**.

No additional membership permission checkbox is needed for these configured
offices. Access starts on the assignment's start date and remains active through
its end date, using the Post's local date. Use **End role**, or enter **Ended** and
select **Save dates**, to record the end of the term. Historical assignments stay
in the person's record but no longer supply access.

**Menu → Administration → Post positions** controls which offices supply access. The
**Full membership access** marker identifies the configured offices.
**Grant membership access** and **Remove membership access** change the position's
policy for everyone currently holding that position; they do not assign a person
to an office. The application uses this setting and dated assignments rather than
matching an office's display name on each request.

An administrator can also grant **Manage people and accounts** under
**People → person → Login Account → Permissions → Save permissions**. This is a
separate manual grant that remains until removed. Ending a role does not
remove a manual grant, and removing a manual grant does not remove access from
another current role. Use drive assignments for volunteers instead.

Account, role, and permission controls require **Manage app settings**
(`manage_settings`); membership access alone does not supply those controls.
See the [user-management guide](USER_MANAGEMENT_GUIDE.md#membership-access-supplied-by-a-position)
for login eligibility and officer turnover.

## Find members who need attention

Managers open **Menu → Officer tools → Membership → Renewal follow-up**.
Volunteers open **Menu → Your work → Your assigned calls**. The assignment, drive dates,
enabled account, and selected membership year all limit volunteer access.
Closing a drive or revoking an assignment ends assignment-derived access on the
next request; a separate current officer role or manual grant can still supply access.

The landing page is a task directory: **Renewal follow-up**, **Drives**, and, for
managers, **Adjutant report** and **Post checks**. Check-ins and the separate monthly
county count belong in [Buddy Checks](BUDDY_CHECKS_WORKSPACE.md), reached from
**Menu → Your work**. Volunteers open
**Your assigned members** instead of the officer renewal list.

**Renewal follow-up** (or **Your assigned members**) defaults to **Needs attention**. It puts
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

From the member's detail page choose **Record contact or review**. The focused entry
page keeps the actual contact date, channel, result, brief notes, and any agreed callback
date. Phone/email links open the person's device application; they do not send
messages or record a completed contact. Website and text channels can record
contacts that actually happened. There is no automated prompt or SMS sender yet.

### Give a volunteer assigned-member access

A current membership manager can create a drive and assign callers without
technical administration access:

1. Open **Membership → Drives** and choose the membership year.
2. Select **Create membership drive**, enter the drive name, purpose, start/end
   dates, and optional call script, then select **Create drive**. You can also open
   an existing drive for that year.
3. Under **Assign members to a caller**, select the volunteer under **Caller**.
4. Set **Access through** to a date within the drive's start/end dates.
5. Check **Members to assign**, then select **Assign selected members**.

The assignment automatically grants scoped website access. Volunteers do not
need a Post office or **Manage people and accounts** permission. A future drive
does not grant access until its start date. Access lasts through **Access through**,
unless **Revoke assignment**, **Close drive**, or disabled sign-in ends it earlier.

**Caller** lists people with enabled website login accounts, not every person on
the National roster. If a volunteer is missing, an administrator should check
**People → person → Login Account**. For an eligible person without an account,
enter a unique **Login email** and select **Create login account**. Roster-backed
accounts still follow [National roster sign-in eligibility](USER_MANAGEMENT_GUIDE.md#are-members-enabled-or-disabled-by-default).

Every purpose excludes deceased and removed records.
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

### Print call sheets

1. Open **Membership → Drives** and select the drive.
2. Assign members to callers first; the PDF uses those assignments.
3. Near the top of the drive page, choose an individual caller or **All callers**
   under **Call sheets for**. Volunteers have no caller selector and always receive
   only their own permitted assignments.
4. Select **Open call sheets PDF**, then use the PDF viewer's print button or
   **Ctrl+P** / **Cmd+P**.

The finished Letter-size document includes member contact blocks, result choices,
callbacks, and writing space. Expired or revoked assignments are excluded, and
assigned members must need contact now to appear. If no blocks appear, check the
assignments and each member's current next step. Member numbers, mailing addresses,
financial history, and private contact notes are excluded.

### Work from paper and enter returned results

A volunteer can make calls using printed sheets without signing in. An officer
can print the sheets and enter the returned results. **Current limitation:** the
named caller must still have an enabled website account, and assigning their
members also grants scoped website access. There is no separate paper-only caller
option that avoids creating or granting access to a login account.

To enter returned results, open the drive, select the assigned member, choose
**Record contact or review**, record the
actual contact date and result, and enter the block's reference under
**Paper reference (when entering a call sheet)**. This prevents duplicate paper entry.
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
