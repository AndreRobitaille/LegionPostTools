# Automatic distribution of attested minutes

Design proposal, revised October 19, 2026. Repository inspected at `059661f`.
This is the approved design. The local implementation is described in
[Minutes email distribution](MINUTES_EMAIL_DISTRIBUTION.md); live Loops setup and activation
remain operator work.
This revision replaces the earlier recommendation to wait for meeting approval and keep
outside recipients out of the Loops audience.

## Confirmed product decisions

- Use an explicit **Post members** group in Loops for general membership mail. Stop
  addressing campaigns and membership automations to the entire audience.
- Keep a separate **Minutes recipients** group for designated county/district and other
  leadership recipients. The same people receive PEC and monthly membership minutes.
- Keep separate recipient entries for separate offices. Nancy's county and district
  addresses may both receive copies; do not consolidate them because one person holds
  both offices. Todd and newsletter delivery are outside the current scope.
- Send after Adjutant attestation, without waiting a month for the later approval vote.
- Include a short cover note and the attested PDF. Clearly say that the relevant meeting
  body has not yet approved the minutes and may make corrections at its next meeting.
- Preserve the document's existing closing status/authority block. Do not invent an
  additional approval ceremony or a prominent warning treatment.
- Send again only when corrected content is attested. Unchanged meeting approval alone
  produces no second email. Determine changes with ordinary deterministic code, with
  no AI calls, AI summaries, or judgment about whether a correction is important.
- The roster-import **Sync email audience** action must coexist with these groups,
  preserve opt-outs, and leave external recipients and unrelated subscriptions intact.

Attestation and meeting approval keep their existing meanings under
[Minutes approval and attestation](MINUTES_APPROVAL_AND_ATTESTATION.md). Emailing an
attested copy does not make it a final approved record or give recipients authority
inside the application. Accepted final minutes remain immutable.

## What the supplied correspondence establishes

Andre supplied the October 18 email exchange with Nancy Rivera, subject **Agendas and
minutes**. Nancy describes sending newsletters and meeting notifications/agendas to
county and district leadership. She identifies herself as both County Commander and
District Vice Commander, and identifies the District Commander. She accepts either her
existing district address or the county address for the correspondence. The CVSO contact
is explicitly **newsletter only**.

Andre subsequently clarified that both of Nancy's addresses may receive minutes, keeping
her county and district offices as separate entries in the website. This supersedes the
earlier recommendation to select one address per person. The Post has no newsletter;
exclude Todd, the newsletter-only CVSO contact, from the current recipient setup and do
not add newsletter groups or automation as part of this feature.

The correspondence is context, not a directive to import contacts or send messages, nor
an explicit request by every named person to receive PEC minutes. Andre's designation
of the minutes list remains the authority for this feature. Do not copy the supplied
addresses, phone number, or correspondence into fixtures, this repository, or the mockup.
Meeting-notice and agenda automation also remain outside this minutes implementation.

## Loops audiences and ownership

Use private Loops mailing lists for these groups, identified by configured IDs. Contacts
can belong to multiple lists. Avoid using the single `userGroup` string as an exclusive
role: one address may legitimately be both a Post member and a designated recipient.
The app remains configurable for other American Legion posts.

| Mailing purpose | Group | Maintained by |
| --- | --- | --- |
| General membership mail | Post members | Roster sync, respecting recipient choices |
| Attested PEC and monthly minutes | Minutes recipients | Designated officers through the minutes-recipient workflow |

Convert existing general campaigns, scheduled sends, and contact-added automations to
Post members before adding outside recipients. New campaigns use an explicit named
audience. List targeting is an operating rule in the Loops dashboard; do not claim that
Rails prevents a human from selecting All audience there. App-owned sends must fail
closed when their required group ID is absent or invalid, never fall back to all contacts.

## Roster synchronization contract

