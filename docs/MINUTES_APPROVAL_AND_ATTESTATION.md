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

The status-card action opens one consequence and identity-confirmation page. Meeting
approval first collects the real approving meeting and decision. Identity is confirmed
by email or passkey. Successful identity confirmation completes the
specific action and returns to the minutes with the new status. There is no extra
approval button after authentication. GET requests never execute an official action.

Each confirmation remains one-use, session-bound, short-lived, and bound to the action,
record lock version, content digest, and supplied meeting/correction details. Changes
to the text, authority, or record while confirming reject the action. Bearer execution
retains explicit capabilities, idempotency, and delegated provenance.

## Visual direction

The audience is infrequent Commander and Adjutant users. Both the Meeting page and
minutes workspace lead with the same plain status, what that status means, and who acts
next. A bounded paper card holds the status and its action together. The signature
element is a three-stage record progression: **Draft → Attested → Approved and locked**.
A Commander handoff and corrections are explanations within that progression, rather
than competing kinds of approval.

Follow The 1919 system: navy #0A2240, gold #C6A15B, paper #FBF7EC, cream #F4EEDD,
officer blue #2F5F87, and completion green #3F6B3F. Working UI uses system sans; serif is
reserved for the document. Reuse existing cards, buttons, and shared section headings.
Body and interactive text are at least 16px; secondary text at least 14px; labels at
least 13px. At 390px the progression stacks, actions wrap, and the page never scrolls
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
