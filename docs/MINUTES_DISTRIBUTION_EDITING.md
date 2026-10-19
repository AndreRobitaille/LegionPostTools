# Minutes distribution settings and email wording

The later [email presentation design](MINUTES_EMAIL_PRESENTATION.md) extends this editor
with short Post/meeting labels, a styled PDF attachment callout and separate status preview.
It preserves the saved-wording and retry boundaries described here.

## User job and accepted direction

An officer needs to understand who receives minutes, check the saved setup, and deliberately
edit either delivery choices or email wording. The existing page exposes connection IDs as
ordinary editable fields and describes a setup review in Loops jargon. Its email example
looks like fixed text rather than a template. Replace those ambiguities without changing
the minutes recipient boundary, roster ownership or official-record authority.

The user selected editing the subject and cover note on this page. Greeting, signature,
approval status and the corrected-copy notice remain automatic. No provider template edit
or live test email is needed to edit or preview this wording.

## Layout and language

Use The 1919's bounded working layout: navy `#0A2240`, gold `#C6A15B`, cream `#F4EEDD`,
card paper `#FBF7EC`, ink `#1b222b`, and green `#3f6b3f` for saved enabled status. System
sans carries working text; no new display font, animation or ornamental treatment.
Reuse existing card headers, buttons, form controls and border tokens. Body and interactive
text stay at least 16px, supporting copy 14px and labels 13px. Stack at the established
900px breakpoint and verify 390px and 320px.

Keep the office register and delivery results together. Give the email enough width to
read and edit paragraphs. Its signature element is a visible variable strip: named,
insertable variables with their literal double-brace notation, paired with a filled-in
example. Technical connection details do not dominate the working view.

```text
Minutes distribution — only designated minutes recipients receive automatic copies

Recipient offices                    Email wording
  name / office / address              saved subject + cover note
  Pause / Edit office entry            automatic greeting / status / signature
                                       Edit email wording
Recent mailings
  delivery results                   Delivery settings
                                       enabled / meetings / reply address
                                       Edit delivery settings
                                       Loops connection details (expand)
```

Saved settings and wording are read-only by default. Explicit Edit links open one editor
at a time. Save persists that editor's fields; Cancel discards unsaved changes. Connection
IDs remain under technical details, with the existing prohibition on changing list IDs
after enrollments reflected in the form. Do not introduce a new approval process.

Replace the confusing setup checkbox with a plain statement that the officer has checked
that regular Post emails in Loops use Post members. Explain that All audience also includes
outside minutes contacts, and that this checkbox records a review rather than changing
Loops campaigns. The normal saved view leads with meetings, reply address and the fact that
automatic copies go only to designated Minutes recipients.

## Wording and persistence

Provide a subject field and plain-text cover-note field. Offer Post name, Meeting name,
Meeting date and Copy label variables. Keep Copy label in the subject so corrected copies
are identifiable. Reject unknown/malformed variables and subject line breaks with an
actionable error; preserve entered wording on validation failure.

The preview uses the same wording and example variables, with first-copy and corrected-copy
examples. Show automatic content separately and explain why it follows the minutes. Editing,
previewing and saving never send email. Existing Loops variables and published transport
template remain compatible: the app still provides subject and cover_note.

Capture the selected wording on each new attestation's distribution intent. Subsequent
wording edits apply to future attestations, including future corrected copies, and cannot
change already-recorded or submitted messages. Older distributions retain the original
standard wording. This adds no AI call. Keep per-address comparison, eligibility, PDF
generation, frozen retries, holds and original correction destinations unchanged.

Use separate permitted parameters for wording and delivery updates, existing current
management authority and append-only audits. Optimistic locking rejects stale forms
instead of silently overwriting another officer's changes. Preserve private/no-store
responses and the website-only configuration boundary.

## Verification

- Confirm saved display, explicit Edit, Cancel and later saved reads through the browser
  at desktop, 390px and 320px, including no overflow and readable controls.
- Insert a variable at the caret and observe a filled-in preview; switch to corrected copy.
  Reject unknown variables without losing input, and show a useful path from stale edits.
- Verify that a wording save cannot change delivery choices, and delivery saves cannot
  replace wording; retain existing role-turnover and unauthorized-access coverage.
- With synthetic data and a fake provider, attest with custom wording, then edit wording
  before initial dispatch and after submission. The recorded copy and retry stay unchanged;
  a genuinely corrected attestation uses the new wording and automatic status/correction
  notice. Unchanged text/approval still generates no duplicate email.
- Run relevant ordinary and browser suites, full release checks for the affected sending
  and authorization boundaries, and inspect rendered screenshots. Send no real email.