Current source and [the existing roster sync contract](LOOPS_ROSTER_SYNC.md) update only
email, parsed names, and `american-legion-member:<member_number>` identity. The current
payload omits `subscribed`, `userGroup`, and `mailingLists`, and the tests assert those
omissions. It does not currently populate a Post members list or remove former members
from one. The following is a deliberate, narrow extension of that contract.

**Roster sync may manage only the configured Post members list.**

1. Keep current eligibility: National-roster-backed, present in the latest roster,
   Active or Grace, valid unique email. Preserve separate counts for missing, malformed,
   and shared addresses, and refuse a preview superseded by a newer import.
2. For an eligible contact, update roster identity and patch only the Post members list
   key. Do not send a replacement map containing every list, copy a stale list snapshot
   back to Loops, or set `userGroup`.
3. Omit global `subscribed` on routine writes. Never resubscribe, delete/recreate, or
   unsuppress a contact to make synchronization succeed. Respect list-level opt-outs
   too. Loops documents that recipient list opt-outs cannot be overridden by team/API
   enrollment; read back effective enrollment and report retained opt-outs truthfully.
4. Track which contacts/addresses the integration has enrolled. Preview removals from
   **only Post members** when those previously managed addresses become ineligible.
   Retain their Loops contact and all other lists. This is a new reconciliation behavior
   and must be described on the existing sync preview before the officer starts it.
5. Do not sweep the entire Loops audience as though everyone were a roster member.
   Initial backfill uses current eligible roster records. Review any pre-existing
   Post members assignments without integration provenance rather than guessing.
6. Do not report a skipped shared/invalid address as proof that an old enrollment was
   removed. Previously managed destinations need an explicit reconciliation outcome.
7. Resolve identity by both the stable member ID and the proposed email before changing
   an established address. Loops can match either identifier and update the other. Flag
   conflicting contacts, reused/shared mailboxes, or an address move that would silently
   move independently managed subscriptions. Do not merge people or overwrite another
   workflow's `userId` to get past a conflict.
8. Preserve current bounded rate-limit handling and per-contact results. Show actual
   additions, removals, unchanged contacts, retained opt-outs, identity conflicts, and
   failures. A partial run must not be labeled a fully reconciled group.

The minutes workflow patches only its own list key and never assigns a National member
ID. For an existing contact, preserve its identity/profile fields; use the app's chosen
recipient name and office in the cover note. Names for new outside contacts can be set
at explicit enrollment. Neither workflow may remove the other's list membership.

Use one account configuration that requires the Post members and Minutes recipients IDs
to be distinct and verifies that both exist. Test sparse update behavior at the provider
boundary before rollout. Update `LOOPS_ROSTER_SYNC.md` and its existing tests alongside
implementation; do not leave a documented promise that list membership is never touched.

## Recipient selection and the sending mechanism

Maintain a small app register of designated recipient entries with name, office, email,
Loops contact identity, and active/paused state. Separate offices may have separate
entries and addresses even when held by the same person. Mirror explicit
enrollment in the private Minutes recipients list. The register supplies known candidate
addresses and an audit trail; membership in Loops supplies the current subscription
choice. A manual addition in Loops alone does not silently authorize sending PEC records
outside the application's designated register.

Deduplicate each mailing by normalized destination email, never by a person's name.
Two designated office addresses for the same person receive two copies. If two active
office entries share the same address, retain both entries but link the same Loops contact
and send one copy. Pausing or removing one such entry must not remove enrollment while
another active designation still uses that address. Delivery history and retry identity
belong to the destination, with the authorizing office entries recorded for audit.

Before each send or retry, require the app designation to remain active, the destination
to match its saved identity, the Loops Minutes recipients membership to be present, and
provider subscription/suppression checks to allow sending. Unknown state or lookup failure
holds delivery. Removing list membership in Loops must stop sending; a later roster sync
or routine contact edit must not add it back. A change to one recipient's email does not
redirect queued historical mail without review. Store only the necessary contact data.

