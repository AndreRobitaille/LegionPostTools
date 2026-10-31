# Minutes email presentation

## Approved direction and user job

Outside officers need to recognize which Post/meeting the message concerns, open the
attached PDF, and understand its authority. The first live test exposed an overlong
subject with the date repeated, full-width paragraphs and no visual hierarchy. The user
approved the short subject, restrained Post letterhead, attachment instruction and
separate approval-status block, and authorized deployment plus one new test to their
specified address.

Use The 1919 navy (#0A2240), gold (#C6A15B), warm paper (#FBF7EC), white (#FFFFFF), ink
(#1B222B) and muted navy (#526172). Email is official correspondence: a bounded ~600px
column, Arial/system sans at 18px for body, 16px status text, 14px supporting text and a
28px document heading. Use a small Post masthead and thin gold divider. The signature
visual element is the warm-paper “Minutes PDF attached” instruction, with a distinct
quiet status panel below. No images, animations, account links or simulated download
buttons. The actual attachment is opened using the recipient's email application.

```text
Post name
──────────────── gold rule
Membership minutes
October 6, 2026

Recipient,

Minutes PDF attached
Open the attached PDF to read, save or print the minutes.

Attested — awaiting membership approval
Attested by the Adjutant. Corrections may be made at the next membership meeting.

Post name
```

## Text and compatibility

- Add insertable Short Post name and Meeting name variables; retain Full meeting title,
  Post name, Meeting date and Copy label for saved custom wording. For a configured
  American Legion Post with a unit number, Short Post name is “Post <number>”; otherwise
  use the installation's full name. Never hard-code Post 165.
- Use the configured meeting-type name (fallback: saved meeting-body name), removing only
  a trailing “Meeting” for email presentation. Do not strip dates from the official title
  or change immutable revision payloads. Capture presentation context before submission.
- Default subject: short Post name, copy label, meeting name and date, each once. Keep
  the existing required Copy label to distinguish corrected copies.
- Default cover note directs the reader to open, save or print the PDF. The attachment
  heading remains automatic even when officers customize their cover note.
- Send separate cover-note, status-label, status-note and corrected-copy variables to the
  new styled template. Status uses the actual saved approving body; corrected copies
  retain the replacement notice. Preserve the legacy combined cover_note variable and
  literal legacy defaults for existing template IDs and older saved distributions.
- Keep greeting, signature, status and correction notices automatic. Website previews
  show the same hierarchy and values, including corrected-copy and approval variants.
  Client rendering may differ; no preview or settings save sends email.

## Provider rollout and evidence

Version the LMX source in the repository. Create and validate a new transactional template,
then publish and switch the saved template connection only after the deployed app supplies
its variables. Keep the previous template available for frozen submissions/retries. The
release does not create historical distributions, change audience lists, or enroll the
test address. Defaults do not overwrite other installations' custom wording. The explicitly authorized
Post 165 rollout saves the newly approved subject and cover note along with the new template
connection; subsequent officer wording edits remain authoritative.

Use the `commander` sender username in Loops; Post 165's sending domain resolves it to
`commander@mail.wipost165.org`. The user requested this sender for templates created for
this installation after reviewing the styled test. Apply the sender correction to both
minutes template versions while preserving their content and the configured reply address.

Verify source formatting and variable validation; synthetic first/corrected/approved email
payloads, legacy copy and frozen retries; rendered desktop/390/320px preview; ordinary and
browser suites, security/lint and deployment health. Validate the provider draft with
Guardian and read back the published source and header/recipient configuration. Send one
new explicitly authorized test with the latest attested minutes PDF, a TEST subject prefix,
no CC/BCC and addToAudience false, using a fresh durable idempotency key and receipt. Keep
all minutes and PDF contents on the server; report provider acceptance separately from
confirmed inbox receipt.
