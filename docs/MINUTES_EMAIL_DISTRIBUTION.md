# Minutes email distribution

The officer workspace's **Minutes distribution** page manages automatic PEC and monthly
minutes email. Commander/Adjutant position authority or `manage_settings` is required;
a draft-editing grant alone does not expose recipient addresses or controls. Changes are
audited and sensitive pages disable caching. Recipients gain no application access.

Automatic minutes emails go only to designated website office entries with an effective
**Minutes recipients** enrollment. They do not go to **Post members**, **Post officers**,
or All audience. A person who also belongs to another list receives minutes only through
their designated minutes entry. Adding a contact to the Loops list alone is insufficient.

## Group ownership

- **Post members** is the private Loops list for general membership campaigns. The roster
  sync owns this list's membership only.
- **Minutes recipients** is a distinct private Loops list for designated outside offices.
  This workflow owns enrollment in that list only. The same list receives both configured
  meeting types.
- Other lists, including Post 165's private **Post officers** list, are not managed by
  either workflow. A website Post role does not automatically populate that list.

For general membership campaigns in Loops, select **Post members** instead of All audience.
Review the audience when creating or duplicating a campaign; the application cannot
enforce that selection in the Loops dashboard. Roster imports do not themselves run a
Loops sync; use **Sync email audience** after reviewing a completed import.

## Post 165 live setup, verified October 19, 2026