Continue to use a Loops transactional template for the PDF attachment, sending one
message per destination. This is a transport choice; audience organization remains in
Loops. Requests set `addToAudience: false` because explicit enrollment already created
or linked the contact. Transactional delivery does not enforce mailing-list preferences
itself, so the checks above are mandatory; never fall back to direct sending to a missing,
unsubscribed, or suppressed contact. One recipient cannot see other recipients' addresses.

Keep the content to the designated administrative record. General membership announcements
use campaigns targeted to Post members. Provide a monitored reply-to
for requests to stop or change delivery; staff can pause a recipient and record the
request. Native marketing unsubscribe behavior must not be assumed for transactionals.

## Attestation and corrected copies

| Record action | Distribution behavior |
| --- | --- |
| Drafting or Commander handoff | No email |
| First Adjutant attestation | Queue the attested revision after commit |
| Draft reopened or corrected while still editable | No email |
| Corrected content re-attested | Send the corrected copy to eligible original recipients |
| Re-attestation with unchanged document content | No repeat copy to recipients already sent that content |
| Approval as presented or another unchanged approval | No second email |
| Approval with corrections still to enter | Wait for corrected text to be attested |
| Adjutant confirms corrections and locks the final copy | Send if content changed; use approved status when applicable |
| New recipient or later activation | Future initial mailings only; no automatic archive/backfill |

Configure the existing PEC and monthly membership meeting types by IDs and their meeting
bodies. Do not infer eligibility from mutable names, month strings, or the existing
`default_distribution` hint. Special meetings remain outside the initial selection.

Capture the exact attestation/revision in the same database transaction as attestation.
Handle both ordinary attestation and correction-confirmation paths: the latter immediately
reaches `membership_approved`. A trigger checking only a transition to `attested` would
miss it. Commander handoff also creates revisions, so a new revision alone is insufficient.

### Detect changes without AI

`MeetingMinutes#revision_payload` already contains the saved heading, meeting date/place,
attendance, ordered sections/items, rich-text narratives, and motions/decisions.
`MinutesRevision#sha256` already fingerprints that payload. Attestation and meeting approval
metadata live in separate records, so an approval click does not change the narrative.

Use a deterministic document-content comparison for mailing eligibility. Include the
reader-visible fields and order; exclude internal linkage IDs (`record_key`, `endeavor_id`,
`source_dated_agenda_item_id`) and authority metadata. Convert sanitized rich text into a
stable representation of visible text and paragraph/list boundaries, normalizing editor
wrapper differences and insignificant whitespace. Preserve punctuation, words, numbers,
and meaningful order. Version this projection and test it against the actual PDF fields.
Do not compare PDF bytes, timestamps, revision numbers, or merely the existence of a new
revision; each can change without a textual correction. Keep the original revision/digest
unaltered for record integrity.

Compare with the last content successfully submitted for each recipient, not a global
"ever sent this hash" flag. This handles partial failures and a genuine A -> B -> A
correction sequence. Each attestation has at most one automatic distribution intent;
retries cannot create another. If an earlier copy has not gone out when a newer attested
copy becomes available, supersede its unsent work and send the current copy once.

Corrections go to the initial recipients who remain designated and subscribed. Do not
silently add newly registered contacts to old meetings. Recipients whose original send
failed receive the latest eligible version; successful recipients receive another only
for changed content. Record skipped/unchanged/superseded outcomes as well as attempts.

## Cover note and PDF

Use this short initial message, with a body-specific label:

> Subject: {post_name} — {meeting_label} minutes — {meeting_date}
>
> Hello {recipient_name},
>
> Attached are the minutes of our {meeting_label} meeting held on {meeting_date}.
> They have been attested by the Adjutant but have not yet been approved by the
> {approving_body}; corrections may be made at its next meeting.
>
> {post_name}

