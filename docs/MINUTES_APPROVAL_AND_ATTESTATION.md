# Minutes Approval and Attestation

**Status:** implemented first official minutes handoff, audited correction reopening, and
membership-approval recording.

## Product boundary

This slice gives a Commander and Adjutant a truthful path from editable working minutes
to a member-visible record awaiting membership approval. It never invents a motion or
calls the minutes official before the membership action is recorded.

The sequence is deliberately explicit:

1. A person with `approve_minutes` approves one exact immutable revision for Adjutant
   review. The draft becomes read-only and remains officer-only.
2. A different person with `attest_minutes` attests that exact revision for member review.
   The revision becomes member-visible as **Awaiting membership approval**.
3. A Commander or Adjutant with `record_minutes_approval` records what the membership
   actually did at the later meeting against that exact attested revision.

Commander approval and Adjutant attestation are Post website controls. They do not
replace or impersonate membership approval. If the membership approves minutes as
corrected, the corrected text goes directly into those minutes, the website handoff is
repeated for the corrected revision, and the membership action is recorded against that
exact revision without requiring another membership vote.

The Commander may perform every ordinary minutes-management task available to the
Adjutant, including drafting, correcting, reopening, and recording membership approval.
The one exception is signing/attestation: `attest_minutes` remains an Adjutant capability
and must be exercised by a different person from the Commander approver.

Every transition records the actor, the person or delegated token that entered the
record, the time, the prior/resulting state, the exact revision digest, and the
confirmation method. Normal in-app actions require the actor's own explicit capability
and an exact confirmation. A bearer token carries its human owner's current capability
and may execute that same act when the human explicitly asks; the audit record marks the
delegated-agent execution.
When an officer has already supplied written confirmation outside the app, an exceptional
operator recording may name that officer while separately naming the recorder and the
written-confirmation basis. It must never imply that the officer clicked the website.

## Visual direction

The subject is a Post's record of proceedings; the audience is a Commander or Adjutant
who may use the app infrequently; the page's single job is to show what must happen next.

- **Color:** Legion navy `#0A2240`, deep navy `#081A34`, service gold `#C6A15B`, paper
  `#FBF7EC`, officer blue `#2F5F87`, and membership-approval green `#3F6B3F`.
- **Type:** the existing system face for controls and explanations, with Georgia reserved
  for the document and lifecycle headings.
- **Layout:** keep the record full-width below a compact four-station lifecycle rail.
  The current station carries the only strong color; completed stations read like dated
  endorsements rather than generic progress badges.
- **Signature element:** an endorsement strip modeled on the approval blocks of an
  official paper record: actor, office, act, and time remain together.

```text
[ Working draft ]---[ Commander approval ]---[ Adjutant release ]---[ Membership approval ]
       done                 current                  later                 later

[ exact consequence ]                              [ primary action ]
```

The rail encodes a real sequence rather than decoration. At 390px it becomes a vertical
ledger so labels, names, and controls remain readable without horizontal scrolling.

## Integrity rules

- Approval snapshots the current heading, attendance, sections, items, rich text, and
  outcomes into an immutable `MinutesRevision` with a canonical SHA-256 digest.
- Approved working rows are read-only. Member pages render the immutable revision, never
  mutable draft rows.
- The Adjutant must be a different person from the Commander approver.
- Attestation never regenerates or copies content.
- Revision, attestation, and lifecycle-event rows are append-only in Rails and PostgreSQL.
- Member pages call the record **Attested minutes** and **Awaiting membership approval**.
  They do not say membership-approved or official yet.
- Draft PDFs remain visibly draft. Approved PDFs render the immutable revision as awaiting
  attestation; attested PDFs render that same revision as awaiting membership approval.
  Membership-approved PDFs render that exact revision as official. Amended PDFs belong to
  a later lifecycle slice.