Minutes distribution was deployed in [PR #159](https://github.com/AndreRobitaille/LegionPostTools/pull/159)
at `7d60cca71efda7883958f6758530afee3fe21e5d` and activated at 2:54 PM Central.
These are installation values, not application defaults:

| Private Loops list | ID | Live use |
| --- | --- | --- |
| Post members | `cmvfnwl200v3k0jy9atkaga70` | General membership campaigns; roster sync owns its recorded enrollments |
| Minutes recipients | `cmvfnx3n20vfi0jx71z2tfmpg` | Designated office addresses for both meeting types |
| Post officers | `cmvfnxk7o0vxb0jy9ghcd1jh8` | Reserved for future use; no application sync or automatic minutes targeting |

Automatic email and the general-audience review are enabled. Selected meeting types are
**PEC Meeting** (9) and **Membership Meeting** (10). The published transactional template
is `cmvfhh6pj01t60jzj8d0s8mkr`; replies use the configured Organization public email.
Loops support confirmed PDF attachments are enabled. Delivery uses individual messages,
without the optional CC arrangement offered by support.

At activation, three office addresses were enrolled and outside Post members. Roster import
6 had 85 eligible addresses. Sync 6 added 76 and retained nine opt-outs; sync 7 reported
76 unchanged and retained the same nine opt-outs. Both completed with zero failures, and
provider read-back confirmed the minutes recipients and other list memberships survived.
These are dated verification counts; use the website for the current register and results.

The worker, scheduler and 15-minute reconciler were running. No historical distributions
were created and no real emails were sent during activation. Attestation and corrected-copy
flows were tested with an offline provider; actual inbox delivery was not tested.

## Manage minutes recipients

Open **Officer tools → Minutes distribution** (or the Administration shortcut). Current
Commander/Adjutant position authority or **Manage app settings** permits these controls;
minutes drafting permission alone does not. Keep the recipient register on this page,
rather than adding contacts only in Loops:

1. Expand **Add an office**, enter the name, office and email, and choose **Add office entry**.
2. Choose **Enroll address in Loops** on the active entry. Confirm the result is **Enrolled**.
   An opt-out or provider error needs review; enrollment does not override email choices.
3. Use **Pause** when an office should stop receiving minutes. **Resume** restores its local
   designation, subject to its current enrollment and provider choices.
4. To replace an officeholder or address, use **Edit office entry → Save entry**, then enroll
   the changed address explicitly. Pause the old entry first when replacing it with a new
   entry. Neither approach redirects already-recorded deliveries to a successor.
5. Inspect **Recent mailings → Delivery results** for per-address outcomes. **Sent to Loops**
   means provider acceptance, not confirmed inbox delivery or reading.

An office entry contains a name, office, address and active state. Two offices held by the
same person can use different addresses and both receive minutes. Two entries sharing a
normalized email remain separate in the website but receive one message per mailing.
Pausing an office stops its authorization; another active original office entry can still
authorize the shared address. Pause does not erase Loops subscription history. Editing an
address clears its saved provider identity and requires explicit enrollment for future
mailings. It does not redirect queued historical mail.

Adding a website entry does not itself contact Loops. **Enroll address in Loops** explicitly
patches only Minutes recipients, preserves existing contact identity/profile and global
subscription choices, then reads back the effective result. A contact added only in Loops
does not authorize sharing PEC records outside the website's register. List opt-outs,
global opt-outs, missing identities and suppression stop transactional delivery as well.
No contact is deleted, recreated or unsuppressed to obtain delivery.

Recipients added after a meeting's first mailing apply to future meetings' initial mailings.
Corrected copies retain the original destinations and recheck their current authorization;
new entries are not added to an existing meeting's correction chain. These recipient and
delivery controls are website-only; a delegated API attestation uses the same sending rules.

## Delivery settings and email wording

The normal page shows saved settings. Choose **Edit delivery settings** to change the
meetings, address for replies or automatic sending, then **Save delivery settings**.
**Cancel** discards unsaved changes. **View Loops connection details** exposes the saved
technical IDs without making them editable. The existing restriction on changing list
connections after enrollments or mailings remains in force.

Under connection setup, “I checked that regular Post emails in Loops use the Post members
list” records a human review. It does not retarget emails in Loops. For regular membership
email, select Post members in Loops; All audience also includes outside minutes contacts.

Choose **Edit email wording** to change the subject and short cover note on this page.
Select a field, then choose a variable button to insert at the caret:

| Variable | Filled-in value |
| --- | --- |
| `{{post_name}}` | This Post's name |
| `{{meeting_label}}` | The minutes' meeting title |
| `{{meeting_date}}` | The meeting date |
| `{{copy_label}}` | Minutes or Corrected minutes |

The subject must keep Copy label so corrected copies are identifiable. Unknown or incomplete
variables and subject line breaks are rejected without losing the entered text. The example
preview updates as wording changes and can show a first or corrected copy; it sends no email.
The greeting, signature, approval status and corrected-copy notice are added automatically.
The status always follows the minutes, including approval when recorded.

**Save email wording** captures changes for future attestations. Each attestation records
its wording with its distribution; later edits cannot change that queued copy or its retry.
A future corrected attestation uses the wording then in effect, but unchanged minutes still
send no duplicate merely because wording changed. Older distributions retain their original
standard wording. Editing wording does not change the minutes or the PDF.

Both editors reject stale forms rather than overwrite another officer's changes. If the
page says the settings changed while editing, use **Reload latest settings** before saving.
Wording and delivery choices are saved separately and all changes retain officer audit
provenance. The Loops delivery template ID remains a separate technical connection; the
existing published template still receives `subject` and `cover_note` from this application.

## Attestation and corrections

The existing human attestation confirmation states the external-mail consequence. The
attestation transaction records a distribution and its initial destination snapshots;
PDF generation and provider requests run afterward in Solid Queue. The new email request
coexists with PR #158's Endeavor History requests and does not change their authority or
recovery. This feature does not invoke an AI provider.

- Initial Adjutant attestation queues the configured meeting's attested PDF and short cover
  note. The note names the actual approving body and says approval is pending and corrections
  may be made at its next meeting.
- Drafting, Commander handoff and reopening do not send mail. New recipients apply to future
  initial mailings, without historical backfill.
- Re-attestation sends again only if the visible document content differs from that address's
  last successful submission. The comparison includes heading, date/place, attendance,
  narrative, ordered sections and motions/decisions, excluding internal links, authority
  metadata and insignificant editor wrappers/whitespace. It uses versioned deterministic code.
- Confirmation of adopted corrections can attest and lock the final corrected text in one
  action. Its mailing accurately says that the corrected copy is approved.
- Unchanged re-attestation and approval without changed text do not send another copy.
  Partial delivery and an A → B → A correction sequence are tracked per destination.
- A newer attestation replaces unattempted older work. Unknown older submissions are resolved
  using their original keys before newer content goes to that address. Other eligible
  addresses can proceed independently.

The attachment reuses the officer document's closing **Record of authority** and the normal
PDF resource policy. A signed loopback source selects the distribution's immutable revision,
captured letterhead and approval context, including after the working record is reopened.
This does not grant members general access to superseded revisions. Approval before the
first submission refreshes authority; after submission begins, the PDF bytes, cover variables,
filename and template selection are frozen. The private stored PDF has a SHA-256 digest.

## Holds, retries and delivery results

A meeting can be held with a reason before or after attestation. Holding email never changes
or approves the minutes. Global pause holds unsent mail; resuming does not release a backlog.
An officer explicitly releases the current recorded copy after review.

A delivery's committed submission marker and idempotency key survive worker interruption.
Dispatch is serialized per minutes record with a PostgreSQL session advisory lock; no network
request lives inside the database transaction that records the submission marker. Queue
reconciliation recovers recorded pending work every 15 minutes and invents no historical
mailings. Recipient designation and current provider choices are checked again before sends.
A local pause or address change during provider lookups is rechecked under lock at dispatch.
An unresolved outcome holds only that destination; healthy addresses can receive current
corrected minutes independently. A missing submitted PDF is held rather than regenerated.

A retry reuses the exact saved payload and key. Automatic submission attempts are bounded,
and uncertain outcomes stop before the provider's 24-hour key window expires (the application
uses 23 hours). An officer reviews **Needs attention** in Loops, then records whether the
message was sent. Verified non-delivery can retry the current copy with a new, audited key;
an obsolete copy is superseded instead. A verified sent result permits current corrected
work to proceed. These actions require current management authority.