For membership minutes, `{approving_body}` is "membership"; for PEC minutes it is the
PEC, not the membership. The subject need not label the document "official" or "approved".
A corrected mailing begins **Corrected minutes** and briefly says that it replaces the
earlier copy. Its status sentence reflects whether that corrected revision is awaiting
approval or already approved. The application derives these facts; no generated summary.

The current officer document ends with **Record of authority**, including Status,
Attested, Meeting approval, Source, and Revision. Its footer also shows the lifecycle
status. Preserve those elements and their existing restrained design. The member document
uses a different attestation/details presentation; ensure the attached PDF preserves the
closing block Andre identified rather than accidentally switching document variants.

Bind the PDF to an explicit immutable revision and captured authority context. The current
renderer defaults to live `current_revision`; its explicit member-revision route requires
that revision still be member-visible. Neither is sufficient for a durable email issue
that may render after a reopen or subsequent attestation. Add a distribution-specific,
loopback-only signed render source using the existing document shell and resource policy.
Do not weaken normal member access to historical revisions or expose the rendering token.

Freeze the selected copy's status/attestation/approval context, post letterhead, filename,
cover variables, template version, and generated PDF once prepared. Store the PDF privately
with its hash; retries use the same bytes. Supersede obsolete unsent content before sending.
If approval occurs while an initial email is still preparing, resolve it before the first
submission so the cover and PDF agree with the selected issue's status. Already issued
copies remain historical evidence of their status when issued; later approval does not
rewrite those PDFs or cause a second mailing. Check this race explicitly in implementation.

Keep transcripts, AI evidence, private drafting notes, and application controls out of the
attachment. Use the existing Letter layout under [PDF delivery](PDF_DOCUMENT_DELIVERY.md).
No public download route, member login, new disclaimer block, or AI call is needed.

## Officer interface and authority

Provide **Minutes distribution** in the officer workspace, linked from the minutes page.
Show the two Loops groups and their purposes, one shared minutes-recipient list, the
attestation trigger, and the email preview. Show each office entry separately, including
its address, even when the same person holds multiple offices. On the roster sync screen show **Updates Post
members only. Other email groups and opt-outs are preserved.** State the effective results,
including anyone skipped or needing identity review.

On the minutes page, keep **Minutes email** beside the existing record workflow. Before
attestation: **Will email 4 recipients after attestation**. Afterward: **Preparing PDF**,
**Queued**, **Sent to Loops**, or **Needs attention**, with relevant actions next to the
status. After unchanged approval: **No new email needed — the text is unchanged**. During
corrections: **The earlier copy was sent; corrections will be emailed after attestation**.
Count distinct eligible destination addresses, not people or office entries. A provider
acceptance is not proof of inbox delivery or readership.

A per-meeting hold with a reason affects mailing only. Global pause stops unsent mail;
resuming shows held work rather than silently releasing an old backlog. No extra Send
confirmation is added to normal attestations once automatic distribution is enabled.
The existing attestation confirmation must state that this copy will also be emailed
to the designated outside recipients, with their count and a route to review them.
Keep that consequence in the existing confirmation rather than adding another step.

Management follows current Commander/Adjutant position-derived authority or
`manage_settings`, checked on each request. Draft-editing grants alone do not authorize
external distribution. Keep organizations isolated, addresses/history private, and
sensitive pages/PDFs no-store. Recipients gain no application access. Officer turnover
does not cancel the organization's saved sending policy, but former officers lose management
access. Contacts removed or paused before dispatch do not receive queued mail; submitted
mail cannot be recalled. A held meeting may be sensitive: do not automatically redact
or summarize its attested content as a substitute for the hold.

## Reliability and implementation boundaries

Use Rails/PostgreSQL records, Solid Queue, and private Active Storage attachments. Store
organization configuration, designated recipients, distribution issues tied to attestations,
and per-recipient delivery attempts with stable idempotency keys. Write durable intent in
the attestation transaction; enqueue and render only after commit. A reconciler recovers
committed unscheduled intents and does not invent mailings for historical minutes.

