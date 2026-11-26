# Minutes Review, Attestation, and Meeting Approval

## Product decisions (October 4, 2026)

The Adjutant is responsible for the minutes record and electronic attestation. The
Commander may help create or edit minutes in practice; Commander review is a drafting
handoff, not a required source of official authority. The relevant Meeting Body (such
as the PEC or membership) approves its minutes at a later meeting.

1. Either officer prepares the working minutes.
2. A Commander preparing minutes can **Send to Adjutant**. This preserves the handed-off
   text and marks the working copy **Ready for Adjutant review**. It stays editable.
3. The Adjutant reviews and edits the working copy, then **Attest and share with members**.
   Adjutant-prepared minutes go directly to this step. Editing a handed-off draft does
   not require another Commander approval. Attestation captures the exact current text
   in an immutable revision; it does not pretend the Commander approved later edits.
4. Members can read the attested copy. An officer records the real later meeting's
   approval. **Approved as presented** locks that exact record.
5. **Approved with corrections** records the decision and corrections to enter, reopens
   the working copy, and retains the last attested copy for members. Either officer can
   enter the corrections. The Adjutant then **Confirm corrections and lock minutes**.
   This attests the corrected text and links the recorded meeting approval to that exact
   final revision, without a second vote or another approval-recording step.

Corrections that have already been incorporated and attested can still have their
meeting approval recorded against that exact copy. Approved official minutes never
reopen; later amendments remain planned.

## Confirmation behavior

On the Meeting page and in the minutes workspace, the paper status card pairs the
action heading with its consequence and signing choices. Use a navy action button
and an outlined email alternative, stacked on phones. Email is primary when the
officer has no usable passkey. Reopening and meeting approval put the same choices
under the officer's reason or decision. Disclose applicable outside distribution
and mailing holds before the officer signs.

One click starts the device prompt or sends the code and link. Email entry stays
in the originating card or form and its final button names the action. Opening
an emailed link displays the meeting and the consequence before the officer
submits. Successful verification completes the action and shows the new status.
Cancellation, expiry and changed records require a fresh request. Opening or
revisiting a page never signs minutes.

Each confirmation remains one-use, session-bound, short-lived, and bound to the action,
record lock version, content digest, and supplied meeting/correction details. Changes
to the text, authority, or record while confirming reject the action. Bearer execution
retains explicit capabilities, idempotency, and delegated provenance.

## Visual direction

The audience is infrequent Commander and Adjutant users. Both the Meeting page and
minutes workspace lead with the same plain status, what that status means, and who acts
next. A bounded paper card holds the status and its action together. The signature
element is a three-stage record progression: **Draft → Attested → Approved and locked**.
A Commander handoff and corrections are explained within those stages.

A wide minutes card reads across one row. The current state is on the left, the
signing consequence sits beside it, and the signing buttons are grouped on the
right. A slim three-stage strip leads the card. Document links sit with the
meeting title. Use the width
of the card to choose the layout, since the Meeting page shares space with
the agenda. In a narrow card the same content follows its reading order,
with the signing choices directly below the consequence. When the Post emails
this kind of minutes or a mailing is on record, a quiet row in the same card
names the outside offices as the audience and explains what happens to the PDF.
Keep that status visible when mailing options are closed. Expand the row in
place for recipient review and meeting-specific controls. A meeting with no
applicable mailing needs no separate card.

Follow The 1919 system: navy #0A2240, gold #C6A15B, paper #FBF7EC, cream #F4EEDD,
officer blue #2F5F87, and completion green #3F6B3F. Working UI uses system sans; serif is
reserved for the document. Reuse existing cards, buttons, and shared section headings.
Body and interactive text are at least 16px; secondary text at least 14px; labels at
least 13px. At 390px the three stages share one row, actions wrap, and the page never scrolls
horizontally. Digests and full provenance belong in expandable history, not primary
instructions.

Member revision wording uses the same Lexxy content styling as the officer view, so
paragraphs, nested bullets, numbering, emphasis, and links retain their formatting on
screen and in print. Apply that styling to sanitized immutable HTML; displaying the
record must never rewrite its text or digest.

The member HTML document uses the agenda's paper layout, a compact approval status,
and electronic attestation with expandable record details. All recorded business and
attendance remain visible. See `MEMBER_MEETING_DOCUMENTS.md` for its design and the
member-only boundary; administrative workspaces and PDF documents retain their layout.

## Integrity and compatibility

- Existing revisions, attestations, and lifecycle events stay immutable in Rails and
  PostgreSQL. Existing Commander endorsements remain truthful historical evidence.
- A revision created directly by Adjutant attestation has no Commander endorsement.
  Nullable Commander fields represent absence, never a simulated approval.
- The legacy internal approved state means a draft handed to the Adjutant; it is not
  the meeting body's approval. Editors and draft APIs accept this state until attestation.
- Member HTML/PDF renders an immutable attested revision. Officer draft previews render
  current working content, including Adjutant changes after a Commander handoff.
- A pending correction decision is an immutable lifecycle event recording the approving
  meeting, disposition, corrections, actor, recorder, confirmation, and original revision.
  Final attestation creates the final membership-approval row using that decision's
  provenance, then locks the minutes atomically.
- Existing membership-approved records and historical meetings remain protected. No
  production record is approved, attested, corrected, or otherwise changed by this work.

## Optional outside minutes email

When enabled for a meeting type, attestation also records a durable email intent for the
designated outside offices. Its consequence is disclosed in the existing confirmation.
Initial and corrected-copy delivery use immutable revisions and do not alter the approval
workflow. Unchanged meeting approval sends no second email. Provider/PDF work happens
after commit and cannot reverse attestation. See
[Minutes email distribution](MINUTES_EMAIL_DISTRIBUTION.md) for group ownership, holds,
recipient choices and recovery. Existing Endeavor History request/recovery remains intact.