**Sent to Loops** means the provider accepted the request, not that the recipient read it
or that inbox delivery is proven. Failures leave the human attestation intact. Oversized
requests are held; the complete JSON including base64 PDF must be below 4 MB.

## Installation and rollout

Settings start paused and no recipient contacts are seeded. Before activation:

1. Create distinct private Loops lists, then save their IDs on Minutes distribution.
   Roster sync and minutes jobs verify both exist and are private; there is no All audience
   fallback. Once there are recorded enrollments or issues, changing list IDs needs an
   operator migration rather than silently moving subscriptions.
2. Backfill Post members using the reviewed roster sync. Retarget general campaigns,
   scheduled sends and contact-added workflows to Post members. Confirm that review on
   Minutes distribution before enrolling outside contacts. The application cannot prevent
   someone manually selecting All audience in the Loops dashboard.
3. Have Loops enable transactional attachments. Create a transactional template whose subject
   uses `subject`, whose greeting uses `recipient_name`, whose body uses `cover_note`, and
   whose sign-off uses `post_name`. Available additional variables are `meeting_label`,
   `meeting_date` and `reply_to`. Use the configured monitored address in the template's
   Reply-to setting. The attachment is supplied by the application, not a public link.
4. Save the template ID and monitored reply address. Select the installation's PEC and
   monthly meeting types by ID; names and Post numbers are not hard-coded.
5. Add and explicitly enroll the designated office entries. Inspect read-back opt-out results.
   Verify attestation and corrected-copy flows with a fake provider. Any live test email
   requires explicit authorization; Post 165 activated without sending a real test email.
6. Ensure the Solid Queue worker and recurring reconciler run. A worker rendering PDFs must
   reach this installation's web service through `PDF_RENDER_PORT` (default `PORT` or 3000)
   on loopback. Do not point it at another application's listener. Chromium is already a
   runtime dependency of meeting PDF delivery.

`LOOPS_API_KEY` remains the existing account credential. No live lists, templates, contacts,
scheduled campaigns or installation settings are provisioned by the migration. Deployment
and live activation remain separate operator actions.

## Verification entry points

- `test/services/minutes_distribution/` covers content, roster coexistence, distribution,
  queue interruption, paused/changed identity, opt-outs and offline provider failures.
- `test/controllers/minutes_distributions_controller_test.rb` covers the real attestation
  confirmation request, saved intent and later status reads, management authority, officer
  turnover, holds, explicit release and reviewed uncertain outcomes.
- `test/controllers/minutes_distribution_pdf_test.rb` checks exact frozen source, approval
  context, loopback/token boundaries and continued member revision restrictions.
- `test/system/minutes_distribution_test.rb` checks the real rendered workspace at desktop,
  390px and 320px, plus worker-produced Chromium PDFs and corrected-copy attachment payloads
  using an in-memory provider. It sends no real email and makes no paid AI calls.

See [the approved design](MINUTES_EMAIL_DISTRIBUTION_DESIGN.md),
[roster sync](LOOPS_ROSTER_SYNC.md), [attestation policy](MINUTES_APPROVAL_AND_ATTESTATION.md)
and [PDF delivery](PDF_DOCUMENT_DELIVERY.md).

## Local verification, October 19, 2026

The following records the pre-deployment local verification, based on `e40df49` / PR #158.
It is separate from the subsequent Post 165 live activation recorded above:

- `PARALLEL_WORKERS=4 bin/rails test`: 1,619 tests, 16,882 assertions, zero failures,
  errors or skips. All expected tests completed and the command exited 0. Restricted-home
  Bundler emitted temporary-directory cleanup warnings when forked workers exited; these
  did not change the test results. No application workaround was introduced.
- Browser run covering `minutes_distribution`, `loops_roster_syncs`,
  `minutes_approval_flow`, `official_action_prefetch` and `meeting_documents`: 9 workflows,
  411 assertions, zero failures, errors or skips. Rails system tests run separately from
  the ordinary suite. Real Chromium PDFs used an in-memory email provider.
- RuboCop: 682 files, no offenses. Brakeman: no warnings. Bundler Audit: no vulnerabilities.
  Zeitwerk eager-loading check passed. Changed documentation links and diff whitespace
  passed review.
- During those local checks, the development/production databases, live Loops account and
  real mail delivery were not used. Only the test database was migrated; that local run
  did not deploy production.