Retain per-recipient success across partial failures. Loops send idempotency currently
lasts 24 hours: reuse the same persisted key within bounded retries, inspect the documented
duplicate-key response, and put ambiguous outcomes beyond that window into **Needs checking**.
An intentional resend is a separate audited action. The existing magic-link backend creates
a fresh key per call, so extend the delivery seam carefully without changing sign-in behavior.

Loops must enable attachments on the account. Check the complete serialized request against
its under-4-MB limit including base64 expansion. PDF/provider/queue failures leave attestation
intact and appear for officer attention. Verify that a background worker can reach the
existing loopback rendering service without exposing it publicly. Provider webhooks and
confirmed delivery tracking can follow later; first release reports **Sent to Loops**.

## Visual direction and rollout

Follow [The 1919](superpowers/specs/2026-07-11-visual-design-system-design.md): navy
`#0A2240`, gold `#C6A15B`, cream `#F4EEDD`, paper `#FBF7EC`, green `#3F6B3F`, and attention
red `#8C1622`. Use system sans for working screens and Georgia for the existing document.
Body/actions stay at least 16px, secondary text 14px, labels 13px; bounded panels and
44px touch targets stack at 390px/320px. The signature is the adjacent record/email status,
with named group ownership visible at the sync action. Avoid a separate campaign dashboard.

Roll out group separation before automatic minutes: configure and verify distinct lists;
backfill Post members with a reviewed roster sync; retarget existing general sends and
contact-added workflows; then enroll designated outside contacts, test a synthetic PDF
with explicit authorization, and enable future attestation-triggered mail. Do not activate
sending or import the supplied addresses merely by completing this design.

## Required verification

- Exercise initial attestation, ordinary/corrected approval, same-content re-attestation,
  changed-content re-attestation, and denial/stale authority. Verify saved intent, exact
  PDF content/status, visible results, and later reads. Prove no AI provider invocation.
- Verify comparison detects a changed word, vote count, attendance, or heading; ignores
  only authority/internal-link/editor-wrapper changes; handles A -> B -> A, partial
  success, and new/removed recipients without duplicate or historical enrollment.
- Run the full sync-to-email sequence using synthetic member-only, minutes-only,
  unrelated-list-only, overlapping, unsubscribed, suppressed, and shared-email contacts.
  Sync twice and read provider state after each: only the owned list may change.
- Verify two office entries for one person with different addresses both receive minutes;
  two office entries sharing one address receive one copy. Pausing one shared-address
  entry preserves delivery through the other active entry. Counts and retry history must
  reflect destination addresses, while the interface retains separate office entries.
- Verify former-member removal affects only Post members; address/member-ID conflicts
  require review; sparse writes preserve all other lists even with concurrent edits.
  Simulate provider list opt-out, missing/identical list IDs, lookup failure, a newer
  roster import, and partial sync. Never select All audience as fallback.
- Test rollback, queue interruption, concurrent workers, PDF failure, oversized payload,
  429/rejection/timeout, stable retry keys, and unknown outcomes after 24 hours.
- Render real worker-produced PDFs after reopen/re-attestation/approval and inspect the
  exact revision and closing authority block. Confirm the normal member-access boundary
  remains intact. Inspect desktop/390px/320px screens and an authorized synthetic inbox.

At the design stage, work was read-only against application data and Loops. Evidence consisted of
repository source/tests inspected, the supplied one-page PDF read visually and as text,
and current provider documentation. Automated Rails tests, live list semantics, actual
account configuration, and production delivery remained implementation verification work.
The revised synthetic preview was checked at 1024px, 390px, and 320px. Recipient pause/
resume, automatic-send pause, navigation, unchanged-approval status, corrected-copy text,
and pending-correction status behaved as expected. Narrow views had no horizontal overflow
and the browser reported no script errors. Four relative document links, whitespace, and
preview JavaScript syntax passed their checks. These are design/prototype checks, not
application workflow or live provider evidence.

## References checked October 19, 2026

- [Loops list management](https://loops.so/docs/contacts/mailing-lists): purpose-specific
  lists, campaign/workflow targeting, and subscription preferences.
- [Update contact](https://loops.so/docs/api-reference/update-contact) and
  [Find contact](https://loops.so/docs/api-reference/find-contact): matching identities,
  subscription fields, and mailing-list membership. Provider behavior still needs synthetic
  verification; no live roster or recipient calls were made for this proposal.
- [Transactional email](https://loops.so/docs/transactional),
  [send API](https://loops.so/docs/api-reference/send-transactional-email), and
  [attachments](https://loops.so/docs/transactional/attachments): delivery behavior,
  idempotency, attachment enablement and payload limit.
- Local source: `app/services/loops/roster_audience.rb`, `roster_synchronizer.rb`, and
  `client.rb`; `app/models/meeting_minutes.rb`; `app/models/minutes_attestation.rb`;
  `app/views/meeting_minutes/_minutes_document.html.erb`; `app/services/meeting_minutes_pdf.rb`;
  `app/controllers/meeting_minutes_pdf_sources_controller.rb`; existing Loops service tests.

## Implementation alignment, October 19, 2026

Implementation starts from `e40df49` (PR #158). Its durable Endeavor History request
inside attestation and its after-commit recovery remain independent of email delivery.
Email intent is also saved in the attestation transaction; provider and PDF work runs
later. No provider request or AI call belongs in the official-record transaction.

The officer screen follows The 1919: navy `#0A2240`, gold `#C6A15B`, document ivory `#FCFAF1`,
ink `#1b222b`, muted slate `#6b7684`; reuse existing application tokens and controls.
System sans carries workspace text; Georgia remains reserved for the minutes document.
A two-column desktop workspace pairs the office-address register with the short cover
preview and group ownership explanation. It becomes one column on narrow screens.
The signature is the paired group ownership statement: Post members belongs to roster
sync; Minutes recipients belongs to this officer workflow. Keep all interactive/body
text at least 16px, secondary text 14px, labels 13px. Meeting email status stays beside
the existing minutes workflow, with its action and count.

Settings and recipient changes have an officer audit trail. Delivery records snapshot
the initial destinations, immutable revision, document authority and letterhead. Queue
recovery uses recorded intents only. Configuration starts disabled, and requires explicit
confirmation that general campaigns have been retargeted before outside enrollment.

## Implementation validation

The subsequent [settings and wording design](MINUTES_DISTRIBUTION_EDITING.md) replaces the
always-open setup form with saved summaries and explicit editing, and adds application-owned
subject/cover-note wording with named variables, previews, attestation snapshots and stale-form
protection. It preserves the existing recipient, official-record and provider boundaries.

The local implementation preserves PR #158's transactional Endeavor History request and
adds separate email intents. Offline provider checks exercise initial/corrected/final
attestation, unchanged approval, separate/shared office addresses, partial failure,
A -> B -> A content, queue loss, interruption, stable retry keys and reviewed unknown
outcomes. The sync-to-email workflow reads back preserved provider state after two
syncs and former-member removal. No real contacts or provider emails are used.

Four additional workflow assertions failed against the initial implementation and passed
with its refinements: pause during provider lookup, a newer attestation during rendering,
per-address progress behind an uncertain delivery, and visible former-member removal
review. These are observed regression detections during implementation, not claims about
a defect in a previously released minutes-email feature.

Chromium-generated synthetic PDFs were inspected as text and rendered pages: original and
corrected narratives and the closing Record of authority match their fixed revisions;
the original attachment remains unchanged. Workspace screens were visually reviewed at
desktop, 390px and 320px. Live account setup and inbox acceptance remain unverified.
See [the current guide](MINUTES_EMAIL_DISTRIBUTION.md) for rollout and test entry points.
